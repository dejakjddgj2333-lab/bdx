import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';

class MeetingApi {
  final Dio _dio;

  MeetingApi(this._dio);

  /// 创建会议，返回 { id, room_name, title, ... }
  Future<Response> createMeeting({String? title}) async {
    return _dio.post(ApiConstants.meetings, data: {
      if (title != null && title.isNotEmpty) 'title': title,
    });
  }

  /// 入会，返回 { token, url, room_name, identity, name, is_host }
  Future<Response> joinMeeting(String roomName) async {
    return _dio.post('${ApiConstants.meetings}/$roomName/token');
  }

  /// 会议详情 + 参会者
  Future<Response> getMeeting(String roomName) async {
    return _dio.get('${ApiConstants.meetings}/$roomName');
  }

  /// 结束会议（仅主持人）
  Future<Response> endMeeting(String roomName) async {
    return _dio.post('${ApiConstants.meetings}/$roomName/end');
  }
}
