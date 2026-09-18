import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/errors/app_exception.dart';
import 'package:safemate/features/auth/domain/models/account_state.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/auth/domain/models/user_session.dart';
import 'package:safemate/features/auth/domain/repositories/auth_repository.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_state.dart';

class FakeAuthRepository implements AuthRepository {
  final StreamController<UserSession?> _controller =
      StreamController<UserSession?>.broadcast();
  UserSession? _currentSession;
  final Map<String, UserProfile> _profiles = {};

  bool shouldThrowOnSignIn = false;
  bool shouldThrowOnSignUp = false;

  void emitSession(UserSession? session) {
    _currentSession = session;
    _controller.add(session);
  }

  @override
  Stream<UserSession?> get authStateChanges => _controller.stream;

  @override
  UserSession? get currentSession => _currentSession;

  @override
  Future<UserProfile?> getUserProfile(String userId) async {
    return _profiles[userId];
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<UserSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (shouldThrowOnSignIn) {
      throw const AuthException('Invalid login credentials.');
    }
    final session = UserSession(
      userId: 'user-sign-in-1',
      email: email,
      role: 'user',
      createdAt: DateTime.now(),
    );
    _profiles[session.userId] = UserProfile(
      id: session.userId,
      displayName: 'Sign In User',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    emitSession(session);
    return session;
  }

  @override
  Future<void> signInWithOtp({required String phone}) async {}

  @override
  Future<void> signOut() async {
    emitSession(null);
  }

  @override
  Future<UserSession> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (shouldThrowOnSignUp) {
      throw const AuthException('Email already registered.');
    }
    final session = UserSession(
      userId: 'user-sign-up-1',
      email: email,
      role: 'user',
      createdAt: DateTime.now(),
    );
    _profiles[session.userId] = UserProfile(
      id: session.userId,
      displayName: displayName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    emitSession(session);
    return session;
  }

  @override
  Future<UserProfile> updateUserProfile(UserProfile profile) async {
    _profiles[profile.id] = profile;
    return profile;
  }

  @override
  Future<UserSession> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    final session = UserSession(
      userId: 'user-otp-1',
      email: '',
      phone: phone,
      role: 'user',
      createdAt: DateTime.now(),
    );
    _profiles[session.userId] = UserProfile(
      id: session.userId,
      displayName: 'Phone User',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    emitSession(session);
    return session;
  }
}

void main() {
  group('AuthController Tests', () {
    late FakeAuthRepository fakeRepo;
    late AuthController controller;

    setUp(() {
      fakeRepo = FakeAuthRepository();
      controller = AuthController(fakeRepo);
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial state defaults to unauthenticated when repo is empty', () {
      expect(controller.state.status, equals(AuthStatus.unauthenticated));
      expect(controller.state.session, isNull);
      expect(controller.state.isAuthenticated, isFalse);
    });

    test('signUpWithEmail transitions to authenticated with profile', () async {
      final result = await controller.signUpWithEmail(
        email: 'alex@example.com',
        password: 'ValidPassword1!',
        displayName: 'Alex Traveler',
      );

      expect(result, isTrue);
      expect(controller.state.status, equals(AuthStatus.authenticated));
      expect(controller.state.session?.email, equals('alex@example.com'));
      expect(controller.state.profile?.displayName, equals('Alex Traveler'));
      expect(controller.state.accountState, equals(AccountState.profileComplete));
    });

    test('signUpWithEmail updates state to error when repo throws', () async {
      fakeRepo.shouldThrowOnSignUp = true;

      final result = await controller.signUpWithEmail(
        email: 'existing@example.com',
        password: 'ValidPassword1!',
        displayName: 'Alex Traveler',
      );

      expect(result, isFalse);
      expect(controller.state.status, equals(AuthStatus.error));
      expect(controller.state.errorMessage, contains('already registered'));
    });

    test('signInWithEmail transitions to authenticated on success', () async {
      final result = await controller.signInWithEmail(
        email: 'login@example.com',
        password: 'ValidPassword1!',
      );

      expect(result, isTrue);
      expect(controller.state.isAuthenticated, isTrue);
      expect(controller.state.session?.email, equals('login@example.com'));
    });

    test('signInWithEmail updates state to error on failure', () async {
      fakeRepo.shouldThrowOnSignIn = true;

      final result = await controller.signInWithEmail(
        email: 'wrong@example.com',
        password: 'BadPassword1!',
      );

      expect(result, isFalse);
      expect(controller.state.status, equals(AuthStatus.error));
      expect(controller.state.errorMessage, contains('Invalid login credentials'));
    });

    test('clearError clears existing errorMessage', () async {
      fakeRepo.shouldThrowOnSignIn = true;
      await controller.signInWithEmail(
        email: 'test@example.com',
        password: 'pass',
      );
      expect(controller.state.errorMessage, isNotNull);

      controller.clearError();
      expect(controller.state.errorMessage, isNull);
    });

    test('signOut resets controller to unauthenticated state', () async {
      await controller.signInWithEmail(
        email: 'login@example.com',
        password: 'ValidPassword1!',
      );
      expect(controller.state.isAuthenticated, isTrue);

      await controller.signOut();
      expect(controller.state.status, equals(AuthStatus.unauthenticated));
      expect(controller.state.session, isNull);
    });

    test('verifyPhoneOtp transitions to authenticated', () async {
      final result = await controller.verifyPhoneOtp(
        phone: '+14155552671',
        token: '123456',
      );

      expect(result, isTrue);
      expect(controller.state.isAuthenticated, isTrue);
      expect(controller.state.session?.phone, equals('+14155552671'));
    });

    test('detects suspended account state when session role is suspended', () async {
      final suspendedSession = UserSession(
        userId: 'suspended-user',
        email: 'suspended@example.com',
        role: 'suspended',
        createdAt: DateTime.now(),
      );

      fakeRepo.emitSession(suspendedSession);
      // Give async tick for listener
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.isSuspended, isTrue);
      expect(controller.state.accountState, equals(AccountState.suspended));
    });
  });
}
