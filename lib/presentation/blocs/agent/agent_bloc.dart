import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/agent.dart';
import '../../../domain/repositories/agent_repository.dart';

part 'agent_event.dart';
part 'agent_state.dart';

class AgentBloc extends Bloc<AgentEvent, AgentState> {
  final AgentRepository _agentRepository;

  AgentBloc(this._agentRepository) : super(const AgentInitial()) {
    on<AgentLoaded>(_onLoaded);
    on<AgentCategorySelected>(_onCategorySelected);
    on<AgentSearchChanged>(_onSearchChanged);
    on<AgentLoadMore>(_onLoadMore);
  }

  Future<void> _onLoaded(
    AgentLoaded event,
    Emitter<AgentState> emit,
  ) async {
    emit(const AgentLoading());
    try {
      final result = await _agentRepository.getAgents(
        category: state.selectedCategory,
        search: state.searchQuery,
      );
      emit(AgentLoadedSuccess(
        agents: result.agents,
        categories: result.categories,
        selectedCategory: state.selectedCategory,
        searchQuery: state.searchQuery,
        hasReachedMax: result.agents.length >= result.total,
      ));
    } catch (e) {
      emit(AgentError(e.toString()));
    }
  }

  Future<void> _onCategorySelected(
    AgentCategorySelected event,
    Emitter<AgentState> emit,
  ) async {
    if (state is AgentLoadedSuccess) {
      emit((state as AgentLoadedSuccess).copyWith(selectedCategory: event.category));
    }
    add(const AgentLoaded());
  }

  void _onSearchChanged(
    AgentSearchChanged event,
    Emitter<AgentState> emit,
  ) {
    if (state is AgentLoadedSuccess) {
      emit((state as AgentLoadedSuccess).copyWith(searchQuery: event.query));
    }
  }

  Future<void> _onLoadMore(
    AgentLoadMore event,
    Emitter<AgentState> emit,
  ) async {
    final current = state;
    if (current is! AgentLoadedSuccess || current.hasReachedMax) return;

    try {
      final nextPage = (current.agents.length ~/ 20) + 1;
      final result = await _agentRepository.getAgents(
        category: current.selectedCategory,
        search: current.searchQuery,
        page: nextPage,
      );
      final allAgents = [...current.agents, ...result.agents];
      emit(current.copyWith(
        agents: allAgents,
        categories: result.categories,
        hasReachedMax: allAgents.length >= result.total,
      ));
    } catch (e) {
      emit(AgentError(e.toString()));
    }
  }
}
