import 'dart:async';
import 'dart:developer';
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
