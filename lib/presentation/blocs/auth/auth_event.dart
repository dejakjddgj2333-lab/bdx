part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthOneClickRequested extends AuthEvent {
  final String token;

  const AuthOneClickRequested(this.token);

  @override
  List<Object?> get props => [token];
}

class AuthAppleLoginRequested extends AuthEvent {
  final String identityToken;
  final String userIdentifier;
  final String? email;
  final String? nickname;

  const AuthAppleLoginRequested({
    required this.identityToken,
    required this.userIdentifier,
    this.email,
    this.nickname,
  });

  @override
  List<Object?> get props => [identityToken, userIdentifier, email, nickname];
}

class AuthSendEmailCodeRequested extends AuthEvent {
  final String email;

  const AuthSendEmailCodeRequested(this.email);

  @override
  List<Object?> get props => [email];
}

class AuthEmailLoginRequested extends AuthEvent {
  final String email;
  final String code;

  const AuthEmailLoginRequested(this.email, this.code);

  @override
  List<Object?> get props => [email, code];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthProfileLoaded extends AuthEvent {
  const AuthProfileLoaded();
}
