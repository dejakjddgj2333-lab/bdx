import 'package:dio/dio.dart';
import '../../core/errors/exceptions.dart';
import '../../data/datasources/local/hive_storage.dart';
import '../../data/datasources/local/secure_storage.dart';
import '../../data/datasources/remote/auth_api.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthApi _authApi;
  final SecureStorage _secureStorage;
  final HiveStorage _hiveStorage;

  AuthRepositoryImpl(
    this._authApi,
    this._secureStorage,
    this._hiveStorage,
  );

  Map<String, dynamic> _unwrap(Response? response) {
    if (response?.data == null) throw const ServerException('响应为空');
    final data = response!.data as Map<String, dynamic>;
    if (data['code'] != 0) {
      throw ServerException(data['message']?.toString() ?? '请求失败');
    }
    return data;
  }

  @override
  Future<Map<String, dynamic>> register(
    String username,
    String password, {
    String? nickname,
  }) async {
    final body = {
      'username': username,
      'password': password,
      if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
    };
    final res = await _authApi.register(body);
    return _unwrap(res);
  }

  @override
  Future<Map<String, dynamic>> login(String username, String password) async {
    final body = {'username': username, 'password': password};
    final res = await _authApi.login(body);
    return _unwrap(res);
  }

  @override
  Future<User?> getProfile() async {
    final res = await _authApi.getProfile();
    final data = _unwrap(res);
    final userData = data['data'] as Map<String, dynamic>?;
    if (userData == null) return null;
    await _hiveStorage.setJson('userInfo', userData);
    return _mapUser(userData);
  }

  @override
  Future<void> logout() async {
    await _secureStorage.deleteToken();
    await _hiveStorage.delete('userInfo');
  }

  @override
  Future<String?> getToken() async {
    return _secureStorage.getToken();
  }

  @override
  Future<void> saveToken(String token) async {
    await _secureStorage.setToken(token);
  }

  User _mapUser(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString(),
      username: json['username']?.toString(),
      nickname: json['nickname']?.toString(),
      avatar: json['avatar']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}
