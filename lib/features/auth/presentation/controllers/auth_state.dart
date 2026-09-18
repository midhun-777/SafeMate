import '../../domain/models/account_state.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/user_session.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// Immutable state representation for SafeMate authentication.
class AuthState {
  final AuthStatus status;
  final UserSession? session;
  final UserProfile? profile;
  final AccountState accountState;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.session,
    this.profile,
    this.accountState = AccountState.newUser,
    this.errorMessage,
  });

  const AuthState.initial()
      : status = AuthStatus.initial,
        session = null,
        profile = null,
        accountState = AccountState.newUser,
        errorMessage = null;

  const AuthState.loading({UserSession? currentSession, UserProfile? currentProfile})
      : status = AuthStatus.loading,
        session = currentSession,
        profile = currentProfile,
        accountState = AccountState.newUser,
        errorMessage = null;

  const AuthState.unauthenticated({String? error})
      : status = error != null ? AuthStatus.error : AuthStatus.unauthenticated,
        session = null,
        profile = null,
        accountState = AccountState.newUser,
        errorMessage = error;

  const AuthState.authenticated({
    required this.session,
    this.profile,
    this.accountState = AccountState.profileComplete,
  })  : status = AuthStatus.authenticated,
        errorMessage = null;

  const AuthState.error(
    String message, {
    this.session,
    this.profile,
  })  : status = AuthStatus.error,
        accountState = AccountState.newUser,
        errorMessage = message;

  bool get isAuthenticated => status == AuthStatus.authenticated && session != null;
  bool get isLoading => status == AuthStatus.loading;
  bool get isSuspended =>
      session?.isSuspended == true ||
      session?.role == 'suspended' ||
      accountState == AccountState.suspended;
  bool get hasError => errorMessage != null;

  AuthState copyWith({
    AuthStatus? status,
    UserSession? session,
    UserProfile? profile,
    AccountState? accountState,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      profile: profile ?? this.profile,
      accountState: accountState ?? this.accountState,
      errorMessage: errorMessage,
    );
  }
}
