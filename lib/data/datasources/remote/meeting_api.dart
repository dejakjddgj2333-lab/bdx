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

  /// 修改会议主题（仅主持人）
  Future<Response> updateMeetingTitle(String roomName, String title) async {
    return _dio.put('${ApiConstants.meetings}/$roomName', data: {
      'title': title,
    });
  }

  /// 更新成员发布权限（仅主持人）：授予/收回说话、视频、屏幕共享
  Future<Response> setParticipantPermission(
      String roomName, String identity, bool canPublish) async {
    return _dio.post('${ApiConstants.meetings}/$roomName/permission', data: {
      'identity': identity,
      'can_publish': canPublish,
    });
  }

  /// 结束会议（仅主持人）
  Future<Response> endMeeting(String roomName) async {
    return _dio.post('${ApiConstants.meetings}/$roomName/end');
  }
}
