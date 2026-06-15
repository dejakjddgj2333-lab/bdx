part of 'chat_detail_bloc.dart';

abstract class ChatDetailState extends Equatable {
  final String? conversationId;
  final String? agentId;
  final List<Message> messages;
  final List<Map<String, dynamic>> models;
  final List<Map<String, dynamic>> suggestions;
  final String? currentModel;
  final bool isSending;
  final bool isLoadingHistory;
  final List<String> pendingImages;
  final String? error;

  const ChatDetailState({
    this.conversationId,
    this.agentId,
    this.messages = const [],
    this.models = const [],
    this.suggestions = const [],
    this.currentModel,
    this.isSending = false,
    this.isLoadingHistory = false,
    this.pendingImages = const [],
    this.error,
  });

  ChatDetailState copyWith({
    String? conversationId,
    String? agentId,
    List<Message>? messages,
    List<Map<String, dynamic>>? models,
    List<Map<String, dynamic>>? suggestions,
    String? currentModel,
    bool? isSending,
    bool? isLoadingHistory,
    List<String>? pendingImages,
    String? error,
    bool clearError = false,
  });

  @override
  List<Object?> get props => [
        conversationId,
        agentId,
        messages,
        models,
        suggestions,
        currentModel,
        isSending,
        isLoadingHistory,
        pendingImages,
        error,
      ];
}

class ChatDetailInitial extends ChatDetailState {
  const ChatDetailInitial() : super();

  @override
  ChatDetailState copyWith({
    String? conversationId,
    String? agentId,
    List<Message>? messages,
    List<Map<String, dynamic>>? models,
    List<Map<String, dynamic>>? suggestions,
    String? currentModel,
    bool? isSending,
    bool? isLoadingHistory,
    List<String>? pendingImages,
    String? error,
    bool clearError = false,
  }) {
    return ChatDetailUpdated(
      conversationId: conversationId ?? this.conversationId,
      agentId: agentId ?? this.agentId,
      messages: messages ?? this.messages,
      models: models ?? this.models,
      suggestions: suggestions ?? this.suggestions,
      currentModel: currentModel ?? this.currentModel,
      isSending: isSending ?? this.isSending,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      pendingImages: pendingImages ?? this.pendingImages,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ChatDetailUpdated extends ChatDetailState {
  const ChatDetailUpdated({
    super.conversationId,
    super.agentId,
    super.messages,
    super.models,
    super.suggestions,
    super.currentModel,
    super.isSending,
    super.isLoadingHistory,
    super.pendingImages,
    super.error,
  });

  @override
  ChatDetailState copyWith({
    String? conversationId,
    String? agentId,
    List<Message>? messages,
    List<Map<String, dynamic>>? models,
    List<Map<String, dynamic>>? suggestions,
    String? currentModel,
    bool? isSending,
    bool? isLoadingHistory,
    List<String>? pendingImages,
    String? error,
    bool clearError = false,
  }) {
    return ChatDetailUpdated(
      conversationId: conversationId ?? this.conversationId,
      agentId: agentId ?? this.agentId,
      messages: messages ?? this.messages,
      models: models ?? this.models,
      suggestions: suggestions ?? this.suggestions,
      currentModel: currentModel ?? this.currentModel,
      isSending: isSending ?? this.isSending,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      pendingImages: pendingImages ?? this.pendingImages,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
