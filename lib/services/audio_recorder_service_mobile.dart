import 'dart:async';
import 'dart:developer';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart';
import 'audio_recorder_service.dart';

class AudioRecorderServiceImpl implements AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription? _subscription;
  bool _isRecording = false;
  int _frameCount = 0;

  @override
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  @override
  Future<void> startRecording({required Function(List<int>) onData}) async {
    if (_isRecording) {
      log('录音已经开启，忽略重复 start');
      return;
    }

    final hasPerm = await hasPermission();
    if (!hasPerm) throw Exception('没有麦克风权限');

    _frameCount = 0;
    _isRecording = true;
    log('录音启动');

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

    // record 插件启动时会重新配置 AVAudioSession（category / sampleRate），
    // 可能覆盖我们的 voiceChat / defaultToSpeaker 配置，导致播放端卡顿或路由异常。
    // 录音建立后立刻重新应用一次我们期望的会话配置。
    await _reassertAudioSession();
  }

  Future<void> _reassertAudioSession() async {
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
      await FlutterPcmSound.setPreferredSampleRate(24000);
      log('录音启动后重新应用音频会话: voiceChat + defaultToSpeaker, sampleRate=24000');
    } catch (e) {
      log('录音启动后音频会话配置失败: $e');
    }
  }

  @override
  Future<void> stopRecording() async {
    if (!_isRecording) {
      log('录音未开启，忽略 stop');
      return;
    }
    log('录音停止, 总帧数=$_frameCount');
    _isRecording = false;
    await _subscription?.cancel();
    _subscription = null;
    await _recorder.stop();
  }

  @override
  Future<void> dispose() async {
    await stopRecording();
    await _recorder.dispose();
  }
}

AudioRecorderService createAudioRecorderService() => AudioRecorderServiceImpl();
