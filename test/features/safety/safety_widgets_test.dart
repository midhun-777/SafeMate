import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/services/analytics_service.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/auth/domain/models/user_session.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_state.dart';
import 'package:safemate/features/safety/domain/services/ai_safety_rule_engine.dart';
import 'package:safemate/features/safety/presentation/controllers/safety_controllers.dart';
import 'package:safemate/features/safety/presentation/screens/pre_journey_safety_screen.dart';
import 'package:safemate/features/safety/presentation/screens/safety_center_screen.dart';
import 'package:safemate/features/safety/presentation/widgets/ai_safety_advisory_banner.dart';
import 'package:safemate/features/safety/presentation/widgets/verification_badge.dart';

class _MockAuthController extends StateNotifier<AuthState> implements AuthController {
  _MockAuthController()
      : super(
          AuthState(
            status: AuthStatus.authenticated,
            session: UserSession(
              userId: 'test-user-id',
              email: 'traveler@safemate.internal',
              createdAt: DateTime.now(),
            ),
            profile: UserProfile(
              id: 'test-user-id',
              displayName: 'Alex Morgan',
              isVerified: true,
              isPhoneVerified: true,
              trustScore: 92,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ),
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Phase 9 Safety Widgets', () {
    testWidgets('VerificationBadge renders correct labels and icons', (tester) async {
      // 1. Identity verified
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VerificationBadge(isVerified: true),
          ),
        ),
      );
      expect(find.text('Identity Verified'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);

      // 2. Phone verified
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VerificationBadge(isVerified: false, isPhoneVerified: true),
          ),
        ),
      );
      expect(find.text('Phone Verified'), findsOneWidget);
      expect(find.byIcon(Icons.phone_android), findsOneWidget);

      // 3. Unverified
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VerificationBadge(isVerified: false, isPhoneVerified: false),
          ),
        ),
      );
      expect(find.text('Unverified'), findsOneWidget);
    });

    testWidgets('AiSafetyAdvisoryBanner displays warning and triggers suggestion callbacks', (tester) async {
      String? tappedReply;

      const warning = SafetyWarning(
        severity: SafetyWarningSeverity.warning,
        title: 'Financial Advisory',
        message: 'Do not send advance wire payments to companions.',
        suggestedReplies: [
          'Let us coordinate our journey schedule here.',
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiSafetyAdvisoryBanner(
              warning: warning,
              onApplySuggestion: (reply) {
                tappedReply = reply;
              },
            ),
          ),
        ),
      );

      expect(find.text('Financial Advisory'), findsOneWidget);
      expect(find.text('Do not send advance wire payments to companions.'), findsOneWidget);
      expect(find.text('Let us coordinate our journey schedule here.'), findsOneWidget);

      await tester.tap(find.text('Let us coordinate our journey schedule here.'));
      await tester.pumpAndSettle();

      expect(tappedReply, 'Let us coordinate our journey schedule here.');
    });

    testWidgets('PreJourneySafetyScreen renders checklist and meetup code', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: PreJourneySafetyScreen(tripId: 'trip-123'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pre-Journey Safety Check'), findsOneWidget);
      expect(find.text('Meetup Verification Code'), findsOneWidget);
      expect(find.text('1. Verified Profile Check'), findsOneWidget);
      expect(find.text('Complete All 6 Checks to Proceed'), findsOneWidget);

      // Tap first check
      await tester.tap(find.text('1. Verified Profile Check'));
      await tester.pumpAndSettle();
    });

    testWidgets('SafetyCenterScreen renders feature cards and trust banner', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _MockAuthController()),
            privacySettingsControllerProvider.overrideWith(
              (ref) => PrivacySettingsController(
                repository: ref.watch(safetyRepositoryProvider),
                analytics: ref.watch(analyticsServiceProvider),
                userId: 'test-user-id',
              ),
            ),
          ],
          child: const MaterialApp(
            home: SafetyCenterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Safety & Trust Center'), findsOneWidget);
      expect(find.text('Traveler Trust Shield'), findsOneWidget);
      expect(find.text('Identity Verification'), findsOneWidget);
      expect(find.text('Trusted Safety Contacts'), findsOneWidget);
      expect(find.text('Privacy & Visibility'), findsOneWidget);
      expect(find.text('Pre-Journey Safety & Meetup Code'), findsOneWidget);
      expect(find.text('Report a Concern or Block User'), findsOneWidget);
    });
  });
}
