import '../models/user_profile.dart';
import '../models/user_session.dart';

/// Abstract Authentication Repository contract for SafeMate.
/// Decouples presentation and domain logic from Supabase infrastructure.
abstract class AuthRepository {
  /// Stream emitting changes in authentication state (login, logout, token refresh).
  Stream<UserSession?> get authStateChanges;

  /// Returns current active session if restored or null if unauthenticated.
  UserSession? get currentSession;

  /// Registers a new account with email, password, and initial display name.
  Future<UserSession> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  /// Signs in existing user with email and password.
  Future<UserSession> signInWithEmail({
    required String email,
    required String password,
  });

  /// Sends a one-time password (OTP) SMS code to the specified phone number.
  Future<void> signInWithOtp({
    required String phone,
  });

  /// Verifies a 6-digit phone OTP token and establishes a session.
  Future<UserSession> verifyPhoneOtp({
    required String phone,
    required String token,
  });

  /// Dispatches password reset instructions to the given email address.
  Future<void> sendPasswordResetEmail({
    required String email,
  });

  /// Terminates current session and purges local secure storage.
  Future<void> signOut();

  /// Fetches application profile details for the given user ID.
  Future<UserProfile?> getUserProfile(String userId);

  /// Updates application profile information.
  Future<UserProfile> updateUserProfile(UserProfile profile);
}
