import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/user_session.dart';
import '../../domain/repositories/auth_repository.dart';

/// Production implementation of AuthRepository backed by Supabase Auth and PostgreSQL.
/// Universal Engineering Rule #7: Only anon key used; RLS and server authority enforced.
class SupabaseAuthRepository implements AuthRepository {
  final sb.SupabaseClient? _client;
  final SecureStorageService _secureStorage;
  final StreamController<UserSession?> _devAuthStateController =
      StreamController<UserSession?>.broadcast();

  UserSession? _devMockSession;
  final Map<String, UserProfile> _devMockProfiles = {};

  SupabaseAuthRepository({
    sb.SupabaseClient? client,
    SecureStorageService? secureStorage,
  })  : _client = client, // ignore: prefer_initializing_formals
        _secureStorage = secureStorage ?? SecureStorageService();

  sb.SupabaseClient? get _activeClient =>
      _client ?? (AppConfig.hasValidSupabaseConfig ? sb.Supabase.instance.client : null);

  @override
  Stream<UserSession?> get authStateChanges {
    final client = _activeClient;
    if (client == null) {
      return _devAuthStateController.stream;
    }
    return client.auth.onAuthStateChange.map((data) {
      final user = data.session?.user;
      if (user == null) return null;
      return _mapSupabaseUserToSession(user);
    });
  }

  @override
  UserSession? get currentSession {
    final client = _activeClient;
    if (client == null) {
      return _devMockSession;
    }
    final user = client.auth.currentUser;
    if (user == null) return null;
    return _mapSupabaseUserToSession(user);
  }

