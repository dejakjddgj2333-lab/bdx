import 'dart:typed_data';
import '../entities/conversation.dart';
import '../entities/message.dart';
import '../entities/voice_provider_config.dart';

abstract class ChatRepository {
  Future<List<Map<String, dynamic>>> getModels();
  Future<List<Map<String, dynamic>>> getPromptSuggestions();
  Future<List<Conversation>> getConversations({int page = 1, int pageSize = 20});
  Future<Conversation> createConversation({required String title, String? model, String? agentId});
  Future<void> updateConversation(String id, {String? title});
  Future<void> deleteConversation(String id);
  Future<List<Message>> getMessages(String id, {int page = 1, int pageSize = 50});
  Future<Message> sendMessage({required String conversationId, required dynamic content, String? model});
  Stream<Map<String, dynamic>> streamChat({
    required String conversationId,
    required dynamic content,
    String? model,
    String? systemPrompt,
  });
  Future<String> uploadImageBytes(Uint8List bytes, {String? filename});
  Future<VoiceProviderConfig> getVoiceProviderConfig();
}
