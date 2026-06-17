import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/message.dart';
import '../../../domain/repositories/chat_repository.dart';

part 'chat_detail_event.dart';
part 'chat_detail_state.dart';

class ChatDetailBloc extends Bloc<ChatDetailEvent, ChatDetailState> {
  final ChatRepository _chatRepository;
  StreamSubscription<Map<String, dynamic>>? _streamSubscription;
  final StringBuffer _typingBuffer = StringBuffer();
  Timer? _typingTimer;

  ChatDetailBloc(this._chatRepository) : super(const ChatDetailInitial()) {
    on<ChatDetailInitialized>(_onInitialized);
    on<ChatDetailMessagesLoaded>(_onMessagesLoaded);
    on<ChatDetailMessageSent>(_onMessageSent);
    on<ChatDetailStreamChunk>(_onStreamChunk);
    on<ChatDetailStreamCompleted>(_onStreamCompleted);
    on<ChatDetailModelSelected>(_onModelSelected);
    on<ChatDetailCleared>(_onCleared);
    on<ChatDetailImageAdded>(_onImageAdded);
    on<ChatDetailImageRemoved>(_onImageRemoved);
    on<ChatDetailImageUploaded>(_onImageUploaded);
    on<ChatDetailTypingTick>(_onTypingTick);
    on<ChatDetailModelsReloadRequested>(_onModelsReloadRequested);
  }

  Future<void> _onInitialized(
    ChatDetailInitialized event,
    Emitter<ChatDetailState> emit,
  ) async {
    emit(state.copyWith(
      conversationId: event.conversationId,
      agentId: event.agentId,
      currentModel: event.initialModel,
    ));

    if (event.conversationId != null) {
      add(ChatDetailMessagesLoaded(event.conversationId!));
    }

    if (event.initialModels != null && event.initialModels!.isNotEmpty) {
      emit(state.copyWith(models: event.initialModels, clearError: true));
      _ensureCurrentModel(emit);
    } else {
      await _loadModels(emit);
    }
    await _loadSuggestions(emit);
  }

  Future<void> _loadModels(Emitter<ChatDetailState> emit) async {
    try {
      final models = await _chatRepository.getModels();
      log('加载模型列表成功: ${models.length} 个', name: 'ChatDetailBloc');
      emit(state.copyWith(models: models, clearError: true));
      _ensureCurrentModel(emit);
    } catch (e, stack) {
      log('加载模型列表失败: $e', name: 'ChatDetailBloc', error: e, stackTrace: stack);
      emit(state.copyWith(error: '模型列表加载失败: $e'));
    }
  }

  Future<void> _loadSuggestions(Emitter<ChatDetailState> emit) async {
    try {
      final suggestions = await _chatRepository.getPromptSuggestions();
      emit(state.copyWith(suggestions: suggestions));
    } catch (e) {
      // ignore
    }
  }

  void _ensureCurrentModel(Emitter<ChatDetailState> emit) {
    if (state.models.isEmpty) return;
    final exists = state.models.any((m) => m['id']?.toString() == state.currentModel);
    if (exists) return;
    final defaultModel = state.models.firstWhere(
      (m) => m['isDefault'] == true,
      orElse: () => state.models.first,
    );
    emit(state.copyWith(currentModel: defaultModel['id']?.toString()));
  }

  Future<void> _onMessagesLoaded(
    ChatDetailMessagesLoaded event,
    Emitter<ChatDetailState> emit,
  ) async {
    emit(state.copyWith(isLoadingHistory: true));
    try {
      final messages = await _chatRepository.getMessages(event.conversationId);
      emit(state.copyWith(messages: messages, isLoadingHistory: false));
    } catch (e) {
      emit(state.copyWith(isLoadingHistory: false));
    }
  }

  Future<void> _onMessageSent(
    ChatDetailMessageSent event,
    Emitter<ChatDetailState> emit,
  ) async {
    if (state.isSending) return;

    final content = _buildContent(event.text, state.pendingImages);
    if (content == null) return;

    emit(state.copyWith(isSending: true));

    try {
      String? conversationId = state.conversationId;
      if (conversationId == null) {
        final textPreview = _extractTextPreview(content);
        final conversation = await _chatRepository.createConversation(
          title: textPreview,
          model: state.currentModel,
          agentId: state.agentId,
        );
        conversationId = conversation.id;
        emit(state.copyWith(conversationId: conversationId));
      }

      final userMessage = Message(
        role: 'user',
        content: content is String ? content : content,
        contentType: content is String ? 'text' : 'mixed',
      );
      final assistantMessage = Message(
        role: 'assistant',
        content: '',
        contentType: 'text',
        model: state.currentModel,
      );

      emit(state.copyWith(
        messages: [...state.messages, userMessage, assistantMessage],
        pendingImages: [],
      ));

      await _streamSubscription?.cancel();

      _streamSubscription = _chatRepository.streamChat(
        conversationId: conversationId!,
        content: content,
        model: state.currentModel,
      ).listen(
        (chunk) => add(ChatDetailStreamChunk(chunk)),
        onDone: () => add(const ChatDetailStreamCompleted()),
        onError: (e, stack) {
          log('流式请求失败: $e', name: 'ChatDetailBloc', error: e, stackTrace: stack);
          add(const ChatDetailStreamCompleted());
        },
      );
    } catch (e, stack) {
      log('发送消息失败: $e', name: 'ChatDetailBloc', error: e, stackTrace: stack);
      emit(state.copyWith(isSending: false));
    }
  }

