import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/utils/sse_fetcher_factory.dart';
import '../../data/datasources/local/secure_storage.dart';
import '../../data/datasources/remote/chat_api.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/voice_provider_config.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatApi _chatApi;
  final SecureStorage _secureStorage;

  ChatRepositoryImpl(this._chatApi, this._secureStorage);

  Map<String, dynamic> _unwrap(Response? response) {
    if (response?.data == null) throw const ServerException('响应为空');
    final data = response!.data as Map<String, dynamic>;
    if (data['code'] != 0) {
      throw ServerException(data['message']?.toString() ?? '请求失败');
    }
    return data;
  }

  @override
  Future<List<Map<String, dynamic>>> getModels() async {
    final res = await _chatApi.getModels();
    final data = _unwrap(res);
    final list = data['data'];
    if (list is List) {
      return list
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getPromptSuggestions() async {
    final res = await _chatApi.getPromptSuggestions();
    final data = _unwrap(res);
    final list = data['data'];
    if (list is List) {
      return list
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    return [];
  }

  @override
  Future<List<Conversation>> getConversations({int page = 1, int pageSize = 20}) async {
    final res = await _chatApi.getConversations({
      'page': page,
      'pageSize': pageSize,
    });
    final data = _unwrap(res);
    final list = data['data'] as List<dynamic>?;
    return list?.map((e) => _mapConversation(e as Map<String, dynamic>)).toList() ?? [];
  }

  @override
  Future<Conversation> createConversation({
    required String title,
    String? model,
    String? agentId,
  }) async {
    final res = await _chatApi.createConversation({
      'title': title,
      'model': model,
      'agentId': agentId,
    });
    final data = _unwrap(res);
    return _mapConversation(data['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> updateConversation(String id, {String? title}) async {
    await _chatApi.updateConversation(id, {'title': title});
  }

  @override
  Future<void> deleteConversation(String id) async {
    await _chatApi.deleteConversation(id);
  }

  @override
  Future<List<Message>> getMessages(String id, {int page = 1, int pageSize = 50}) async {
    final res = await _chatApi.getMessages(id, {
      'page': page,
      'pageSize': pageSize,
    });
    final data = _unwrap(res);
    final list = data['data'] as List<dynamic>?;
    return list?.map((e) => _mapMessage(e as Map<String, dynamic>)).toList() ?? [];
  }

  @override
  Future<Message> sendMessage({
    required String conversationId,
    required dynamic content,
    String? model,
  }) async {
    final res = await _chatApi.sendMessage({
      'conversationId': conversationId,
      'content': content,
      'model': model,
    });
    final data = _unwrap(res);
    return _mapMessage(data['data'] as Map<String, dynamic>);
  }

  @override
  Stream<Map<String, dynamic>> streamChat({
    required String conversationId,
    required dynamic content,
    String? model,
  }) async* {
    if (kIsWeb) {
      yield* _streamChatWeb(conversationId, content, model);
      return;
    }

    final response = await _chatApi.streamChat({
      'conversationId': conversationId,
      'content': content,
      'model': model,
    });

    final rawStream = response.data.stream as Stream;
    final stream = rawStream.cast<List<int>>();
    var partialChunk = '';

    await for (final chunk in stream.transform(utf8.decoder)) {
      log('SSE 原始 chunk 到达: ${chunk.length} 字符', name: 'ChatRepository');
      partialChunk += chunk;
      final lines = partialChunk.split('\n');
      partialChunk = lines.removeLast();

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('data: ')) {
          try {
            final data = jsonDecode(trimmed.substring(6)) as Map<String, dynamic>;
            log('SSE 解析数据: $data', name: 'ChatRepository');
            yield data;
          } catch (_) {
            // 忽略解析错误
          }
        }
      }
    }

    if (partialChunk.trim().startsWith('data: ')) {
      try {
        final data = jsonDecode(partialChunk.trim().substring(6)) as Map<String, dynamic>;
        yield data;
      } catch (_) {}
    }

    yield {'done': true};
  }

  Stream<Map<String, dynamic>> _streamChatWeb(
    String conversationId,
    dynamic content,
    String? model,
  ) async* {
    final baseUrl = _chatApi.dio.options.baseUrl;
    final url = '$baseUrl${ApiConstants.streamChat}';
    final token = await _secureStorage.getToken();

    final stream = createSseFetcher().fetchStream(
      url: url,
      body: {
        'conversationId': conversationId,
        'content': content,
        'model': model,
      },
      token: token,
    );

    var partialChunk = '';

    await for (final chunk in stream) {
      log('SSE Web chunk 到达: ${chunk.length} 字符', name: 'ChatRepository');
      partialChunk += chunk;
      final lines = partialChunk.split('\n');
      partialChunk = lines.removeLast();

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('data: ')) {
          try {
            final data = jsonDecode(trimmed.substring(6)) as Map<String, dynamic>;
            log('SSE Web 解析数据: $data', name: 'ChatRepository');
            yield data;
          } catch (_) {
            // 忽略解析错误
          }
        }
      }
    }

    if (partialChunk.trim().startsWith('data: ')) {
      try {
        final data = jsonDecode(partialChunk.trim().substring(6)) as Map<String, dynamic>;
        yield data;
      } catch (_) {}
    }

    yield {'done': true};
  }

  @override
  Future<String> uploadImageBytes(Uint8List bytes, {String? filename}) async {
    Uint8List data = bytes;

    if (!kIsWeb) {
      try {
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          quality: 80,
        );
        if (compressed != null && compressed.isNotEmpty) {
          data = compressed;
        }
      } catch (_) {
        // 压缩失败时直接上传原图
      }
    }

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        data,
        filename: filename ?? 'image.jpg',
      ),
    });

    final res = await _chatApi.uploadImage(formData);
    final dataMap = _unwrap(res);
    return dataMap['data']['url'].toString();
  }

  Conversation _mapConversation(Map<String, dynamic> json) {
    return Conversation(
      id: json['id']?.toString(),
      title: json['title']?.toString(),
      model: json['model']?.toString(),
      agentId: (json['agentId'] ?? json['agent_id'])?.toString(),
      agent: json['agent'] as Map<String, dynamic>?,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['last_message_at']) ??
          _parseDate(json['updatedAt'] ?? json['updated_at']) ??
          _parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  Message _mapMessage(Map<String, dynamic> json) {
    return Message(
      id: json['id']?.toString(),
      role: json['role']?.toString(),
      content: json['content'],
      contentType: json['contentType']?.toString(),
      model: json['model']?.toString(),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  @override
  Future<VoiceProviderConfig> getVoiceProviderConfig() async {
    final res = await _chatApi.getVoiceProvider();
    final data = _unwrap(res);
    final payload = data['data'];
    if (payload is Map<String, dynamic>) {
      return VoiceProviderConfig.fromJson(payload);
    }
    return const VoiceProviderConfig(
      provider: 'qwen',
      name: '阿里百炼实时多模态',
      voices: ['zhiyan', 'xiaogang', 'xiaomei'],
      voiceLabels: {
        'zhiyan': '知言',
        'xiaogang': '小刚',
        'xiaomei': '小美',
      },
      defaultVoice: 'zhiyan',
    );
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
