import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:typed_data';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
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

  /// 每次喂给插件的时长（ms），对应 24kHz 单声道 16bit：400ms = 9600 frames = 19200 bytes
  static const int _feedChunkMs = 400;

  /// 兜底排空定时器间隔（ms），防止收到数据时正在喂导致漏排
  static const int _safetyIntervalMs = 200;

  /// native 缓冲低于此阈值时打印提醒（ms），不用于主动补喂
  static const int _feedThresholdMs = 300;

  /// 开始播放前需要累积的目标缓冲时长（ms）。
  /// 后端经常 600ms+ 才发一个 320ms 的包，目标设大才能连续播放。
  static const int _targetBufferedMs = 1500;

  /// Dart 缓冲上限，超过则丢弃最新数据（避免跳字）
  static const int _maxBufferedMs = 4000;

  final Queue<Uint8List> _buffer = Queue<Uint8List>();
  int _bufferedBytes = 0;
  Timer? _feedTimer;
  Timer? _statsTimer;
  bool _hasStarted = false;
  bool _isFeeding = false;
  int _nativeRemainingFrames = 0;
  int _feedCallbackCount = 0;

  /// 最近收到后端音频数据包的时间，用于判断是否为网络抖动
  DateTime? _lastAudioDeltaTime;

  /// 最近收到 feed 回调认为 native buffer 为空的时间
  DateTime? _lastNativeEmptyTime;

  Future<void> init() async {
    if (_initialized) return;
    await dispose();

    try {
      // 先统一配置 AVAudioSession：mode、category options、sample rate，
      // 然后再让 flutter_pcm_sound 创建 AudioUnit，避免中途重配导致格式错乱。
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
      _emitLog('音频会话配置完成: voiceChat + defaultToSpeaker');
    } catch (e) {
      _emitLog('音频会话配置失败: $e');
    }

    try {
      await FlutterPcmSound.setLogLevel(LogLevel.standard);
      await FlutterPcmSound.setup(
        sampleRate: _sampleRate,
        channelCount: _channels,
        iosAudioCategory: IosAudioCategory.playAndRecord,
      );
      await FlutterPcmSound.setFeedThreshold(_msToFrames(_feedThresholdMs));
      FlutterPcmSound.setFeedCallback(_onFeedSamples);
      _emitLog('flutter_pcm_sound setup 完成: $_sampleRate Hz, $_channels ch, '
          'feedThreshold=${_feedThresholdMs}ms');
    } catch (e) {
      _emitLog('flutter_pcm_sound setup 失败: $e');
      await dispose();
      rethrow;
    }

    _initialized = true;
    _lastFeedTime = null;
    // 暂关 stats 定时日志，避免刷屏淹没 WS/bloc 日志；调试可改回 _startStatsTimer()
    // _startStatsTimer();
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

    final now = DateTime.now();
    final interval = _lastAudioDeltaTime != null
        ? now.difference(_lastAudioDeltaTime!).inMilliseconds
        : 0;
    _lastAudioDeltaTime = now;

    final bufferedFrames = _bytesToFrames(_bufferedBytes);
    final targetFrames = _msToFrames(_targetBufferedMs);

    _emitLog('recv delta: ${pcmData.length} bytes, '
        'interval=${interval}ms, buffered=${bufferedFrames}f');

    if (!_hasStarted && bufferedFrames >= targetFrames) {
      _hasStarted = true;
      _startFeedTimer();
      _nativeRemainingFrames = targetFrames;
      _feedChunk(frames: targetFrames);
      _emitLog('开始播放，已缓冲 $bufferedFrames frames ($_bufferedBytes bytes)');
    }

    // 收到数据就尽量往 native 送，让 native 缓冲自己累积，
    // 而不是让 Dart 缓冲越积越多后丢弃旧数据。
    if (_hasStarted) {
      _drainBuffer();
    }

    final maxFrames = _msToFrames(_maxBufferedMs);
    if (bufferedFrames > maxFrames) {
      final dropFrames = bufferedFrames - targetFrames;
      _dropNewestFrames(dropFrames);
      _emitLog('缓冲过大，丢弃 $dropFrames frames 最新数据');
    }
  }

  /// 停止当前播放并清空缓冲。
  ///
  /// 调用后底层 AudioUnit 会被释放，必须重新 [init] 才能再次播放。
  Future<void> cancelPlaying() async {
    _stopFeedTimer();
    _lastFeedTime = null;
    _nativeRemainingFrames = 0;
    _lastNativeEmptyTime = DateTime.now();
    try {
      // flutter_pcm_sound 没有单独 pause/stop/clear 接口，release 会释放资源。
      await FlutterPcmSound.release();
      _emitLog('cancelPlaying: 已 release');
    } catch (e) {
      _emitLog('cancelPlaying 失败: $e');
    } finally {
      // release 后插件必须重新 setup，标记为未初始化避免后续 feed/clear 报错。
      _initialized = false;
      _hasStarted = false;
    }
  }

  /// 清空播放缓冲（用于打断/新响应开始时），不释放底层 AudioUnit。
  Future<void> clearBuffer() async {
    if (!_initialized) return;
    _emitLog('clearBuffer: 清空播放缓冲');
    _stopFeedTimer();
    _nativeRemainingFrames = 0;
    _lastNativeEmptyTime = DateTime.now();
    try {
      await FlutterPcmSound.clear();
    } catch (e) {
      _emitLog('clearBuffer 失败: $e');
      // 若插件已释放，标记为未初始化，避免后续继续调用。
      if (e.toString().contains('setup first')) {
        _initialized = false;
        _hasStarted = false;
      }
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

  /// Dart 层缓冲帧数。
  int get bufferedFrames => _bytesToFrames(_bufferedBytes);

  /// native 层剩余帧数（由 OnFeedSamples 回调更新）。
  int get nativeRemainingFrames => _nativeRemainingFrames;

  /// Dart + native 缓冲是否都已排空。
  bool get isPlaybackBufferEmpty =>
      _bufferedBytes == 0 && _nativeRemainingFrames == 0;

  /// 是否还在持续喂数据（native 正在播放或即将播放）。
  bool get isRecentlyFed {
    if (_lastFeedTime == null) return false;
    return DateTime.now().difference(_lastFeedTime!) <
        const Duration(milliseconds: 300);
  }

  /// 综合判断当前是否还有 AI 音频在播放或等待播放。
  bool get isPlaybackActive => !isPlaybackBufferEmpty || isRecentlyFed;

  /// native buffer 最近一次排空的时间，用于精确计算尾音保护期。
  DateTime? get lastNativeEmptyTime => _lastNativeEmptyTime;

  Future<void> forceReset() async {
    _emitLog('AudioPlayer 长时间无数据，强制重置');
    _lastFeedTime = null;
    await dispose();
    await init();
  }

  Future<void> dispose() async {
    _initialized = false;
    _lastFeedTime = null;
    _nativeRemainingFrames = 0;
    _lastNativeEmptyTime = null;
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
      const Duration(milliseconds: _safetyIntervalMs),
      (_) => _drainBuffer(),
    );
  }

  void _startStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        final lastFeedAge = _lastFeedTime != null
            ? DateTime.now().difference(_lastFeedTime!).inMilliseconds
            : -1;
        final lastDeltaAge = _lastAudioDeltaTime != null
            ? DateTime.now().difference(_lastAudioDeltaTime!).inMilliseconds
            : -1;
        _emitLog('stats: dartBuf=${bufferedFrames}f, '
            'nativeBuf=$_nativeRemainingFrames f, '
            'isFeeding=$_isFeeding, lastFeedAge=${lastFeedAge}ms, '
            'lastDeltaAge=${lastDeltaAge}ms');
      },
    );
  }

  /// 把 Dart 缓冲里的数据全部/分批喂给 native。
  void _drainBuffer() {
    if (!_initialized || _isFeeding || _bufferedBytes == 0) return;
    _feedChunk();
  }

  void _stopFeedTimer() {
    _feedTimer?.cancel();
    _feedTimer = null;
    _statsTimer?.cancel();
    _statsTimer = null;
    _hasStarted = false;
    _buffer.clear();
    _bufferedBytes = 0;
  }

  /// 从缓冲中取出 [frames] 帧（默认一个 80ms 包）喂给播放器。
  Future<void> _feedChunk({int? frames}) async {
    if (!_initialized || _isFeeding) return;

    final chunkFrames = frames ?? _msToFrames(_feedChunkMs);
    final chunkBytes = _framesToBytes(chunkFrames);
    final feedBytes = _bufferedBytes >= chunkBytes ? chunkBytes : _bufferedBytes;
    if (feedBytes == 0) return;

    _isFeeding = true;
    final data = _consumeBytes(feedBytes);
    final bufferedBeforeFrames = _bytesToFrames(_bufferedBytes + feedBytes);
    _emitLog('feed: ${feedBytes}bytes (${_bytesToFrames(feedBytes)}f), '
        'bufferBefore=${bufferedBeforeFrames}f, nativeRemaining=$_nativeRemainingFrames');
    try {
      final pcmArray = PcmArrayInt16(
        bytes: ByteData.sublistView(data),
      );
      await FlutterPcmSound.feed(pcmArray);
      _lastFeedTime = DateTime.now();
      _nativeRemainingFrames += _bytesToFrames(feedBytes);
      _emitLog('feed ok: nativeRemaining ~$_nativeRemainingFrames');
    } catch (e) {
      _emitLog('_feedChunk 失败: $e');
      // 若插件已释放，标记为未初始化，避免死循环报错。
      if (e.toString().contains('setup first')) {
        _initialized = false;
        _hasStarted = false;
      }
    } finally {
      _isFeeding = false;
      // 继续排空，确保新到的数据也能及时送进 native。
      if (_hasStarted && _bufferedBytes > 0) {
        _drainBuffer();
      }
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

  /// 丢弃缓冲中最新的 [frames] 帧，避免跳字/跳段。
  void _dropNewestFrames(int frames) {
    int remaining = _framesToBytes(frames);
    final list = _buffer.toList();
    while (remaining > 0 && list.isNotEmpty) {
      final back = list.last;
      if (back.length <= remaining) {
        remaining -= back.length;
        _bufferedBytes -= back.length;
        list.removeLast();
      } else {
        final keepLength = back.length - remaining;
        final kept = Uint8List.sublistView(back, 0, keepLength);
        _bufferedBytes -= remaining;
        list[list.length - 1] = kept;
        remaining = 0;
      }
    }
    _buffer.clear();
    _buffer.addAll(list);
  }

  int _msToFrames(int ms) => (_sampleRate * ms) ~/ 1000;

  void _onFeedSamples(int remainingFrames) {
    _nativeRemainingFrames = remainingFrames;
    _feedCallbackCount++;
    if (remainingFrames == 0) {
      _lastNativeEmptyTime = DateTime.now();
    }
    final thresholdFrames = _msToFrames(_feedThresholdMs);
    final isLow = remainingFrames <= thresholdFrames;
    // 每 20 次回调或低缓冲/排空时打印，避免刷屏
    if (isLow || remainingFrames == 0 || _feedCallbackCount % 20 == 1) {
      _emitLog('native cb #$_feedCallbackCount: remaining=$remainingFrames f '
          '(${(remainingFrames * 1000 ~/ _sampleRate)}ms), low=$isLow');
    }
  }

  int _framesToBytes(int frames) => frames * _channels * _bytesPerSample;

  int _bytesToFrames(int bytes) => bytes ~/ (_channels * _bytesPerSample);

  void _emitLog(String message) {
    final line = '[AudioPlayerService] $message';
    log(line);
    debugPrint(line);
  }
}
