import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:record_platform_interface/record_platform_interface.dart';

class RecordPluginWebStub extends RecordPlatform {
  static void registerWith(Registrar registrar) {
    RecordPlatform.instance = RecordPluginWebStub();
  }

  @override
  Future<void> create(String recorderId) async {}

  @override
  Future<void> dispose(String recorderId) async {}

  @override
  Future<void> start(
    String recorderId,
    RecordConfig config, {
    String? path,
  }) async {
    throw UnsupportedError('Web 端暂不支持录音');
  }

  @override
  Future<Stream<Uint8List>> startStream(
    String recorderId,
    RecordConfig config,
  ) async {
    throw UnsupportedError('Web 端暂不支持录音');
  }

  @override
  Future<String?> stop(String recorderId) async => null;

  @override
  Future<void> pause(String recorderId) async {}

  @override
  Future<void> resume(String recorderId) async {}

  @override
  Future<void> cancel(String recorderId) async {}

  @override
  Future<bool> hasPermission(
    String recorderId, {
    bool request = true,
  }) async => true;

  @override
  Future<bool> isEncoderSupported(
    String recorderId,
    AudioEncoder encoder,
  ) async => false;

  @override
  Future<bool> isPaused(String recorderId) async => false;

  @override
  Future<bool> isRecording(String recorderId) async => false;

  @override
  Future<Amplitude> getAmplitude(String recorderId) async =>
      Amplitude(current: -160.0, max: -160.0);

  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) async => [];

  @override
  Stream<RecordState> onStateChanged(String recorderId) =>
      const Stream.empty();

  @override
  void setOnConfigChanged(
    String recorderId,
    void Function(RecordConfig config)? onChanged,
  ) {}

}
