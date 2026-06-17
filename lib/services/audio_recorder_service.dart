
export 'audio_recorder_service_stub.dart'
    if (dart.library.html) 'audio_recorder_service_web.dart'
    if (dart.library.io) 'audio_recorder_service_mobile.dart';

abstract class AudioRecorderService {
  int get recordedFrameCount;
  Future<bool> hasPermission();

  /// 开始录音。
  ///
  /// [dropInitial] 用于在重新开麦时丢弃前 N 毫秒的音频，避免把扬声器尾音/房间混响
  /// 当作人声发送给服务端。
  Future<void> startRecording({
    required Function(List<int>) onData,
    Duration dropInitial = Duration.zero,
  });

  Future<void> stopRecording();
  Future<void> dispose();
}
