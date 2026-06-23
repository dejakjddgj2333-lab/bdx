import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/constants/api_constants.dart';
import '../core/utils/audio_utils.dart';
import '../data/datasources/local/secure_storage.dart';

class WebSocketService {
  final SecureStorage _secureStorage;
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _audioController = StreamController<List<int>>.broadcast();
  String? _currentResponseId;
  double _currentVadThreshold = 0.3;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<List<int>> get audioStream => _audioController.stream;

  WebSocketService(this._secureStorage);

  Future<void> connect({String? voice}) async {
    _currentResponseId = null;
    final token = await _secureStorage.getToken();
    var url = '${ApiConstants.wsUrl}?token=$token';
    if (voice != null && voice.isNotEmpty) {
      url += '&voice=${Uri.encodeComponent(voice)}';
    }
    final uri = Uri.parse(url);
    log('WebSocket 连接: $uri');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (event) {
        try {
          if (event is List<int>) {
            log('收到二进制帧, 长度=${event.length}');
            _handleBinary(event);
          } else {
            final text = event.toString();
            log('收到文本: ${text.length > 200 ? text.substring(0, 200) : text}');
            final data = jsonDecode(text) as Map<String, dynamic>;
            _handleMessage(data);
          }
        } catch (e) {
          log('WebSocket 消息处理错误: $e');
        }
      },
      onError: (error) {
        log('WebSocket 错误: $error');
        _messageController.add({'type': 'error', 'error': error.toString()});
      },
      onDone: () {
        log('WebSocket 关闭');
        _messageController.add({'type': 'closed'});
      },
    );
  }

  void _handleBinary(List<int> bytes) {
    try {
      final text = utf8.decode(bytes);
      final trimmed = text.trim();
      if (trimmed.startsWith('{')) {
        final data = jsonDecode(text) as Map<String, dynamic>;
        _handleMessage(data);
        return;
      }
    } catch (_) {}
    _audioController.add(bytes);
  }

  void _handleMessage(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    log('收到消息类型: $type');

    if (type == 'response.created') {
      _currentResponseId = data['response_id']?.toString();
      log('当前响应 id: $_currentResponseId');
    } else if (type == 'response.done' ||
        type == 'response.cancelled' ||
        type == 'response.output_item.done') {
      _currentResponseId = null;
    }

    if (type == 'response.audio.delta') {
      final delta = data['delta']?.toString() ?? '';
      if (delta.isNotEmpty) {
        final responseId = data['response_id']?.toString();
        if (_currentResponseId != null &&
            responseId != null &&
            responseId != _currentResponseId) {
          log('忽略过期 response 音频: $responseId');
        } else {
          final bytes = AudioUtils.base64ToBytes(delta);
          log('收到 response.audio.delta, ${bytes.length} bytes');
          _audioController.add(bytes.toList());
        }
      }
    }

    _messageController.add(data);
  }

  void sendConfig({String? voice}) {
    final config = {
      'event_id': 'event_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'session.update',
      'session': {
        'modalities': ['text', 'audio'],
        'instructions': '你是北斗星AI，一个 helpful 的语音助手，请用中文回答用户问题。',
        'voice': voice ?? 'coral',
        'turn_detection': {
          'type': 'server_vad',
          'threshold': 0.4,
          'prefix_padding_ms': 300,
          'silence_duration_ms': 1200,
        },
      },
    };
    log('发送 session.update: $config');
    send(config);
  }

  void updateVadThreshold(double threshold) {
    if ((threshold - _currentVadThreshold).abs() < 0.001) {
      return;
    }
    _currentVadThreshold = threshold;
    final config = {
      'event_id': 'event_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'session.update',
      'session': {
        'turn_detection': {
          'type': 'server_vad',
          'threshold': threshold,
          'prefix_padding_ms': 300,
          'silence_duration_ms': 1200,
        },
      },
    };
    log('发送 VAD threshold=$threshold');
    send(config);
  }

  int _audioSendCount = 0;
  int get audioSendCount => _audioSendCount;

  void sendAudio(List<int> pcmData) {
    final base64 = AudioUtils.bytesToBase64(Uint8List.fromList(pcmData));
    _audioSendCount++;
    if (_audioSendCount <= 3 || _audioSendCount % 100 == 0) {
      log('发送 input_audio_buffer.append #$_audioSendCount, ${pcmData.length} bytes');
    }
    send({
      'type': 'input_audio_buffer.append',
      'audio': base64,
    });
  }

  void send(Map<String, dynamic> data) {
    if (_channel == null) {
      log('WebSocket 未连接，无法发送: ${data['type']}');
      return;
    }
    final text = jsonEncode(data);
    if (data['type'] != 'input_audio_buffer.append') {
      log('发送: ${text.length > 200 ? text.substring(0, 200) : text}');
    }
    try {
      _channel!.sink.add(text);
    } catch (e) {
      log('WebSocket 发送失败: $e');
    }
  }

  void disconnect() {
    log('WebSocket 断开');
    _currentResponseId = null;
    try {
      _channel?.sink.close();
    } catch (e) {
      log('WebSocket sink 关闭失败: $e');
    }
    _channel = null;
  }

  /// 应用退出时调用。关闭 channel 和 controller；
  /// 此后该实例不可复用，如需重新连接请重新实例化服务。
  void dispose() {
    disconnect();
    if (!_messageController.isClosed) _messageController.close();
    if (!_audioController.isClosed) _audioController.close();
  }
}
