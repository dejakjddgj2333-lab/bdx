import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import '../core/utils/audio_utils.dart';

/// 流式 PCM 播放器。
///
/// 通过一次 [AudioPlayer] + [StreamAudioSource] 建立连续音频管道，
/// AI 返回的 PCM 数据源源不断地写入同一个流，避免反复实例化播放器导致的卡顿。
class AudioPlayerService {
  AudioPlayer? _player;
  StreamController<Uint8List>? _pcmController;
  final StreamController<String> _logController = StreamController<String>.broadcast();

  bool _initialized = false;
  bool _started = false;
  Uint8List? _jitterBuffer;
  DateTime? _playStartTime;

  static const int _sampleRate = 24000;
  static const int _channels = 1;

  /// 24kHz 16-bit mono，100ms 抖动缓冲 = 4800 bytes
  static const int _jitterSize = 4800;

  /// 播放器内部日志流，供 UI 实时显示调试用。
  Stream<String> get logs => _logController.stream;

  Future<void> init() async {
    if (_initialized) return;

    await dispose();

    // 配置音频会话：允许同时播放和录音，避免 AI 说话时麦克风被系统静音
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.defaultToSpeaker |
                AVAudioSessionCategoryOptions.allowBluetooth,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ));
      await session.setActive(true);
      _emitLog('音频会话配置完成, 采样率=$_sampleRate, 声道=$_channels');
    } catch (e) {
      _emitLog('音频会话配置失败（继续初始化播放器）: $e');
    }

    try {
      _player = AudioPlayer();
      // 使用广播流：iOS just_audio 内部代理可能会多次订阅（range 请求），
      // 单订阅流会导致二次监听抛出异常。
      _pcmController = StreamController<Uint8List>.broadcast();

      await _player!.setAudioSource(_PcmStreamSource(_pcmController!.stream));

      // 监听播放器状态，便于排查 iOS 没声音问题
      _player!.playerStateStream.listen((playerState) {
        _emitLog('播放器状态: playing=${playerState.playing}, '
            'processingState=${playerState.processingState}');
      });

      // 先写入流式 WAV 头，让播放器知道采样率/声道等格式信息
      _pcmController!.add(AudioUtils.streamingWavHeader(_sampleRate, _channels));

      await _player!.setVolume(1.0);
      await _player!.play();
      _emitLog('音频播放器初始化完成');
    } catch (e) {
      _emitLog('音频播放器初始化失败: $e');
      await dispose();
      rethrow;
    }

    _initialized = true;
    _started = false;
    _jitterBuffer = null;
    _playStartTime = null;
  }

  Future<void> setSpeaker(bool useSpeaker) async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: useSpeaker
            ? AVAudioSessionCategoryOptions.defaultToSpeaker |
                AVAudioSessionCategoryOptions.allowBluetooth
            : AVAudioSessionCategoryOptions.allowBluetooth,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ));
      await session.setActive(true);
      _emitLog('音频输出切换到: ${useSpeaker ? "扬声器" : "听筒"}');
    } catch (e) {
      _emitLog('切换扬声器失败: $e');
    }
  }

  /// 接收 AI 返回的 PCM 数据并写入流。
  ///
  /// 前 [jitterSize] 字节先缓存，凑够 200ms 后再开始播放，
  /// 用以抵消网络抖动带来的断断续续。
  void handleAudioData(Uint8List pcmData) {
    if (!_initialized || _pcmController == null || _pcmController!.isClosed) {
      _emitLog('handleAudioData: 播放器未初始化，忽略 ${pcmData.length} bytes');
      return;
    }

    _emitLog('handleAudioData: 收到 ${pcmData.length} bytes, started=$_started, '
        'playing=${_player?.playing}, processingState=${_player?.processingState}');

    if (!_started) {
      _jitterBuffer = _concatBuffers(_jitterBuffer, pcmData);
      if (_jitterBuffer!.length >= _jitterSize) {
        _emitLog('handleAudioData: 抖动缓冲已满 ${_jitterBuffer!.length} bytes，开始播放');
        _pcmController!.add(_jitterBuffer!);
        _jitterBuffer = null;
        _started = true;
        _playStartTime = DateTime.now();
        _ensurePlaying();
      }
    } else {
      _pcmController!.add(pcmData);
      _playStartTime = DateTime.now();
      _ensurePlaying();
    }
  }

  /// 停止当前播放并清空缓冲，但保留播放器实例可再次 [init]。
  void cancelPlaying() {
    _jitterBuffer = null;
    _started = false;
    _playStartTime = null;
    _player?.stop();
  }

  /// 把尾部的累积数据一次性推入流，避免 AI 回复末尾被截断。
  Future<void> flushAccumulatedAudio() async {
    if (_jitterBuffer != null && _jitterBuffer!.isNotEmpty) {
      _pcmController?.add(_jitterBuffer!);
      _jitterBuffer = null;
      _started = true;
      _playStartTime = DateTime.now();
      _ensurePlaying();
    }
  }

  void _ensurePlaying() {
    final player = _player;
    if (player == null) return;
    // 只要没在播放就尝试恢复，兼容 iOS 在各种 processingState 下的暂停状态。
    if (!player.playing) {
      _emitLog('_ensurePlaying: 尝试恢复播放 (processingState=${player.processingState})');
      player.play();
    }
  }

  /// 如果播放器超过 8 秒没有收到新数据，认为卡死。
  bool get isStuck {
    if (!_initialized || _playStartTime == null) return false;
    return DateTime.now().difference(_playStartTime!).inSeconds > 8;
  }

  void forceReset() {
    _emitLog('AudioPlayer 长时间无数据，强制重置');
    _player?.stop();
    _playStartTime = null;
  }

  Future<void> dispose() async {
    _initialized = false;
    _started = false;
    _jitterBuffer = null;
    _playStartTime = null;

    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e) {
      _emitLog('AudioSession 释放失败: $e');
    }

    if (_pcmController != null && !_pcmController!.isClosed) {
      await _pcmController!.close();
    }
    _pcmController = null;

    await _player?.dispose();
    _player = null;
  }

  static Uint8List _concatBuffers(Uint8List? a, Uint8List b) {
    if (a == null || a.isEmpty) return b;
    final result = Uint8List(a.length + b.length);
    result.setAll(0, a);
    result.setAll(a.length, b);
    return result;
  }

  void _emitLog(String message) {
    log(message);
    if (!_logController.isClosed) {
      _logController.add(message);
    }
  }
}

/// 把 PCM 裸流包装成可播放的 WAV 音频源。
///
/// 音频流开头已经带有一个流式 WAV 头，因此这里直接把数据透传给播放器即可。
class _PcmStreamSource extends StreamAudioSource {
  final Stream<Uint8List> _stream;

  _PcmStreamSource(this._stream);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    // iOS 的 AVPlayer 通过 just_audio 内部 HTTP 代理请求音频，会发起 range 请求。
    // 直播流长度未知，若 sourceLength 与 contentLength 同时为 null，
    // just_audio 在计算 contentLength 时会抛出 Null check operator 异常。
    // 这里给一个足够大的 fake 长度，让播放器认为是无尽流并持续播放。
    // 注意：contentLength 必须保持为 null；若按 range 返回小数值（如 2），
    // 而直播流尚未产出数据，代理会报 "No content even though contentLength > 0"。
    const fakeLength = 0x7FFFFFFFFFFFFFFF;
    return StreamAudioResponse(
      sourceLength: fakeLength,
      contentLength: null,
      offset: start ?? 0,
      stream: _stream,
      contentType: 'audio/wav',
    );
  }
}
