import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../core/constants/api_constants.dart';
import '../local/secure_storage.dart';

class ApiClient {
  late final Dio dio;
  final SecureStorage _secureStorage;

  ApiClient(this._secureStorage) {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          debugPrint('[ApiClient] ${options.method} ${options.path} 使用 token=${token != null && token.isNotEmpty ? token.substring(0, token.length > 16 ? 16 : token.length) : '无'}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          handler.next(response);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            await _secureStorage.deleteToken();
            Fluttertoast.showToast(msg: '登录已过期');
            // 路由跳转由全局监听处理
          } else if (e.response?.statusCode == 404) {
            Fluttertoast.showToast(msg: '服务暂不可用，请稍后重试');
          } else {
            final msg = e.response?.data?['message'] ?? '网络请求失败';
            Fluttertoast.showToast(msg: msg.toString());
          }
          handler.next(e);
        },
      ),
    );
  }
}
