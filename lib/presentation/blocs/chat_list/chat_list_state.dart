part of 'chat_list_bloc.dart';

abstract class ChatListState extends Equatable {
  const ChatListState();

  @override
  List<Object?> get props => [];
}

class ChatListInitial extends ChatListState {
  const ChatListInitial();
}

class ChatListLoading extends ChatListState {
  const ChatListLoading();
}

class ChatListLoadedSuccess extends ChatListState {
  final List<Conversation> conversations;
  final List<Conversation> filtered;
  final String searchQuery;

  const ChatListLoadedSuccess(
    this.conversations, {
    this.filtered = const [],
    this.searchQuery = '',
  });

  ChatListLoadedSuccess copyWith({
    List<Conversation>? conversations,
    List<Conversation>? filtered,
    String? searchQuery,
  }) {
    return ChatListLoadedSuccess(
      conversations ?? this.conversations,
      filtered: filtered ?? this.filtered,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [conversations, filtered, searchQuery];
}

class ChatListError extends ChatListState {
  final String message;

  const ChatListError(this.message);

  @override
  List<Object?> get props => [message];
}
