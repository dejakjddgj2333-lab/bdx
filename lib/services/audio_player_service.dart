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

  bool _initialized = false;
  bool _started = false;
  Uint8List? _jitterBuffer;
  DateTime? _playStartTime;

  static const int _sampleRate = 24000;
  static const int _channels = 1;

  /// 24kHz 16-bit mono，200ms 抖动缓冲 = 9600 bytes
  static const int _jitterSize = 9600;

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
      log('音频会话配置完成');
    } catch (e) {
      log('音频会话配置失败（继续初始化播放器）: $e');
    }

    try {
      _player = AudioPlayer();
      _pcmController = StreamController<Uint8List>();

      await _player!.setAudioSource(_PcmStreamSource(_pcmController!.stream));

      // 先写入流式 WAV 头，让播放器知道采样率/声道等格式信息
      _pcmController!.add(AudioUtils.streamingWavHeader(_sampleRate, _channels));

      await _player!.setVolume(1.0);
      await _player!.play();
      log('音频播放器初始化完成');
    } catch (e) {
      log('音频播放器初始化失败: $e');
      await dispose();
      rethrow;
    }

    _initialized = true;
    _started = false;
    _jitterBuffer = null;
    _playStartTime = null;
  }

  Future<void> setSpeaker(bool useSpeaker) async {
    // TODO: 实现扬声器/听筒切换
  }

  /// 接收 AI 返回的 PCM 数据并写入流。
  ///
  /// 前 [jitterSize] 字节先缓存，凑够 200ms 后再开始播放，
  /// 用以抵消网络抖动带来的断断续续。
  void handleAudioData(Uint8List pcmData) {
    if (!_initialized || _pcmController == null || _pcmController!.isClosed) {
      return;
    }

    if (!_started) {
      _jitterBuffer = _concatBuffers(_jitterBuffer, pcmData);
      if (_jitterBuffer!.length >= _jitterSize) {
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
    if (player.playing) return;
    if (player.processingState == ProcessingState.completed ||
        player.processingState == ProcessingState.idle) {
      player.play();
    }
  }

  /// 如果播放器超过 8 秒没有收到新数据，认为卡死。
  bool get isStuck {
    if (!_initialized || _playStartTime == null) return false;
    return DateTime.now().difference(_playStartTime!).inSeconds > 8;
  }

  void forceReset() {
    log('AudioPlayer 长时间无数据，强制重置');
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
      log('AudioSession 释放失败: $e');
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
}

/// 把 PCM 裸流包装成可播放的 WAV 音频源。
///
/// 音频流开头已经带有一个流式 WAV 头，因此这里直接把数据透传给播放器即可。
class _PcmStreamSource extends StreamAudioSource {
  final Stream<Uint8List> _stream;

  _PcmStreamSource(this._stream);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    return StreamAudioResponse(
      sourceLength: null, // 实时流，长度未知
      contentLength: null,
      offset: 0,
      stream: _stream,
      contentType: 'audio/wav',
    );
  }
}
