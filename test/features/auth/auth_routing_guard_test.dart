import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/app/app.dart';
import 'package:safemate/features/auth/domain/models/account_state.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/auth/domain/models/user_session.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_state.dart';

class TestAuthController extends StateNotifier<AuthState>
    implements AuthController {
  TestAuthController(super.initialState);

  void setState(AuthState newState) {
    state = newState;
  }

  @override
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return true;
  }

  @override
  Future<bool> signInWithOtp({required String phone}) async {
    return true;
  }

  @override
  Future<void> signOut() async {
    state = const AuthState.unauthenticated();
  }

  @override
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return true;
  }

  @override
  Future<bool> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    return true;
  }

  @override
  Future<bool> sendPasswordResetEmail({required String email}) async {
    return true;
  }
}

void main() {
  group('Auth Routing Guard Tests', () {
    testWidgets('unauthenticated user is redirected to WelcomeScreen',
        (tester) async {
      final testController = TestAuthController(
        const AuthState.unauthenticated(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => testController),
          ],
          child: const SafeMateApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Should be on WelcomeScreen
      expect(find.text('SafeMate'), findsWidgets);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Verified Travelers'), findsOneWidget);
    });

    testWidgets('authenticated user is redirected to TripsHomeScreen',
        (tester) async {
      final session = UserSession(
        userId: 'auth-test-user',
        email: 'traveler@safemate.com',
        role: 'user',
        createdAt: DateTime.now(),
      );

      final profile = UserProfile(
        id: session.userId,
        displayName: 'Aria Stark',
        trustScore: 92,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final testController = TestAuthController(
        AuthState.authenticated(
          session: session,
          profile: profile,
          accountState: AccountState.profileComplete,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => testController),
          ],
          child: const SafeMateApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Should be on TripsHomeScreen displaying user info
      expect(find.text('Hello, Aria Stark'), findsOneWidget);
      expect(find.text('traveler@safemate.com'), findsOneWidget);
      expect(find.text('Trust: 92'), findsOneWidget);
      expect(find.text('My Journeys'), findsOneWidget);
    });

    testWidgets('suspended user is redirected to SuspendedScreen',
        (tester) async {
      final suspendedSession = UserSession(
        userId: 'suspended-123',
        email: 'banned@safemate.com',
        role: 'suspended',
        createdAt: DateTime.now(),
      );

      final testController = TestAuthController(
        AuthState(
          status: AuthStatus.authenticated,
          session: suspendedSession,
          accountState: AccountState.suspended,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => testController),
          ],
          child: const SafeMateApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Should be on SuspendedScreen
      expect(find.text('Account Suspended'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('signing out redirects user back to WelcomeScreen',
        (tester) async {
      final session = UserSession(
        userId: 'auth-signout-user',
        email: 'aria@safemate.com',
        role: 'user',
        createdAt: DateTime.now(),
      );

      final testController = TestAuthController(
        AuthState.authenticated(
          session: session,
          accountState: AccountState.profileComplete,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => testController),
          ],
          child: const SafeMateApp(),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Hello, aria'), findsOneWidget);

      // Tap the Sign Out icon button in AppBar
      final signOutButton = find.byIcon(Icons.logout_outlined);
      expect(signOutButton, findsOneWidget);
      await tester.tap(signOutButton);
      await tester.pumpAndSettle();

      // Should now be on WelcomeScreen
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });
  });
}
