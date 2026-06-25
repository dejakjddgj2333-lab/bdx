import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';

class AuthApi {
  final Dio _dio;

  AuthApi(this._dio);

  Future<Response> oneClickLogin(Map<String, dynamic> body) async {
    return _dio.post(ApiConstants.oneClickLogin, data: body);
  }

  Future<Response> sendEmailCode(Map<String, dynamic> body) async {
    return _dio.post(ApiConstants.sendEmailCode, data: body);
  }

  Future<Response> emailLogin(Map<String, dynamic> body) async {
    return _dio.post(ApiConstants.emailLogin, data: body);
  }

  Future<Response> appleLogin(Map<String, dynamic> body) async {
    return _dio.post(ApiConstants.appleLogin, data: body);
  }

  Future<Response> refreshToken(Map<String, dynamic> body) async {
    return _dio.post(ApiConstants.refreshToken, data: body);
  }

  Future<Response> getProfile() async {
    return _dio.get(ApiConstants.userProfile);
  }

  Future<Response> updateProfile(Map<String, dynamic> body) async {
    return _dio.put(ApiConstants.userProfile, data: body);
  }

  Future<Response> uploadAvatar(FormData formData) async {
    return _dio.post(ApiConstants.userAvatar, data: formData);
  }

  Future<Response> getSettings() async {
    return _dio.get(ApiConstants.userSettings);
  }

  Future<Response> updateSettings(Map<String, dynamic> body) async {
    return _dio.put(ApiConstants.userSettings, data: body);
  }
}
