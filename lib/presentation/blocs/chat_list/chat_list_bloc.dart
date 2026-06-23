import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/conversation.dart';
import '../../../domain/repositories/chat_repository.dart';

part 'chat_list_event.dart';
part 'chat_list_state.dart';

class ChatListBloc extends Bloc<ChatListEvent, ChatListState> {
  final ChatRepository _chatRepository;

  ChatListBloc(this._chatRepository) : super(const ChatListInitial()) {
    on<ChatListLoaded>(_onLoaded);
    on<ChatListRefreshed>(_onRefreshed);
    on<ChatListSearchChanged>(_onSearchChanged);
    on<ChatListConversationDeleted>(_onDeleted);
    on<ChatListConversationRenamed>(_onRenamed);
  }

  Future<void> _onLoaded(
    ChatListLoaded event,
    Emitter<ChatListState> emit,
  ) async {
    emit(const ChatListLoading());
    try {
      final conversations = await _chatRepository.getConversations();
      emit(ChatListLoadedSuccess(
        conversations,
        filtered: conversations,
        searchQuery: '',
      ));
    } catch (e) {
      emit(ChatListError(e.toString()));
    }
  }

  Future<void> _onRefreshed(
    ChatListRefreshed event,
    Emitter<ChatListState> emit,
  ) async {
    final current = state;
    String query = '';
    if (current is ChatListLoadedSuccess) {
      query = current.searchQuery;
    }
    try {
      final conversations = await _chatRepository.getConversations();
      final filtered = _filter(conversations, query);
      emit(ChatListLoadedSuccess(conversations, filtered: filtered, searchQuery: query));
    } catch (e) {
      emit(ChatListError(e.toString()));
    }
  }

  void _onSearchChanged(
    ChatListSearchChanged event,
    Emitter<ChatListState> emit,
  ) {
    final current = state;
    if (current is ChatListLoadedSuccess) {
      final filtered = _filter(current.conversations, event.query);
      emit(current.copyWith(filtered: filtered, searchQuery: event.query));
    }
  }

  Future<void> _onDeleted(
    ChatListConversationDeleted event,
    Emitter<ChatListState> emit,
  ) async {
    try {
      await _chatRepository.deleteConversation(event.id);
      add(const ChatListRefreshed());
    } catch (e) {
      emit(ChatListError(e.toString()));
    }
  }

  Future<void> _onRenamed(
    ChatListConversationRenamed event,
    Emitter<ChatListState> emit,
  ) async {
    try {
      await _chatRepository.updateConversation(event.id, title: event.title);
      add(const ChatListRefreshed());
    } catch (e) {
      emit(ChatListError(e.toString()));
    }
  }

  List<Conversation> _filter(List<Conversation> list, String query) {
    if (query.isEmpty) return list;
    return list
        .where((c) => c.title?.toLowerCase().contains(query.toLowerCase()) ?? false)
        .toList();
  }
}
