import 'dart:typed_data';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<Map<String, dynamic>> oneClickLogin(String token);
  Future<void> sendEmailCode(String email);
  Future<Map<String, dynamic>> emailLogin(String email, String code);
  Future<Map<String, dynamic>> appleLogin({
    required String identityToken,
    required String userIdentifier,
    String? email,
    String? nickname,
  });
  Future<User?> getProfile();
  Future<User?> updateProfile({String? nickname, String? avatar});
  Future<String> uploadAvatar(Uint8List bytes, {String? filename});
  Future<void> logout();
  Future<String?> getToken();
  Future<void> saveToken(String token);
}
