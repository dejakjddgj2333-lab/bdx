import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const String _tokenKey = 'token';

  Future<void> setToken(String token) async {
    // iOS 上 flutter_secure_storage 对已存在的 key 直接 write 会报
    // -25299 (errSecDuplicateItem)，先删除再写入以避免重复项冲突。
    await _storage.delete(key: _tokenKey);
    await _storage.write(key: _tokenKey, value: token);
    debugPrint('[SecureStorage] token 已保存，长度=${token.length}，前16位=${token.substring(0, token.length > 16 ? 16 : token.length)}');
  }

  Future<String?> getToken() async {
    final token = await _storage.read(key: _tokenKey);
    if (token != null) {
      debugPrint('[SecureStorage] 读到 token，长度=${token.length}，前16位=${token.substring(0, token.length > 16 ? 16 : token.length)}');
    } else {
      debugPrint('[SecureStorage] 未读到 token');
    }
    return token;
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
