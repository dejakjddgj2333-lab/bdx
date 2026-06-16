import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

/// 流式 PCM 播放器（基于 flutter_pcm_sound）。
///
/// 直接播放后端返回的 PCM 裸流，无需 WAV 头或 HTTP 代理。
class AudioPlayerService {
  bool _initialized = false;
  DateTime? _playStartTime;

  static const int _sampleRate = 24000;
  static const int _channels = 1;

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
      _emitLog('音频会话配置完成: voiceChat + defaultToSpeaker');
    } catch (e) {
      _emitLog('音频会话配置失败: $e');
    }

    _initialized = true;
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

  /// 接收 AI 返回的 PCM 数据并直接喂给播放器。
  void handleAudioData(Uint8List pcmData) {
    if (!_initialized) {
      _emitLog('handleAudioData: 播放器未初始化，忽略 ${pcmData.length} bytes');
      return;
    }
    try {
      final pcmArray = PcmArrayInt16(
        bytes: ByteData.sublistView(pcmData),
      );
      FlutterPcmSound.feed(pcmArray);
      _playStartTime = DateTime.now();
      _emitLog('handleAudioData: 投喂 ${pcmData.length} bytes');
    } catch (e) {
      _emitLog('handleAudioData: 投喂失败 $e');
    }
  }

  /// 停止当前播放并清空缓冲。
  Future<void> cancelPlaying() async {
    _playStartTime = null;
    try {
      // flutter_pcm_sound 没有单独 pause/stop/clear 接口，release 会释放资源。
      await FlutterPcmSound.release();
      _emitLog('cancelPlaying: 已 release');
    } catch (e) {
      _emitLog('cancelPlaying 失败: $e');
    }
  }

  /// 把尾部累积数据一次性推入流（flutter_pcm_sound 实时性高，这里只保留接口兼容）。
  Future<void> flushAccumulatedAudio() async {
    _playStartTime = DateTime.now();
    _emitLog('flushAccumulatedAudio: 无实际缓冲，仅刷新时间戳');
  }

  /// 如果播放器超过 8 秒没有收到新数据，认为卡死。
  bool get isStuck {
    if (!_initialized || _playStartTime == null) return false;
    return DateTime.now().difference(_playStartTime!).inSeconds > 8;
  }

  Future<void> forceReset() async {
    _emitLog('AudioPlayer 长时间无数据，强制重置');
    _playStartTime = null;
    await dispose();
    await init();
  }

  Future<void> dispose() async {
    _initialized = false;
    _playStartTime = null;

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

  void _emitLog(String message) {
    log(message);
  }
}
