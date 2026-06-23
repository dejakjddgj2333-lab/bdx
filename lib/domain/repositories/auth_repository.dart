import 'dart:typed_data';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<Map<String, dynamic>> register(String username, String password, {String? nickname});
  Future<Map<String, dynamic>> login(String username, String password);
  Future<User?> getProfile();
  Future<User?> updateProfile({String? nickname, String? avatar});
  Future<String> uploadAvatar(Uint8List bytes, {String? filename});
  Future<void> logout();
  Future<String?> getToken();
  Future<void> saveToken(String token);
}
