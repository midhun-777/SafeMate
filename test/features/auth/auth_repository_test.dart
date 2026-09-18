import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/errors/app_exception.dart';
import 'package:safemate/features/auth/data/repositories/supabase_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('SupabaseAuthRepository Tests (Development/Mock Mode)', () {
    late SupabaseAuthRepository repository;

    setUp(() {
      repository = SupabaseAuthRepository();
    });

    test('initial state has null session when unauthenticated', () {
      expect(repository.currentSession, isNull);
    });

    test('signUpWithEmail creates a new session and persists profile', () async {
      final session = await repository.signUpWithEmail(
        email: 'alex.morgan@example.com',
        password: 'ValidPassword123!',
        displayName: 'Alex Morgan',
      );

      expect(session.email, equals('alex.morgan@example.com'));
      expect(session.userId, isNotEmpty);
      expect(repository.currentSession?.userId, equals(session.userId));

      final profile = await repository.getUserProfile(session.userId);
      expect(profile, isNotNull);
      expect(profile?.displayName, equals('Alex Morgan'));
    });

    test('signInWithEmail succeeds with valid credentials', () async {
      final session = await repository.signInWithEmail(
        email: 'test.user@example.com',
        password: 'CorrectPassword1!',
      );

      expect(session.email, equals('test.user@example.com'));
      expect(repository.currentSession, isNotNull);
    });

    test('signInWithEmail throws AuthException on invalid test credentials', () async {
      expect(
        () => repository.signInWithEmail(
          email: 'wrong@example.com',
          password: 'InvalidPassword1',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('signInWithOtp and verifyPhoneOtp establish valid session', () async {
      await repository.signInWithOtp(phone: '+14155552671');

      final session = await repository.verifyPhoneOtp(
        phone: '+14155552671',
        token: '123456',
      );

      expect(session.phone, equals('+14155552671'));
      expect(repository.currentSession?.phone, equals('+14155552671'));
    });

    test('verifyPhoneOtp throws AuthException on invalid token', () async {
      expect(
        () => repository.verifyPhoneOtp(
          phone: '+14155552671',
          token: '999999',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('signOut clears current session and emits null', () async {
      await repository.signInWithEmail(
        email: 'logout.test@example.com',
        password: 'ValidPassword1!',
      );
      expect(repository.currentSession, isNotNull);

      await repository.signOut();
      expect(repository.currentSession, isNull);
    });

    test('updateUserProfile updates stored profile data', () async {
      final session = await repository.signUpWithEmail(
        email: 'profile.update@example.com',
        password: 'ValidPassword1!',
        displayName: 'Initial Profile Name',
      );

      final existingProfile = await repository.getUserProfile(session.userId);
      expect(existingProfile, isNotNull);

      final updated = existingProfile!.copyWith(
        displayName: 'Updated Profile Name',
        trustScore: 40,
      );

      final saved = await repository.updateUserProfile(updated);
      expect(saved.displayName, equals('Updated Profile Name'));
      expect(saved.trustScore, equals(40));

      final fetched = await repository.getUserProfile(session.userId);
      expect(fetched?.displayName, equals('Updated Profile Name'));
    });

    test('sendPasswordResetEmail completes without throwing', () async {
      expect(
        repository.sendPasswordResetEmail(email: 'reset@example.com'),
        completes,
      );
    });
  });
}
