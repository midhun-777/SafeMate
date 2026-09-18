import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/ai/presentation/screens/journey_copilot_screen.dart';
import 'package:safemate/features/ai/presentation/widgets/ai_suggestion_chip.dart';
import 'package:safemate/features/ai/presentation/widgets/itinerary_proposal_card.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_state.dart';
import 'package:safemate/features/trips/data/repositories/supabase_trip_repository.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip_purpose.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';
import 'package:safemate/features/trips/domain/models/trip_transport.dart';
import 'package:safemate/features/trips/presentation/controllers/trip_creation_controller.dart';

void main() {
  group('AI Widget Tests', () {
    testWidgets('AiSuggestionChip renders and triggers callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiSuggestionChip(
              icon: Icons.map,
              label: 'PLAN',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('PLAN'), findsOneWidget);
      expect(find.byIcon(Icons.map), findsOneWidget);

      await tester.tap(find.text('PLAN'));
      expect(tapped, isTrue);
    });

    testWidgets('ItineraryProposalCard displays items and disclaimer', (tester) async {
      var applied = false;
      var dismissed = false;

      final sampleProposal = {
        'type': 'itinerary_proposal',
        'title': '3-Day Zurich Explorer',
        'items': [
          {
            'day': 1,
            'title': 'Day 1: Arrival & Altstadt',
            'morning': 'Check in and orient',
            'afternoon': 'Walk around Old Town',
            'evening': 'Lake dinner',
          }
        ],
        'disclaimer': 'Suggestion only. Verify hours independently.',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryProposalCard(
              proposal: sampleProposal,
              onApply: () => applied = true,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.text('3-Day Zurich Explorer'), findsOneWidget);
      expect(find.text('Day 1: Arrival & Altstadt'), findsOneWidget);
      expect(find.text('Suggestion only. Verify hours independently.'), findsOneWidget);

      await tester.tap(find.text('Apply Plan'));
      expect(applied, isTrue);

      await tester.tap(find.text('Keep Current Plan'));
      expect(dismissed, isTrue);
    });

    testWidgets('JourneyCopilotScreen renders full interface with chips', (tester) async {
      final tripRepo = SupabaseTripRepository();
      const tripId = 'trip_widget_test';
      const userId = 'user_bob';

      await tripRepo.createTrip(
        Trip(
          id: tripId,
          userId: userId,
          title: 'Swiss Escape',
          origin: 'Geneva',
          destination: 'Zermatt',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 3)),
          budgetTier: TripBudgetTier.moderate,
          transportMode: TripTransport.train,
          tripPurpose: TripPurpose.vacation,
          status: TripStatus.published,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(tripRepo),
            authControllerProvider.overrideWith((ref) => _FakeAuthController(userId)),
          ],
          child: const MaterialApp(
            home: JourneyCopilotScreen(
              tripId: tripId,
              destination: 'Zermatt',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Journey Copilot'), findsOneWidget);
      expect(find.text('Zermatt'), findsOneWidget);
      expect(find.text('PLAN'), findsOneWidget);
      expect(find.text('PREPARE'), findsOneWidget);
      expect(find.text('ADAPT'), findsOneWidget);
      expect(find.text('SAFETY'), findsOneWidget);
      expect(find.text('COMPANION'), findsOneWidget);
      expect(find.text('SUMMARY'), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });
  });
}

class _FakeAuthController extends StateNotifier<AuthState> implements AuthController {
  _FakeAuthController(String userId)
      : super(
          AuthState(
            status: AuthStatus.authenticated,
            profile: UserProfile(
              id: userId,
              displayName: 'Bob Traveler',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ),
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