  void _onStreamChunk(
    ChatDetailStreamChunk event,
    Emitter<ChatDetailState> emit,
  ) {
    final chunk = event.chunk;
    log('收到流式 chunk: $chunk', name: 'ChatDetailBloc');
    if (chunk['done'] == true) {
      add(const ChatDetailStreamCompleted());
      return;
    }

    final text = chunk['text']?.toString() ?? '';
    if (text.isEmpty) return;

    _typingBuffer.write(text);
    _startTypingTimer();
  }

  void _onStreamCompleted(
    ChatDetailStreamCompleted event,
    Emitter<ChatDetailState> emit,
  ) {
    _stopTypingTimer();
    _flushTypingBuffer(emit);
    emit(state.copyWith(isSending: false));
  }

  void _startTypingTimer() {
    if (_typingTimer?.isActive ?? false) return;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      add(const ChatDetailTypingTick());
    });
  }

  void _stopTypingTimer() {
    _typingTimer?.cancel();
    _typingTimer = null;
  }

  void _flushTypingBuffer(Emitter<ChatDetailState> emit) {
    final remaining = _typingBuffer.toString();
    if (remaining.isEmpty) return;
    _typingBuffer.clear();
    _appendToLastAssistant(emit, remaining);
  }

  void _appendToLastAssistant(Emitter<ChatDetailState> emit, String text) {
    final messages = List<Message>.from(state.messages);
    if (messages.isNotEmpty && messages.last.role == 'assistant') {
      final last = messages.last;
      messages[messages.length - 1] = last.copyWith(
        content: (last.content?.toString() ?? '') + text,
      );
      emit(state.copyWith(messages: messages));
    }
  }

  Future<void> _onTypingTick(
    ChatDetailTypingTick event,
    Emitter<ChatDetailState> emit,
  ) async {
    final bufferStr = _typingBuffer.toString();
    if (bufferStr.isEmpty) {
      if (!state.isSending) {
        _stopTypingTimer();
      }
      return;
    }

    // 每次取 1 个字符，最多连续取 5 个以平衡速度与流畅度
    var takeCount = 1;
    if (bufferStr.length > 20) takeCount = 3;
    if (bufferStr.length > 100) takeCount = 5;

    final chars = bufferStr.substring(0, takeCount.clamp(1, bufferStr.length));
    _typingBuffer.clear();
    if (bufferStr.length > chars.length) {
      _typingBuffer.write(bufferStr.substring(chars.length));
    }

    _appendToLastAssistant(emit, chars);
  }

  void _onModelSelected(
    ChatDetailModelSelected event,
    Emitter<ChatDetailState> emit,
  ) {
    emit(state.copyWith(currentModel: event.modelId));
  }

  void _onCleared(
    ChatDetailCleared event,
    Emitter<ChatDetailState> emit,
  ) {
    _streamSubscription?.cancel();
    emit(state.copyWith(
      messages: [],
      conversationId: null,
      agentId: null,
      isSending: false,
    ));
  }

  void _onImageAdded(
    ChatDetailImageAdded event,
    Emitter<ChatDetailState> emit,
  ) {
    emit(state.copyWith(
      pendingImages: [...state.pendingImages, event.url],
    ));
  }

  void _onImageRemoved(
    ChatDetailImageRemoved event,
    Emitter<ChatDetailState> emit,
  ) {
    final list = List<String>.from(state.pendingImages);
    list.removeAt(event.index);
    emit(state.copyWith(pendingImages: list));
  }

  Future<void> _onModelsReloadRequested(
    ChatDetailModelsReloadRequested event,
    Emitter<ChatDetailState> emit,
  ) async {
    await _loadModels(emit);
  }

  Future<void> _onImageUploaded(
    ChatDetailImageUploaded event,
    Emitter<ChatDetailState> emit,
  ) async {
    try {
      final url = await _chatRepository.uploadImageBytes(
        event.bytes,
        filename: event.filename,
      );
      add(ChatDetailImageAdded(url));
    } catch (e) {
      // ignore
    }
  }

  dynamic _buildContent(String text, List<String> images) {
    final trimmed = text.trim();
    if (images.isEmpty) {
      if (trimmed.isEmpty) return null;
      return trimmed;
    }

    final parts = <Map<String, dynamic>>[];
    if (trimmed.isNotEmpty) {
      parts.add({'type': 'text', 'text': trimmed});
    }
    for (final img in images) {
      parts.add({
        'type': 'image_url',
        'image_url': {'url': img},
      });
    }
    return parts;
  }

  String _extractTextPreview(dynamic content) {
    if (content is String) return content;
    if (content is List) {
      final textParts = content
          .whereType<Map<String, dynamic>>()
          .where((p) => p['type'] == 'text')
          .map((p) => p['text']?.toString() ?? '')
          .join('');
      return textParts;
    }
    return '';
  }

  @override
  Future<void> close() {
    _streamSubscription?.cancel();
    _stopTypingTimer();
    _typingBuffer.clear();
    return super.close();
  }
}
