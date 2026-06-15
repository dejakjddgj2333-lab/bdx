part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  final User? user;
  final String? error;

  const AuthState({this.user, this.error});

  bool get isAuthenticated => user != null;

  @override
  List<Object?> get props => [user, error];
}

class AuthInitial extends AuthState {
  const AuthInitial() : super();
}

class AuthLoading extends AuthState {
  const AuthLoading() : super();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(User? user) : super(user: user);
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated() : super();
}

class AuthError extends AuthState {
  const AuthError(String error) : super(error: error);
}
