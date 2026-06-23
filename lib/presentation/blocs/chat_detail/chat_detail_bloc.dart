import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/message.dart';
import '../../../domain/repositories/chat_repository.dart';

part 'chat_detail_event.dart';
part 'chat_detail_state.dart';

// 场景配置
final Map<String, Map<String, dynamic>> _sceneConfigs = {
  'assistant': {
    'title': 'AI 助手',
    'placeholder': '输入消息，开启文字对话...',
    'systemPrompt': null,
    'templates': <Map<String, String>>[],
  },
  'translator': {
    'title': 'AI 翻译',
    'placeholder': '输入要翻译的内容...',
    'systemPrompt': '你是一位专业翻译助手。请直接输出翻译结果，不要添加解释。若用户没有指定源语言和目标语言，请根据内容自动判断并翻译成中文或英文。',
    'templates': [
      {'title': '中译英', 'text': '将以下内容翻译成英文：'},
      {'title': '英译中', 'text': '将以下内容翻译成中文：'},
      {'title': '润色', 'text': '润色并优化以下表达：'},
    ],
  },
  'code_explain': {
    'title': '代码解释',
    'placeholder': '粘贴代码，我会帮你解释...',
    'systemPrompt': '你是一位资深程序员。请解释用户提供的代码，说明其作用、关键逻辑和潜在问题。回答要简洁，代码块使用 Markdown 格式。',
    'templates': [
      {'title': '解释代码', 'text': '请解释这段代码：\n```\n\n```'},
      {'title': '查找 Bug', 'text': '请检查这段代码是否有 Bug：\n```\n\n```'},
      {'title': '优化建议', 'text': '请优化这段代码：\n```\n\n```'},
    ],
  },
  'weekly_report': {
    'title': '周报生成',
    'placeholder': '输入本周工作要点...',
    'systemPrompt': '你是一位职场写作助手。根据用户提供的工作要点，生成一份结构清晰、重点突出的周报，包含本周工作、遇到的问题、下周计划三部分。',
    'templates': [
      {'title': '开发周报', 'text': '请根据以下要点生成开发周报：'},
      {'title': '产品周报', 'text': '请根据以下要点生成产品周报：'},
      {'title': '运营周报', 'text': '请根据以下要点生成运营周报：'},
    ],
  },
  'rewrite': {
    'title': '文案改写',
    'placeholder': '输入需要改写的文案...',
    'systemPrompt': '你是一位文案润色专家。请根据用户需求改写文案，保持原意的同时让表达更流畅、专业、有吸引力。',
    'templates': [
      {'title': '更正式', 'text': '请将以下文案改写得更加正式：'},
      {'title': '更口语化', 'text': '请将以下文案改得更口语化：'},
      {'title': '更简短', 'text': '请将以下文案精简：'},
    ],
  },
};

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
      scene: event.scene,
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
    } catch (e, stack) {
      log('加载历史消息失败: $e', name: 'ChatDetailBloc', error: e, stackTrace: stack);
      emit(state.copyWith(
        isLoadingHistory: false,
        error: '历史消息加载失败，请重试',
      ));
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

      final sceneConfig = _sceneConfigs[state.scene] ?? _sceneConfigs['assistant']!;
      final systemPrompt = sceneConfig['systemPrompt'] as String?;

      _streamSubscription = _chatRepository.streamChat(
        conversationId: conversationId!,
        content: content,
        model: state.currentModel,
        systemPrompt: systemPrompt,
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
    } catch (e, stack) {
      log('图片上传失败: $e', name: 'ChatDetailBloc', error: e, stackTrace: stack);
      emit(state.copyWith(error: '图片上传失败，请重试'));
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
