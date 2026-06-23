part of 'chat_detail_bloc.dart';

abstract class ChatDetailEvent extends Equatable {
  const ChatDetailEvent();

  @override
  List<Object?> get props => [];
}

class ChatDetailInitialized extends ChatDetailEvent {
  final String? conversationId;
  final String? agentId;
  final String? initialModel;
  final List<Map<String, dynamic>>? initialModels;
  final String scene;

  const ChatDetailInitialized({
    this.conversationId,
    this.agentId,
    this.initialModel,
    this.initialModels,
    this.scene = 'assistant',
  });

  @override
  List<Object?> get props => [conversationId, agentId, initialModel, initialModels, scene];
}

class ChatDetailMessagesLoaded extends ChatDetailEvent {
  final String conversationId;

  const ChatDetailMessagesLoaded(this.conversationId);

  @override
  List<Object?> get props => [conversationId];
}

class ChatDetailMessageSent extends ChatDetailEvent {
  final String text;

  const ChatDetailMessageSent(this.text);

  @override
  List<Object?> get props => [text];
}

class ChatDetailStreamChunk extends ChatDetailEvent {
  final Map<String, dynamic> chunk;

  const ChatDetailStreamChunk(this.chunk);

  @override
  List<Object?> get props => [chunk];
}

class ChatDetailStreamCompleted extends ChatDetailEvent {
  const ChatDetailStreamCompleted();
}

class ChatDetailModelSelected extends ChatDetailEvent {
  final String modelId;

  const ChatDetailModelSelected(this.modelId);

  @override
  List<Object?> get props => [modelId];
}

class ChatDetailCleared extends ChatDetailEvent {
  const ChatDetailCleared();
}

class ChatDetailImageAdded extends ChatDetailEvent {
  final String url;

  const ChatDetailImageAdded(this.url);

  @override
  List<Object?> get props => [url];
}

class ChatDetailImageRemoved extends ChatDetailEvent {
  final int index;

  const ChatDetailImageRemoved(this.index);

  @override
  List<Object?> get props => [index];
}

class ChatDetailImageUploaded extends ChatDetailEvent {
  final Uint8List bytes;
  final String? filename;

  const ChatDetailImageUploaded(this.bytes, {this.filename});

  @override
  List<Object?> get props => [bytes, filename];
}

class ChatDetailTypingTick extends ChatDetailEvent {
  const ChatDetailTypingTick();
}

class ChatDetailModelsReloadRequested extends ChatDetailEvent {
  const ChatDetailModelsReloadRequested();
}