  @override
  Future<UserSession> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final client = _activeClient;
    if (client == null) {
      // Mock mode for local development without live backend
      final mockSession = UserSession(
        userId: 'dev-user-${DateTime.now().millisecondsSinceEpoch}',
        email: email.trim(),
        role: 'user',
        createdAt: DateTime.now(),
      );
      _devMockSession = mockSession;
      _devMockProfiles[mockSession.userId] = UserProfile(
        id: mockSession.userId,
        displayName: displayName.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _devAuthStateController.add(mockSession);
      return mockSession;
    }

    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'display_name': displayName.trim(),
        },
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException('Registration could not be completed. Please try again.');
      }

      final session = _mapSupabaseUserToSession(user);
      if (response.session != null) {
        await _persistTokens(response.session!);
      }
      return session;
    } on sb.AuthException catch (e) {
      throw AuthException(_mapSupabaseErrorMessage(e.message), code: e.statusCode);
    } on SocketException {
      throw const NetworkException('Network unavailable. Please verify your connection.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthException('An unexpected error occurred during registration.');
    }
  }

  @override
  Future<UserSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final client = _activeClient;
    if (client == null) {
      // Mock mode for development
      if (password == 'InvalidPassword1') {
        throw const AuthException('Incorrect email or password. Please try again.');
      }
      final mockSession = UserSession(
        userId: 'dev-user-signed-in',
        email: email.trim(),
        role: 'user',
        createdAt: DateTime.now(),
      );
      _devMockSession = mockSession;
      _devMockProfiles[mockSession.userId] ??= UserProfile(
        id: mockSession.userId,
        displayName: email.split('@').first,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _devAuthStateController.add(mockSession);
      return mockSession;
    }

    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException('Invalid credentials. Please verify your email and password.');
      }

      final session = _mapSupabaseUserToSession(user);
      if (response.session != null) {
        await _persistTokens(response.session!);
      }
      return session;
    } on sb.AuthException catch (e) {
      throw AuthException(_mapSupabaseErrorMessage(e.message), code: e.statusCode);
    } on SocketException {
      throw const NetworkException('Network connection failed. Please check your internet connection.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthException('Could not sign in. Please try again later.');
    }
  }

  @override
  Future<void> signInWithOtp({required String phone}) async {
    final client = _activeClient;
    if (client == null) {
      debugPrint('[Mock Auth] Sent OTP to $phone: mock token is 123456');
      return;
    }

    try {
      await client.auth.signInWithOtp(
        phone: phone.trim(),
      );
    } on sb.AuthException catch (e) {
      throw AuthException(_mapSupabaseErrorMessage(e.message), code: e.statusCode);
    } on SocketException {
      throw const NetworkException('Network connection failed. Please check your internet connection.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthException('Failed to send verification code. Please try again.');
    }
  }

  @override
  Future<UserSession> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    final client = _activeClient;
    if (client == null) {
      if (token.trim() != '123456') {
        throw const AuthException('Invalid or expired verification code.');
      }
      final mockSession = UserSession(
        userId: 'dev-user-phone',
        email: '',
        phone: phone.trim(),
        role: 'user',
        createdAt: DateTime.now(),
      );
      _devMockSession = mockSession;
      _devMockProfiles[mockSession.userId] ??= UserProfile(
        id: mockSession.userId,
        displayName: 'Traveler',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _devAuthStateController.add(mockSession);
      return mockSession;
    }

    try {
      final response = await client.auth.verifyOTP(
        phone: phone.trim(),
        token: token.trim(),
        type: sb.OtpType.sms,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException('OTP verification failed.');
      }

      final session = _mapSupabaseUserToSession(user);
      if (response.session != null) {
        await _persistTokens(response.session!);
      }
      return session;
    } on sb.AuthException catch (e) {
      throw AuthException(_mapSupabaseErrorMessage(e.message), code: e.statusCode);
    } on SocketException {
      throw const NetworkException('Network connection failed. Please check your internet connection.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthException('Failed to verify OTP code.');
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    final client = _activeClient;
    if (client == null) {
      debugPrint('[Mock Auth] Password reset requested for $email');
      return;
    }

    try {
      await client.auth.resetPasswordForEmail(email.trim());
    } on sb.AuthException catch (e) {
      throw AuthException(_mapSupabaseErrorMessage(e.message), code: e.statusCode);
    } on SocketException {
      throw const NetworkException('Network connection failed. Please check your internet connection.');
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthException('Failed to send password reset email.');
    }
  }

  @override
  Future<void> signOut() async {
    final client = _activeClient;
    if (client == null) {
      _devMockSession = null;
      _devAuthStateController.add(null);
      await _secureStorage.clearSession();
      return;
    }

    try {
      await client.auth.signOut();
      await _secureStorage.clearSession();
    } catch (e) {
      debugPrint('[SafeMate Auth] Warning on signOut: $e');
      await _secureStorage.clearSession();
    }
  }

  @override
  Future<UserProfile?> getUserProfile(String userId) async {
    final client = _activeClient;
    if (client == null) {
      return _devMockProfiles[userId] ??
          UserProfile(
            id: userId,
            displayName: 'Dev Traveler',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
    }

    try {
      final data = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;
      return UserProfile.fromJson(data);
    } catch (e) {
      debugPrint('[SafeMate Profile] Error fetching profile: $e');
      return null;
    }
  }

  @override
  Future<UserProfile> updateUserProfile(UserProfile profile) async {
    final client = _activeClient;
    if (client == null) {
      _devMockProfiles[profile.id] = profile;
      return profile;
    }

    try {
      final data = await client
          .from('profiles')
          .update(profile.toJson())
          .eq('id', profile.id)
          .select()
          .single();

      return UserProfile.fromJson(data);
    } on sb.PostgrestException catch (e) {
      throw AuthException(e.message, code: e.code);
    } catch (e) {
      throw const AuthException('Failed to update traveler profile.');
    }
  }

  UserSession _mapSupabaseUserToSession(sb.User user) {
    return UserSession(
      userId: user.id,
      email: user.email ?? '',
      phone: user.phone,
      role: (user.appMetadata['role'] as String?) ?? 'user',
      createdAt: DateTime.parse(user.createdAt),
    );
  }

  Future<void> _persistTokens(sb.Session session) async {
    await _secureStorage.saveSessionTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken ?? '',
      userId: session.user.id,
    );
  }

  String _mapSupabaseErrorMessage(String rawMessage) {
    final lower = rawMessage.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (lower.contains('user already registered')) {
      return 'An account with this email already exists.';
    }
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return 'Too many attempts. Please wait a few moments before trying again.';
    }
    if (lower.contains('otp expired') || lower.contains('token has expired')) {
      return 'Verification code has expired. Please request a new code.';
    }
    if (lower.contains('invalid token') || lower.contains('invalid otp')) {
      return 'Invalid verification code. Please check and try again.';
    }
    if (lower.contains('password should be at least')) {
      return 'Password must be at least 8 characters long.';
    }
    return rawMessage;
  }
}
