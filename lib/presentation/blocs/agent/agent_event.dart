part of 'agent_bloc.dart';

abstract class AgentEvent extends Equatable {
  const AgentEvent();

  @override
  List<Object?> get props => [];
}

class AgentLoaded extends AgentEvent {
  const AgentLoaded();
}

class AgentCategorySelected extends AgentEvent {
  final String category;

  const AgentCategorySelected(this.category);

  @override
  List<Object?> get props => [category];
}

class AgentSearchChanged extends AgentEvent {
  final String query;

  const AgentSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class AgentLoadMore extends AgentEvent {
  const AgentLoadMore();
}
