import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:typed_data';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

/// 流式 PCM 播放器（基于 flutter_pcm_sound）。
///
/// 直接播放后端返回的 PCM 裸流，无需 WAV 头或 HTTP 代理。
/// 内部维护一个抖动缓冲，吸收网络抖动，减少卡顿。
class AudioPlayerService {
  bool _initialized = false;
  DateTime? _lastFeedTime;

  static const int _sampleRate = 24000;
  static const int _channels = 1;
  static const int _bytesPerSample = 2;

  /// 每次喂给插件的时长（ms），对应 24kHz 单声道 16bit：20ms = 480 frames = 960 bytes
  static const int _feedIntervalMs = 20;

  /// 开始播放前需要累积的目标缓冲时长（ms）
  static const int _targetBufferedMs = 250;

  /// 缓冲上限，超过则丢弃旧数据，避免延迟越来越大
  static const int _maxBufferedMs = 800;

  final Queue<Uint8List> _buffer = Queue<Uint8List>();
  int _bufferedBytes = 0;
  Timer? _feedTimer;
  bool _hasStarted = false;

  Future<void> init() async {
    if (_initialized) return;
    await dispose();

    try {
      // flutter_pcm_sound 的 setup 会设置 AVAudioSession category，但不会带选项。
      // 先让插件初始化，再用 audio_session 补充 defaultToSpeaker/allowBluetooth。
      await FlutterPcmSound.setLogLevel(LogLevel.standard);
      await FlutterPcmSound.setup(
        sampleRate: _sampleRate,
        channelCount: _channels,
        iosAudioCategory: IosAudioCategory.playAndRecord,
      );
      _emitLog('flutter_pcm_sound setup 完成: $_sampleRate Hz, $_channels ch');
    } catch (e) {
      _emitLog('flutter_pcm_sound setup 失败: $e');
      await dispose();
      rethrow;
    }

    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.defaultToSpeaker |
                AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ));
      await session.setActive(true);
      await FlutterPcmSound.setPreferredSampleRate(_sampleRate);
      _emitLog('音频会话配置完成: voiceChat + defaultToSpeaker, sampleRate=$_sampleRate');
    } catch (e) {
      _emitLog('音频会话配置失败: $e');
    }

    _initialized = true;
    _lastFeedTime = null;
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
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
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

  /// 接收 AI 返回的 PCM 数据并放入抖动缓冲。
  void handleAudioData(Uint8List pcmData) {
    if (!_initialized) {
      _emitLog('handleAudioData: 播放器未初始化，忽略 ${pcmData.length} bytes');
      return;
    }
    if (pcmData.isEmpty) return;

    _buffer.add(pcmData);
    _bufferedBytes += pcmData.length;

    final bufferedFrames = _bytesToFrames(_bufferedBytes);
    final targetFrames = _msToFrames(_targetBufferedMs);

    if (!_hasStarted && bufferedFrames >= targetFrames) {
      _hasStarted = true;
      _startFeedTimer();
      _feedChunk(frames: targetFrames);
      _emitLog('开始播放，已缓冲 $bufferedFrames frames ($_bufferedBytes bytes)');
    }

    final maxFrames = _msToFrames(_maxBufferedMs);
    if (bufferedFrames > maxFrames) {
      final dropFrames = bufferedFrames - targetFrames;
      _dropFrames(dropFrames);
      _emitLog('缓冲过大，丢弃 $dropFrames frames 旧数据');
    }
  }

  /// 停止当前播放并清空缓冲。
  Future<void> cancelPlaying() async {
    _stopFeedTimer();
    _lastFeedTime = null;
    try {
      // flutter_pcm_sound 没有单独 pause/stop/clear 接口，release 会释放资源。
      await FlutterPcmSound.release();
      _emitLog('cancelPlaying: 已 release');
    } catch (e) {
      _emitLog('cancelPlaying 失败: $e');
    }
  }

  /// 把尾部累积数据一次性推入流（抖动缓冲会持续喂完，这里额外推一次保证及时）。
  Future<void> flushAccumulatedAudio() async {
    if (!_initialized) return;
    _feedChunk();
    _lastFeedTime = DateTime.now();
    _emitLog('flushAccumulatedAudio: 已推送当前缓冲');
  }

  /// 如果播放器超过 8 秒没有收到新数据，认为卡死。
  bool get isStuck {
    if (!_initialized || _lastFeedTime == null) return false;
    return DateTime.now().difference(_lastFeedTime!).inSeconds > 8;
  }

  Future<void> forceReset() async {
    _emitLog('AudioPlayer 长时间无数据，强制重置');
    _lastFeedTime = null;
    await dispose();
    await init();
  }

  Future<void> dispose() async {
    _initialized = false;
    _lastFeedTime = null;
    _stopFeedTimer();

    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e) {
      _emitLog('AudioSession 释放失败: $e');
    }

    try {
      await FlutterPcmSound.release();
      _emitLog('flutter_pcm_sound 已释放');
    } catch (e) {
      _emitLog('flutter_pcm_sound 释放失败: $e');
    }
  }

  void _startFeedTimer() {
    _feedTimer?.cancel();
    _feedTimer = Timer.periodic(
      const Duration(milliseconds: _feedIntervalMs),
      (_) => _feedChunk(),
    );
  }

  void _stopFeedTimer() {
    _feedTimer?.cancel();
    _feedTimer = null;
    _hasStarted = false;
    _buffer.clear();
    _bufferedBytes = 0;
  }

  /// 从缓冲中取出 [frames] 帧（默认一个 20ms 包）喂给播放器。
  void _feedChunk({int? frames}) {
    if (!_initialized) return;

    final chunkFrames = frames ?? _msToFrames(_feedIntervalMs);
    final chunkBytes = _framesToBytes(chunkFrames);
    final feedBytes = _bufferedBytes >= chunkBytes ? chunkBytes : _bufferedBytes;
    if (feedBytes == 0) return;

    final data = _consumeBytes(feedBytes);
    try {
      final pcmArray = PcmArrayInt16(
        bytes: ByteData.sublistView(data),
      );
      FlutterPcmSound.feed(pcmArray);
      _lastFeedTime = DateTime.now();
    } catch (e) {
      _emitLog('_feedChunk 失败: $e');
    }
  }

  /// 从队列头部消费 [count] 字节。
  Uint8List _consumeBytes(int count) {
    final builder = BytesBuilder();
    int remaining = count;
    while (remaining > 0 && _buffer.isNotEmpty) {
      final front = _buffer.first;
      if (front.length <= remaining) {
        builder.add(front);
        remaining -= front.length;
        _bufferedBytes -= front.length;
        _buffer.removeFirst();
      } else {
        builder.add(Uint8List.sublistView(front, 0, remaining));
        final remainingInFront = front.length - remaining;
        _bufferedBytes -= remaining;
        _buffer.removeFirst();
        _buffer.addFirst(Uint8List.sublistView(front, remaining));
        // 更新剩余长度，防止循环
        assert(remainingInFront == _buffer.first.length);
        remaining = 0;
      }
    }
    return builder.toBytes();
  }

  /// 丢弃缓冲中最旧的 [frames] 帧。
  void _dropFrames(int frames) {
    int remaining = _framesToBytes(frames);
    while (remaining > 0 && _buffer.isNotEmpty) {
      final front = _buffer.first;
      if (front.length <= remaining) {
        remaining -= front.length;
        _bufferedBytes -= front.length;
        _buffer.removeFirst();
      } else {
        Uint8List.sublistView(front, 0, remaining);
        _bufferedBytes -= remaining;
        _buffer.removeFirst();
        _buffer.addFirst(Uint8List.sublistView(front, remaining));
        remaining = 0;
      }
    }
  }

  int _msToFrames(int ms) => (_sampleRate * ms) ~/ 1000;

  int _framesToBytes(int frames) => frames * _channels * _bytesPerSample;

  int _bytesToFrames(int bytes) => bytes ~/ (_channels * _bytesPerSample);

  void _emitLog(String message) {
    log(message);
  }
}
