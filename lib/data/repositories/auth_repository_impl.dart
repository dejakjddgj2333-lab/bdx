import 'dart:typed_data';

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
  Future<Map<String, dynamic>> oneClickLogin(String token) async {
    final res = await _authApi.oneClickLogin({'token': token});
    return _unwrap(res);
  }

  @override
  Future<void> sendEmailCode(String email) async {
    final res = await _authApi.sendEmailCode({'email': email});
    _unwrap(res);
  }

  @override
  Future<Map<String, dynamic>> emailLogin(String email, String code) async {
    final res = await _authApi.emailLogin({'email': email, 'code': code});
    return _unwrap(res);
  }

  @override
  Future<Map<String, dynamic>> appleLogin({
    required String identityToken,
    required String userIdentifier,
    String? email,
    String? nickname,
  }) async {
    final body = {
      'identityToken': identityToken,
      'userIdentifier': userIdentifier,
      if (email != null && email.isNotEmpty) 'email': email,
      if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
    };
    final res = await _authApi.appleLogin(body);
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
  Future<User?> updateProfile({String? nickname, String? avatar}) async {
    final body = <String, dynamic>{
      if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
      if (avatar != null && avatar.isNotEmpty) 'avatar': avatar,
    };
    final res = await _authApi.updateProfile(body);
    final data = _unwrap(res);
    final userData = data['data'] as Map<String, dynamic>?;
    if (userData == null) return null;
    await _hiveStorage.setJson('userInfo', userData);
    return _mapUser(userData);
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes, {String? filename}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename ?? 'avatar.jpg',
      ),
    });
    final res = await _authApi.uploadAvatar(formData);
    final data = _unwrap(res);
    return (data['data']?['avatar'] ?? '').toString();
  }

  @override
  Future<void> logout() async {
    // 退出登录时先清空可能残留的 key，再调用 deleteToken。
    // iOS Keychain 在 accessibility 不一致时 delete 可能匹配不到旧 item，
    // deleteAll 能更彻底地清理本 App 在钥匙串中的全部数据。
    await _secureStorage.clearAll();
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
