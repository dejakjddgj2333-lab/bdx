import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart';
import 'audio_recorder_service.dart';

/// 跨平台录音实现。
///
/// iOS 使用 flutter_pcm_sound 内置的 VoiceProcessingIO 录音，和 playback 走同一个
/// AudioUnit，从而让系统 AEC 拿到输出参考信号，抑制扬声器回声。
/// Android 继续用 record 插件。
class AudioRecorderServiceImpl implements AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription? _subscription;
  bool _isRecording = false;
  int _frameCount = 0;
  _Pcm16Resampler? _resampler;

  @override
  Future<bool> hasPermission() async {
    if (Platform.isIOS) {
      // iOS 权限由 flutter_pcm_sound 通过 AVAudioSession 隐式触发；
      // 这里始终返回 true，真正无权限时 startRecording 会失败。
      return true;
    }
    return await _recorder.hasPermission();
  }

  @override
  Future<void> startRecording({required Function(List<int>) onData}) async {
    if (_isRecording) {
      log('录音已经开启，忽略重复 start');
      return;
    }

    _frameCount = 0;
    _isRecording = true;
    log('录音启动');

    if (Platform.isIOS) {
      _resampler = _Pcm16Resampler(fromRate: 24000, toRate: 16000);
      final stream = FlutterPcmSound.startRecording();
      _subscription = stream.listen(
        (bytes) {
          final resampled = _resampler!.resample(bytes);
          if (resampled.isEmpty) return;
          _frameCount++;
          if (_frameCount <= 3 || _frameCount % 100 == 0) {
            log('iOS 录音帧 #$_frameCount, 原始=${bytes.length}, 重采样后=${resampled.length}');
          }
          onData(resampled.toList());
        },
        onError: (e) {
          log('iOS 录音错误: $e');
          _isRecording = false;
        },
        onDone: () {
          _isRecording = false;
        },
      );
      return;
    }

    // Android / 其他平台继续使用 record 插件
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) throw Exception('没有麦克风权限');

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );

    _subscription = stream.listen((bytes) {
      _frameCount++;
      if (_frameCount <= 3 || _frameCount % 100 == 0) {
        log('录音帧 #$_frameCount, 长度=${bytes.length}');
      }
      onData(bytes.toList());
    }, onError: (e) {
      log('录音错误: $e');
      _isRecording = false;
    }, onDone: () {
      _isRecording = false;
    });
  }

  @override
  Future<void> stopRecording() async {
    if (!_isRecording) {
      log('录音未开启，忽略 stop');
      return;
    }
    log('录音停止, 总帧数=$_frameCount');
    _isRecording = false;

    if (Platform.isIOS) {
      await FlutterPcmSound.stopRecording();
    } else {
      await _subscription?.cancel();
      _subscription = null;
      await _recorder.stop();
    }
  }

  @override
  Future<void> dispose() async {
    await stopRecording();
    if (!Platform.isIOS) {
      await _recorder.dispose();
    }
  }
}

/// 简单的 PCM16 线性重采样器（24kHz -> 16kHz 等固定比例）。
class _Pcm16Resampler {
  final int fromRate;
  final int toRate;
  final List<int> _leftover = [];

  _Pcm16Resampler({required this.fromRate, required this.toRate});

  Uint8List resample(Uint8List input) {
    final all = Uint8List(_leftover.length + input.length);
    all.setAll(0, _leftover);
    all.setAll(_leftover.length, input);
    _leftover.clear();

    final totalFrames = all.length ~/ 2;
    final outFrames = (totalFrames * toRate) ~/ fromRate;
    if (outFrames == 0) {
      _leftover.addAll(all);
      return Uint8List(0);
    }

    final consumedFrames = (outFrames * fromRate) ~/ toRate;
    final consumedBytes = consumedFrames * 2;
    if (consumedBytes < all.length) {
      _leftover.addAll(all.sublist(consumedBytes));
    }

    final output = Uint8List(outFrames * 2);
    final inView = ByteData.sublistView(all);
    final outView = ByteData.sublistView(output);
    final ratio = fromRate / toRate;

    for (var i = 0; i < outFrames; i++) {
      final srcIdx = i * ratio;
      final i0 = srcIdx.floor();
      final i1 = math.min(i0 + 1, totalFrames - 1);
      final frac = srcIdx - i0;
      final s0 = inView.getInt16(i0 * 2, Endian.little);
      final s1 = inView.getInt16(i1 * 2, Endian.little);
      final sample = (s0 + (s1 - s0) * frac).round().clamp(-32768, 32767);
      outView.setInt16(i * 2, sample, Endian.little);
    }

    return output;
  }
}

AudioRecorderService createAudioRecorderService() => AudioRecorderServiceImpl();
