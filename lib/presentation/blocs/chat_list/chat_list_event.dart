part of 'chat_list_bloc.dart';

abstract class ChatListEvent extends Equatable {
  const ChatListEvent();

  @override
  List<Object?> get props => [];
}

class ChatListLoaded extends ChatListEvent {
  const ChatListLoaded();
}

class ChatListRefreshed extends ChatListEvent {
  const ChatListRefreshed();
}

class ChatListSearchChanged extends ChatListEvent {
  final String query;

  const ChatListSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class ChatListConversationDeleted extends ChatListEvent {
  final String id;

  const ChatListConversationDeleted(this.id);

  @override
  List<Object?> get props => [id];
}

class ChatListConversationRenamed extends ChatListEvent {
  final String id;
  final String title;

  const ChatListConversationRenamed(this.id, this.title);

  @override
  List<Object?> get props => [id, title];
}
