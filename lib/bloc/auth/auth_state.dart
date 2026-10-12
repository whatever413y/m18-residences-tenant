import 'package:equatable/equatable.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final String token;
  final Tenant tenant;

  Authenticated({required this.token, required this.tenant});

  @override
  List<Object?> get props => [token, tenant];
}

class Unauthenticated extends AuthState {
  final String message;

  /// The login expired while the app was in use (a 401): the app goes back to the login page and shows [message].
  final bool sessionExpired;

  Unauthenticated(this.message, {this.sessionExpired = false});

  @override
  List<Object?> get props => [message, sessionExpired];
}

class AuthError extends AuthState {
  final String message;

  AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
