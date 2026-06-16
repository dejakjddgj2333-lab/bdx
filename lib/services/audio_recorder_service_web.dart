import 'dart:async';
import 'dart:typed_data';
import 'audio_recorder_service.dart';

class AudioRecorderServiceImpl implements AudioRecorderService {
  @override
  int get recordedFrameCount => 0;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> startRecording({required Function(List<int>) onData}) async {
    throw UnsupportedError('Web 端暂不支持实时 PCM 录音');
  }

  @override
  Future<void> stopRecording() async {}

  @override
  Future<void> dispose() async {}
}

AudioRecorderService createAudioRecorderService() => AudioRecorderServiceImpl();
