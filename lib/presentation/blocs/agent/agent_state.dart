part of 'agent_bloc.dart';

abstract class AgentState extends Equatable {
  final String selectedCategory;
  final String searchQuery;

  const AgentState({
    this.selectedCategory = '',
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [selectedCategory, searchQuery];
}

class AgentInitial extends AgentState {
  const AgentInitial() : super();
}

class AgentLoading extends AgentState {
  const AgentLoading() : super();
}

class AgentLoadedSuccess extends AgentState {
  final List<Agent> agents;
  final List<String> categories;
  final bool hasReachedMax;

  const AgentLoadedSuccess({
    required this.agents,
    this.categories = const ['全部'],
    super.selectedCategory = '',
    super.searchQuery = '',
    this.hasReachedMax = false,
  });

  AgentLoadedSuccess copyWith({
    List<Agent>? agents,
    List<String>? categories,
    String? selectedCategory,
    String? searchQuery,
    bool? hasReachedMax,
  }) {
    return AgentLoadedSuccess(
      agents: agents ?? this.agents,
      categories: categories ?? this.categories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }

  @override
  List<Object?> get props => [agents, categories, selectedCategory, searchQuery, hasReachedMax];
}

class AgentError extends AgentState {
  final String message;

  const AgentError(this.message);

  @override
  List<Object?> get props => [message];
}
