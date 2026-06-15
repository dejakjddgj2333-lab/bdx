import '../entities/agent.dart';

abstract class AgentRepository {
  Future<({List<Agent> agents, List<String> categories, int total})> getAgents({
    String? category,
    String? search,
    int page = 1,
    int pageSize = 20,
  });
  Future<Agent> getAgentDetail(String id);
}
