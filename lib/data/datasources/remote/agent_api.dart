import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';

class AgentApi {
  final Dio _dio;

  AgentApi(this._dio);

  Future<Response> getAgents(Map<String, dynamic> queries) async {
    return _dio.get(ApiConstants.agents, queryParameters: queries);
  }

  Future<Response> getAgentDetail(String id) async {
    return _dio.get('${ApiConstants.agents}/$id');
  }
}
