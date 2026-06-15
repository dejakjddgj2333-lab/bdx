import 'audio_recorder_service_stub.dart'
    if (dart.library.html) 'audio_recorder_service_web.dart'
    if (dart.library.io) 'audio_recorder_service_mobile.dart';

export 'audio_recorder_service_stub.dart'
    if (dart.library.html) 'audio_recorder_service_web.dart'
    if (dart.library.io) 'audio_recorder_service_mobile.dart';

abstract class AudioRecorderService {
  Future<bool> hasPermission();
  Future<void> startRecording({required Function(List<int>) onData});
  Future<void> stopRecording();
  Future<void> dispose();
}
