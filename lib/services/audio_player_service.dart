import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';

/// 使用 flutter_sound 的流式 PCM 播放器。
///
/// 相比通过 WAV 头包装后再喂给 just_audio，这种方式直接把 16bit PCM
/// 数据写入播放器的 foodSink，延迟更低、兼容性更好。
class AudioPlayerService {
  FlutterSoundPlayer? _player;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await dispose();

    try {
      _player = FlutterSoundPlayer();
      await _player!.openPlayer();
      await _player!.startPlayerFromStream(
        codec: Codec.pcm16,
        interleaved: true,
        numChannels: 1,
        sampleRate: 24000,
        bufferSize: 8192,
      );
      _initialized = true;
      log('音频播放器初始化完成 (flutter_sound)');
    } catch (e) {
      log('音频播放器初始化失败: $e');
      await dispose();
      rethrow;
    }
  }

  Future<void> setSpeaker(bool useSpeaker) async {
    // TODO: 实现扬声器/听筒切换
  }

  /// 直接把 AI 返回的 PCM 数据喂给播放器。
  void handleAudioData(Uint8List pcmData) {
    if (!_initialized || _player == null) return;
    _player!.uint8ListSink?.add(pcmData);
  }

  /// 停止当前播放。
  void cancelPlaying() {
    _player?.stopPlayer();
  }

  /// flutter_sound 是流式播放，不需要额外 flush。
  Future<void> flushAccumulatedAudio() async {}

  /// 流式播放器不会被“卡死”，这里保留接口但始终返回 false。
  bool get isStuck => false;

  void forceReset() {}

  Future<void> dispose() async {
    _initialized = false;

    final player = _player;
    _player = null;

    if (player != null) {
      try {
        await player.stopPlayer();
      } catch (e) {
        log('停止播放器失败: $e');
      }
      try {
        await player.closePlayer();
      } catch (e) {
        log('关闭播放器失败: $e');
      }
    }
  }
}
