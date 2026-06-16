import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';

class ChatApi {
  final Dio _dio;

  ChatApi(this._dio);

  Dio get dio => _dio;

  Future<Response> getModels() async {
    return _dio.get(ApiConstants.models);
  }

  Future<Response> getPromptSuggestions() async {
    return _dio.get(ApiConstants.promptSuggestions);
  }

  Future<Response> getConversations(Map<String, dynamic> queries) async {
    return _dio.get(ApiConstants.conversations, queryParameters: queries);
  }

  Future<Response> createConversation(Map<String, dynamic> body) async {
    return _dio.post(ApiConstants.conversations, data: body);
  }

  Future<Response> updateConversation(String id, Map<String, dynamic> body) async {
    return _dio.put('${ApiConstants.conversations}/$id', data: body);
  }

  Future<Response> deleteConversation(String id) async {
    return _dio.delete('${ApiConstants.conversations}/$id');
  }

  Future<Response> getMessages(String id, Map<String, dynamic> queries) async {
    return _dio.get('${ApiConstants.conversations}/$id/messages', queryParameters: queries);
  }

  Future<Response> sendMessage(Map<String, dynamic> body) async {
    return _dio.post(ApiConstants.sendMessage, data: body);
  }

  Future<Response> streamChat(Map<String, dynamic> body) async {
    return _dio.post(
      ApiConstants.streamChat,
      data: body,
      options: Options(responseType: ResponseType.stream),
    );
  }

  Future<Response> uploadImage(FormData formData) async {
    return _dio.post(ApiConstants.uploadImage, data: formData);
  }

  Future<Response> getVoiceProvider() async {
    return _dio.get(ApiConstants.voiceProvider);
  }
}
