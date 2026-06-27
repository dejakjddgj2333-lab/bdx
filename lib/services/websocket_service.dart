import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/constants/api_constants.dart';
import '../core/utils/audio_utils.dart';
import '../data/datasources/local/secure_storage.dart';

/// 语音通话 WebSocket（阶段二：方舟 Plan ASR/TTS 编排协议）
///
/// 上行：{ type:'audio', audio:base64 }  PCM16 16kHz
///      { type:'stop' }
/// 下行：{ type:'state', state }         listening/thinking/speaking/interrupted
///      { type:'asr.text', text, isFinal }
///      { type:'llm.text', text }
///      { type:'tts.audio', audio:base64 }  PCM16 24kHz
///      { type:'turn.end' }
///      { type:'error', message }
class WebSocketService {
  final SecureStorage _secureStorage;
  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _audioController = StreamController<List<int>>.broadcast();
  int _audioSendCount = 0;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<List<int>> get audioStream => _audioController.stream;

  WebSocketService(this._secureStorage);

  Future<void> connect({String? voice, String? prompt}) async {
    final token = await _secureStorage.getToken();
    var url = '${ApiConstants.wsUrl}?token=$token';
    if (voice != null && voice.isNotEmpty) {
      url += '&voice=${Uri.encodeComponent(voice)}';
    }
    if (prompt != null && prompt.isNotEmpty) {
      url += '&prompt=${Uri.encodeComponent(prompt)}';
    }
    final uri = Uri.parse(url);
    print('🔴[ws] 连接: $uri');
    await _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel = WebSocketChannel.connect(uri);

    _channelSubscription = _channel!.stream.listen(
      (event) {
        try {
          // event 可能是 String（文本帧）或 List<int>（二进制帧）
          String text;
          if (event is String) {
            text = event;
          } else if (event is List) {
            text = utf8.decode(List<int>.from(event));
          } else {
            text = event.toString();
          }
          print('🔴[ws] 收到: ${text.length > 300 ? text.substring(0, 300) : text}');
          final data = jsonDecode(text) as Map<String, dynamic>;
          _handleMessage(data);
        } catch (e) {
          log('WebSocket 消息处理错误: $e');
        }
      },
      onError: (error) {
        log('WebSocket 错误: $error');
        _messageController.add({'type': 'error', 'message': error.toString()});
      },
      onDone: () {
        log('WebSocket 关闭');
        _messageController.add({'type': 'closed'});
      },
    );
  }

  void _handleMessage(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';

    if (type == 'tts.audio') {
      final audioBase64 = data['audio']?.toString() ?? '';
      if (audioBase64.isNotEmpty) {
        final bytes = AudioUtils.base64ToBytes(audioBase64);
        _audioController.add(bytes.toList());
      }
      return; // 音频不入 message 流
    }

    _messageController.add(data);
  }

  /// 发送录音 PCM16 音频块（base64）
  void sendAudio(List<int> pcmData) {
    final base64 = AudioUtils.bytesToBase64(Uint8List.fromList(pcmData));
    _audioSendCount++;
    if (_audioSendCount <= 5) {
      print('🔴[ws] sendAudio #$_audioSendCount, ${pcmData.length} bytes, ws状态=${_channel?.closeCode}');
    }
    send({'type': 'audio', 'audio': base64});
  }

  /// 通知结束（可选，依赖静音 VAD）
  void sendAudioEnd() {
    send({'type': 'audio.end'});
  }

  /// 停止通话
  void sendStop() {
    send({'type': 'stop'});
  }

  void send(Map<String, dynamic> data) {
    if (_channel == null) {
      log('WebSocket 未连接，无法发送: ${data['type']}');
      return;
    }
    final text = jsonEncode(data);
    if (data['type'] != 'audio') {
      log('发送: $text');
    }
    try {
      _channel!.sink.add(text);
    } catch (e) {
      log('WebSocket 发送失败: $e');
    }
  }

  void disconnect() {
    log('WebSocket 断开');
    _channelSubscription?.cancel();
    _channelSubscription = null;
    try {
      _channel?.sink.close();
    } catch (e) {
      log('WebSocket sink 关闭失败: $e');
    }
    _channel = null;
  }

  void dispose() {
    disconnect();
    if (!_messageController.isClosed) _messageController.close();
    if (!_audioController.isClosed) _audioController.close();
  }
}
