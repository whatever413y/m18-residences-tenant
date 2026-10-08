import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class CheckAuthStatus extends AuthEvent {}

class LoginWithAccountId extends AuthEvent {
  final String accountId;

  /// The login page's Turnstile token (single use).
  final String? turnstileToken;

  LoginWithAccountId(this.accountId, {this.turnstileToken});

  @override
  List<Object> get props => [accountId, ?turnstileToken];
}

class LogoutRequested extends AuthEvent {}
