import 'dart:convert';
import 'dart:typed_data';

class AudioUtils {
  AudioUtils._();

  /// Float32 转 Int16（H5 录音用）
  static Uint8List float32ToInt16(List<double> float32Array) {
    final buffer = Uint8List(float32Array.length * 2);
    final view = ByteData.view(buffer.buffer);
    for (var i = 0; i < float32Array.length; i++) {
      var s = (float32Array[i] * 32767).toInt();
      if (s > 32767) s = 32767;
      if (s < -32768) s = -32768;
      view.setInt16(i * 2, s, Endian.little);
    }
    return buffer;
  }

  /// PCM 转 Float32（H5 播放用）
  static List<double> pcmToFloat32(Uint8List pcmBytes) {
    final view = ByteData.view(pcmBytes.buffer, pcmBytes.offsetInBytes);
    final result = List<double>.filled(pcmBytes.length ~/ 2, 0.0);
    for (var i = 0; i < result.length; i++) {
      result[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return result;
  }

  /// PCM 封装为 WAV
  static Uint8List pcmToWav(Uint8List pcmData, int sampleRate, int channels) {
    final byteRate = sampleRate * channels * 2;
    final blockAlign = channels * 2;
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final buffer = Uint8List(fileSize + 8);
    final view = ByteData.view(buffer.buffer);
    var offset = 0;

    void writeString(String s) {
      for (final c in s.codeUnits) {
        view.setUint8(offset++, c);
      }
    }

    writeString('RIFF');
    view.setUint32(offset, fileSize, Endian.little);
    offset += 4;
    writeString('WAVE');
    writeString('fmt ');
    view.setUint32(offset, 16, Endian.little);
    offset += 4;
    view.setUint16(offset, 1, Endian.little); // PCM
    offset += 2;
    view.setUint16(offset, channels, Endian.little);
    offset += 2;
    view.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    view.setUint32(offset, byteRate, Endian.little);
    offset += 4;
    view.setUint16(offset, blockAlign, Endian.little);
    offset += 2;
    view.setUint16(offset, 16, Endian.little); // bits per sample
    offset += 2;
    writeString('data');
    view.setUint32(offset, dataSize, Endian.little);
    offset += 4;
    buffer.setAll(offset, pcmData);

    return buffer;
  }

  /// 流式 WAV 头（data chunk size 置为最大值，表示长度未知）
  static Uint8List streamingWavHeader(int sampleRate, int channels) {
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    const headerSize = 44;

    final buffer = Uint8List(headerSize);
    final view = ByteData.view(buffer.buffer);
    var offset = 0;

    void writeString(String s) {
      for (final c in s.codeUnits) {
        view.setUint8(offset++, c);
      }
    }

    writeString('RIFF');
    view.setUint32(offset, 0x7FFFFFFF, Endian.little);
    offset += 4;
    writeString('WAVE');
    writeString('fmt ');
    view.setUint32(offset, 16, Endian.little);
    offset += 4;
    view.setUint16(offset, 1, Endian.little); // PCM
    offset += 2;
    view.setUint16(offset, channels, Endian.little);
    offset += 2;
    view.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    view.setUint32(offset, byteRate, Endian.little);
    offset += 4;
    view.setUint16(offset, blockAlign, Endian.little);
    offset += 2;
    view.setUint16(offset, bitsPerSample, Endian.little);
    offset += 2;
    writeString('data');
    view.setUint32(offset, 0x7FFFFFFF, Endian.little);
    return buffer;
  }

  static Uint8List base64ToBytes(String base64String) {
    return base64Decode(base64String);
  }

  static String bytesToBase64(Uint8List bytes) {
    return base64Encode(bytes);
  }
}
