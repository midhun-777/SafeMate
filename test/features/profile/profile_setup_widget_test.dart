import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/app/app.dart';
import 'package:safemate/features/auth/domain/models/account_state.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/auth/domain/models/user_session.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_state.dart';
import 'package:safemate/features/profile/data/repositories/supabase_profile_repository.dart';
import 'package:safemate/features/profile/presentation/controllers/profile_controller.dart';

class FakeWidgetAuthController extends StateNotifier<AuthState>
    implements AuthController {
  FakeWidgetAuthController(super.state);

  @override
  void clearError() {}

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<bool> signInWithEmail({required String email, required String password}) async => true;

  @override
  Future<bool> signInWithOtp({required String phone}) async => true;

  @override
  Future<void> signOut() async {
    state = const AuthState.unauthenticated();
  }

  @override
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async => true;

  @override
  Future<bool> verifyPhoneOtp({required String phone, required String token}) async => true;

  @override
  Future<bool> sendPasswordResetEmail({required String email}) async => true;
}

void main() {
  group('ProfileSetupScreen Widget Tests', () {
    late SupabaseProfileRepository profileRepo;
    const testUserId = 'widget-test-user';

    setUp(() async {
      profileRepo = SupabaseProfileRepository();
      await profileRepo.saveProfile(
        UserProfile(
          id: testUserId,
          displayName: 'Elena Rostova',
          homeCity: 'Rome, Italy',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    });

    testWidgets('renders Step 0 Basic Identity and advances on Continue', (tester) async {
      final session = UserSession(
        userId: testUserId,
        email: 'elena@example.com',
        role: 'user',
        createdAt: DateTime.now(),
      );

      final fakeAuth = FakeWidgetAuthController(
        AuthState.authenticated(
          session: session,
          accountState: AccountState.profileComplete,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => fakeAuth),
            profileRepositoryProvider.overrideWithValue(profileRepo),
          ],
          child: const SafeMateApp(),
        ),
      );

      await tester.pumpAndSettle();

      // On home screen, find "Complete Setup" button and tap it
      final setupButton = find.text('Complete Setup');
      expect(setupButton, findsOneWidget);
      await tester.tap(setupButton);
      await tester.pumpAndSettle();

      // Should now be on ProfileSetupScreen Step 0
      expect(find.text('Who are you traveling as?'), findsOneWidget);
      expect(find.text('Display Name *'), findsOneWidget);
      expect(find.text('Languages Spoken'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);

      // Tap "Continue" to advance to Step 1
      final continueButton = find.text('Continue');
      expect(continueButton, findsOneWidget);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Should now be on Step 1: Travel Personality
      expect(find.text('What kind of trips do you imagine?'), findsOneWidget);
      expect(find.text('🌿 Relaxed'), findsOneWidget);
      expect(find.text('🏔 Adventure'), findsOneWidget);

      // Tap on '🌿 Relaxed'
      await tester.tap(find.text('🌿 Relaxed'));
      await tester.pumpAndSettle();

      // Tap "Save & Exit"
      final saveExit = find.text('Save & Exit');
      expect(saveExit, findsOneWidget);
      await tester.tap(saveExit);
      await tester.pumpAndSettle();

      // Should navigate back to home screen
      expect(find.text('My Journeys'), findsOneWidget);
    });
  });
}
