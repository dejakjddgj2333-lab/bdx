import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:beidouxing_app_flutter/domain/entities/user.dart';
import 'package:beidouxing_app_flutter/domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc(this._authRepository) : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthOneClickRequested>(_onOneClickRequested);
    on<AuthAppleLoginRequested>(_onAppleLoginRequested);
    on<AuthSendEmailCodeRequested>(_onSendEmailCodeRequested);
    on<AuthEmailLoginRequested>(_onEmailLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthProfileLoaded>(_onProfileLoaded);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final token = await _authRepository.getToken();
      if (token == null || token.isEmpty) {
        emit(const AuthUnauthenticated());
        return;
      }
      final user = await _authRepository.getProfile();
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onOneClickRequested(
    AuthOneClickRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    debugPrint('[AuthBloc] 开始一键登录后端校验，token长度=${event.token.length}');
    try {
      final res = await _authRepository.oneClickLogin(event.token);
      debugPrint('[AuthBloc] 后端返回: $res');
      await _saveTokenAndProfile(res, emit);
    } catch (e, s) {
      debugPrint('[AuthBloc] 一键登录失败: $e');
      debugPrint('[AuthBloc] 堆栈: $s');
      emit(AuthOneClickFailed(e.toString()));
    }
  }

  Future<void> _onAppleLoginRequested(
    AuthAppleLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final res = await _authRepository.appleLogin(
        identityToken: event.identityToken,
        userIdentifier: event.userIdentifier,
        email: event.email,
        nickname: event.nickname,
      );
      await _saveTokenAndProfile(res, emit);
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSendEmailCodeRequested(
    AuthSendEmailCodeRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthEmailCodeSending());
    try {
      await _authRepository.sendEmailCode(event.email);
      emit(const AuthEmailCodeSent());
    } catch (e) {
      emit(AuthEmailCodeError(e.toString()));
    }
  }

  Future<void> _onEmailLoginRequested(
    AuthEmailLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final res = await _authRepository.emailLogin(event.email, event.code);
      await _saveTokenAndProfile(res, emit);
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onProfileLoaded(
    AuthProfileLoaded event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final user = await _authRepository.getProfile();
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _saveTokenAndProfile(
    Map<String, dynamic> res,
    Emitter<AuthState> emit,
  ) async {
    final token = res['data']?['token']?.toString();
    debugPrint('[AuthBloc] 解析token=${token != null ? '有(长度${token.length})' : '无'}');
    if (token != null && token.isNotEmpty) {
      await _authRepository.saveToken(token);
      debugPrint('[AuthBloc] token已保存');
    }
    debugPrint('[AuthBloc] 开始获取用户信息...');
    final user = await _authRepository.getProfile();
    debugPrint('[AuthBloc] 获取用户信息完成: id=${user?.id}, username=${user?.username}, nickname=${user?.nickname}');
    emit(AuthAuthenticated(user));
  }
}
