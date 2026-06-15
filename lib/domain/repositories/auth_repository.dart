import '../entities/user.dart';

abstract class AuthRepository {
  Future<Map<String, dynamic>> register(String username, String password, {String? nickname});
  Future<Map<String, dynamic>> login(String username, String password);
  Future<User?> getProfile();
  Future<void> logout();
  Future<String?> getToken();
  Future<void> saveToken(String token);
}
