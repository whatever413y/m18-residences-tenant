import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  /// Also used by pages for the signed receipt and payment image URLs.
  final AuthApi authApi;
  final TenantApi tenantApi;

  Tenant? _cachedTenant;

  AuthBloc({required this.authApi, required this.tenantApi}) : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginWithAccountId>(_onLoginWithAccountId);
    on<LogoutRequested>(_onLogout);
    on<SessionExpired>(_onSessionExpired);
    authApi.client.onSessionExpired = () => add(SessionExpired());
  }

  Future<void> _onCheckAuthStatus(CheckAuthStatus event, Emitter<AuthState> emit) async {
    final isAuth = await _isSessionValid();
    if (!isAuth) {
      return emit(Unauthenticated('Session has expired. Please try again'));
    }

    final token = await authApi.tokens.token();
    final tenantIdStr = await authApi.tokens.subject();
    if (token == null || tenantIdStr == null) {
      return emit(Unauthenticated('Token or user missing'));
    }

    final tenantId = int.tryParse(tenantIdStr);
    if (tenantId == null) {
      return emit(Unauthenticated('Invalid tenant ID'));
    }

    final tenant = await _fetchTenant(tenantId);
    if (tenant == null) {
      return emit(Unauthenticated('Tenant not found'));
    }

    _cachedTenant = tenant;
    emit(Authenticated(token: token, tenant: tenant));
  }

  /// A session the server cannot confirm (rejected token, server or network error) counts as expired.
  Future<bool> _isSessionValid() async {
    try {
      return await authApi.validateToken();
    } catch (e) {
      debugPrint('Error validating token: $e');
      return false;
    }
  }

  /// `null` (shown as "Tenant not found") when the tenant cannot be loaded for any reason.
  Future<Tenant?> _fetchTenant(int id) async {
    try {
      return await tenantApi.getById(id);
    } catch (e) {
      debugPrint('Error fetching tenant by ID: $e');
      return null;
    }
  }

  Future<void> _onLoginWithAccountId(LoginWithAccountId event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    try {
      final session = await authApi.tenantLogin(event.accountId, turnstileToken: event.turnstileToken);
      _cachedTenant = session.tenant;
      emit(Authenticated(token: session.token, tenant: session.tenant));
    } on TenantNotFoundException {
      emit(AuthError('Account ID not found.'));
    } on TooManyAttemptsException {
      emit(AuthError('Too many attempts. Please wait a minute and try again.'));
    } on VerificationFailedException catch (e) {
      emit(AuthError(e.unavailable ? "Couldn't verify right now. Please try again." : 'Verification failed. Please try again.'));
    } catch (e) {
      emit(AuthError(readableError(e)));
    }
  }

  Future<void> _onLogout(LogoutRequested event, Emitter<AuthState> emit) async {
    await authApi.logout();
    _cachedTenant = null;
    emit(Unauthenticated('You have been logged out.'));
  }

  /// Several calls can fail at once: only the first, while logged in, ends the session.
  Future<void> _onSessionExpired(SessionExpired event, Emitter<AuthState> emit) async {
    if (state is! Authenticated) return;
    await authApi.logout();
    _cachedTenant = null;
    emit(Unauthenticated('Your session has ended. Please log in again.', sessionExpired: true));
  }

  Tenant? get cachedTenant => _cachedTenant;
}
