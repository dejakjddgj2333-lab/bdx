import 'package:dio/dio.dart';
import '../../core/errors/exceptions.dart';
import '../../data/datasources/remote/agent_api.dart';
import '../../domain/entities/agent.dart';
import '../../domain/repositories/agent_repository.dart';

class AgentRepositoryImpl implements AgentRepository {
  final AgentApi _agentApi;

  AgentRepositoryImpl(this._agentApi);

  Map<String, dynamic> _unwrap(Response? response) {
    if (response?.data == null) throw const ServerException('响应为空');
    final data = response!.data as Map<String, dynamic>;
    if (data['code'] != 0) {
      throw ServerException(data['message']?.toString() ?? '请求失败');
    }
    return data;
  }

  @override
  Future<({List<Agent> agents, List<String> categories, int total})> getAgents({
    String? category,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _agentApi.getAgents({
      if (category != null && category.isNotEmpty) 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'pageSize': pageSize,
    });
    final data = _unwrap(res);
    final payload = data['data'] as Map<String, dynamic>? ?? {};
    final list = payload['list'] as List<dynamic>? ?? [];
    final categories = (payload['categories'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final pagination = payload['pagination'] as Map<String, dynamic>? ?? {};
    final total = (pagination['total'] as num?)?.toInt() ?? 0;

    return (
      agents: list.map((e) => _mapAgent(e as Map<String, dynamic>)).toList(),
      categories: categories.isEmpty ? const ['全部'] : ['全部', ...categories],
      total: total,
    );
  }

  @override
  Future<Agent> getAgentDetail(String id) async {
    final res = await _agentApi.getAgentDetail(id);
    final data = _unwrap(res);
    final payload = data['data'] as Map<String, dynamic>? ?? {};
    return _mapAgent(payload);
  }

  Agent _mapAgent(Map<String, dynamic> json) {
    return Agent(
      id: json['id']?.toString(),
      name: json['name']?.toString(),
      category: json['category']?.toString(),
      description: json['description']?.toString(),
      avatar: json['avatar']?.toString(),
      usageCount: json['use_count'] as int? ?? json['usageCount'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString())
              : null),
    );
  }
}
