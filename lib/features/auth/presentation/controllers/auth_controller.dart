import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../data/repositories/supabase_auth_repository.dart';
import '../../domain/models/account_state.dart';
import '../../domain/models/user_session.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

/// Provider for AuthRepository contract.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository();
});

/// Riverpod StateNotifierProvider for central AuthController.
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});

/// AuthController coordinates authentication actions and manages reactive AuthState.
/// Universal Engineering Rule #10: Separation of Auth and Profile.
/// Universal Engineering Rule #11: Account States managed reactively.
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  StreamSubscription<UserSession?>? _authSubscription;

  AuthController(this._repository) : super(const AuthState.initial()) {
    _init();
  }

  void _init() {
    // Listen to reactive auth stream
    _authSubscription = _repository.authStateChanges.listen((session) {
      if (session != null) {
        _handleAuthenticatedSession(session);
      } else {
        state = const AuthState.unauthenticated();
      }
    });

    // Check initial cached/restored session
    final initialSession = _repository.currentSession;
    if (initialSession != null) {
      _handleAuthenticatedSession(initialSession);
    } else {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> _handleAuthenticatedSession(UserSession session) async {
    if (session.isSuspended || session.role == 'suspended') {
      state = AuthState(
        status: AuthStatus.authenticated,
        session: session,
        accountState: AccountState.suspended,
      );
      return;
    }

    try {
      final profile = await _repository.getUserProfile(session.userId);
      final accountState = profile == null || !profile.isProfileComplete
          ? AccountState.profileIncomplete
          : AccountState.profileComplete;

      state = AuthState.authenticated(
        session: session,
        profile: profile,
        accountState: accountState,
      );
    } catch (e) {
      debugPrint('[AuthController] Error loading profile: $e');
      // Still authenticated at identity layer even if profile query fails
      state = AuthState.authenticated(
        session: session,
        accountState: AccountState.profileIncomplete,
      );
    }
  }

  /// Registers a new user with email, password, and display name.
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final session = await _repository.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      await _handleAuthenticatedSession(session);
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'An unexpected error occurred during signup. Please try again.',
      );
      return false;
    }
  }

  /// Signs in with email and password.
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final session = await _repository.signInWithEmail(
        email: email,
        password: password,
      );
      await _handleAuthenticatedSession(session);
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'An unexpected error occurred during sign in. Please try again.',
      );
      return false;
    }
  }

  /// Sends a one-time password (OTP) SMS code to the given phone number.
  Future<bool> signInWithOtp({
    required String phone,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _repository.signInWithOtp(phone: phone);
      state = state.copyWith(status: AuthStatus.unauthenticated, errorMessage: null);
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to send verification code. Please check your phone number.',
      );
      return false;
    }
  }

  /// Verifies a 6-digit phone OTP token.
  Future<bool> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final session = await _repository.verifyPhoneOtp(
        phone: phone,
        token: token,
      );
      await _handleAuthenticatedSession(session);
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to verify OTP code. Please try again.',
      );
      return false;
    }
  }

  /// Dispatches a password reset email.
  Future<bool> sendPasswordResetEmail({
    required String email,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _repository.sendPasswordResetEmail(email: email);
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: null,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to dispatch password reset email. Please try again.',
      );
      return false;
    }
  }

  /// Signs out and resets state to unauthenticated.
  Future<void> signOut() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repository.signOut();
    } finally {
      state = const AuthState.unauthenticated();
    }
  }

  /// Refreshes the currently authenticated user's profile.
  Future<void> refreshProfile() async {
    final session = state.session;
    if (session == null) return;
    try {
      final profile = await _repository.getUserProfile(session.userId);
      final accountState = profile == null || !profile.isProfileComplete
          ? AccountState.profileIncomplete
          : AccountState.profileComplete;
      state = state.copyWith(profile: profile, accountState: accountState);
    } catch (e) {
      debugPrint('[AuthController] Failed to refresh profile: $e');
    }
  }

  /// Clears any existing error banner message.
  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
