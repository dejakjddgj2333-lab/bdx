import 'audio_recorder_service.dart';

class AudioRecorderServiceImpl implements AudioRecorderService {
  @override
  int get recordedFrameCount => 0;

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<void> startRecording({
    required Function(List<int>) onData,
    Duration dropInitial = Duration.zero,
  }) async {
    throw UnsupportedError('当前平台不支持录音');
  }

  @override
  Future<void> stopRecording() async {}

  @override
  Future<void> dispose() async {}
}

AudioRecorderService createAudioRecorderService() => AudioRecorderServiceImpl();
