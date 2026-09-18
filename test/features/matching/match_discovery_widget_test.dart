import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/theme/app_theme.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/matching/domain/models/compatibility_score.dart';
import 'package:safemate/features/matching/domain/models/match_candidate.dart';
import 'package:safemate/features/matching/domain/models/match_reason.dart';
import 'package:safemate/features/matching/domain/models/match_result.dart';
import 'package:safemate/features/matching/presentation/screens/match_detail_screen.dart';
import 'package:safemate/features/matching/presentation/widgets/match_card.dart';
import 'package:safemate/features/matching/presentation/widgets/match_empty_state.dart';
import 'package:safemate/features/profile/domain/models/travel_personality.dart';
import 'package:safemate/features/profile/domain/models/travel_preferences.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip_purpose.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';
import 'package:safemate/features/trips/domain/models/trip_transport.dart';
import 'package:safemate/features/trips/domain/models/trip_visibility.dart';

void main() {
  final now = DateTime(2026, 6, 1);

  final sampleCandidate = MatchCandidate(
    trip: Trip(
      id: 'cand_trip_1',
      userId: 'cand_user_1',
      title: 'Exploring Kyoto',
      origin: 'Tokyo',
      destination: 'Kyoto, Japan',
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 6, 10),
      transportMode: TripTransport.train,
      budgetTier: TripBudgetTier.moderate,
      tripPurpose: TripPurpose.exploration,
      status: TripStatus.published,
      visibility: TripVisibility.visibleForMatching,
    ),
    profile: UserProfile(
      id: 'cand_user_1',
      displayName: 'Elena Rostova',
      homeCity: 'Prague',
      trustScore: 92,
      completionPercentage: 90,
      createdAt: now,
      updatedAt: now,
    ),
    preferences: TravelPreferences(
      id: 'pref_cand_1',
      userId: 'cand_user_1',
      travelPace: TravelPace.moderate,
      planningStyle: PlanningStyle.flexible,
      schedulePreference: ScheduleStyle.flexible,
      activityInterests: const ['Culture', 'Photography'],
      createdAt: now,
      updatedAt: now,
    ),
  );

  final sampleScore = const CompatibilityScore(
    total: 88,
    band: MatchQualityBand.excellent,
    components: MatchComponentScore(
      routeScore: 100,
      dateScore: 100,
      transportScore: 90,
      budgetScore: 90,
      purposeScore: 100,
      styleScore: 80,
      preferenceScore: 80,
      scheduleScore: 80,
    ),
  );

  final sampleResult = MatchResult(
    id: 'match_sample_1',
    tripId: 'target_trip_1',
    candidateTripId: 'cand_trip_1',
    userId: 'user_target',
    candidateUserId: 'cand_user_1',
    candidate: sampleCandidate,
    score: sampleScore,
    reasons: const [
      MatchReason(
        title: 'Same Destination',
        explanation: 'Both visiting Kyoto, Japan',
        type: MatchReasonType.sameDestination,
      ),
      MatchReason(
        title: 'Exact Travel Dates',
        explanation: 'Traveling Jun 1 – Jun 10',
        type: MatchReasonType.dateOverlap,
      ),
    ],
    mismatches: const [
      MismatchExplanation(
        dimension: 'Travel Pace',
        note: 'Slightly different daily tempo',
      ),
    ],
    createdAt: now,
    evaluatedAt: now,
  );

  Widget createWidgetUnderTest(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: child),
      ),
    );
  }

  group('MatchCard Widget Tests', () {
    testWidgets('renders candidate information, score badge, and reasons', (tester) async {
      bool tapped = false;
      bool dismissed = false;

      await tester.pumpWidget(
        createWidgetUnderTest(
          MatchCard(
            match: sampleResult,
            onTap: () => tapped = true,
            onDismiss: () => dismissed = true,
          ),
        ),
      );

      // Verify display name & home city
      expect(find.text('Elena Rostova'), findsOneWidget);
      expect(find.text('Prague'), findsOneWidget);

      // Verify score badge & quality label
      expect(find.text('88% Match'), findsOneWidget);
      expect(find.text('Excellent Match'), findsOneWidget);

      // Verify reasons
      expect(find.text('Same Destination'), findsOneWidget);
      expect(find.text('Exact Travel Dates'), findsOneWidget);

      // Tap 'See Why' action button
      await tester.tap(find.text('See Why'));
      expect(tapped, isTrue);

      // Tap 'Dismiss' action button
      await tester.tap(find.text('Dismiss'));
      expect(dismissed, isTrue);
    });
  });

  group('MatchEmptyState Widget Tests', () {
    testWidgets('renders headline, explanation, and triggers onAdjustFilters', (tester) async {
      bool adjusted = false;

      await tester.pumpWidget(
        createWidgetUnderTest(
          MatchEmptyState(
            onAdjustFilters: () => adjusted = true,
            onRefresh: () {},
          ),
        ),
      );

      expect(find.text('No strong matches yet'), findsOneWidget);
      expect(find.textContaining('Your journey is published'), findsOneWidget);

      // Tap reset filters button
      await tester.tap(find.text('Reset Filters'));
      expect(adjusted, isTrue);
    });
  });

  group('MatchDetailScreen Widget Tests', () {
    testWidgets('renders "Why this match?", score breakdown, highlights, and differences', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          MatchDetailScreen(
            tripId: 'target_trip_1',
            matchId: 'match_sample_1',
            initialMatch: sampleResult,
          ),
        ),
      );

      // App bar
      expect(find.text('Why This Match?'), findsOneWidget);

      // Candidate Passport
      expect(find.text('Elena Rostova'), findsOneWidget);
      expect(find.text('Prague'), findsOneWidget);
      expect(find.text('Trust Score: 92/100'), findsOneWidget);

      // Total score badge
      expect(find.text('88%'), findsOneWidget);
      expect(find.text('Excellent Match Estimate'), findsOneWidget);

      // Positive Highlights
      expect(find.text('Why You Match'), findsOneWidget);
      expect(find.text('Same Destination'), findsOneWidget);
      expect(find.text('Both visiting Kyoto, Japan'), findsOneWidget);

      // Differences section
      expect(find.text('Some Preferences Differ'), findsOneWidget);
      expect(find.text('Slightly different daily tempo'), findsOneWidget);

      // Component Breakdown
      expect(find.text('Compatibility Breakdown'), findsOneWidget);
      expect(find.text('Route & Destination (25%)'), findsOneWidget);
      expect(find.text('Travel Dates (20%)'), findsOneWidget);
      expect(find.text('Transport Mode (10%)'), findsOneWidget);
      expect(find.text('Budget Compatibility (10%)'), findsOneWidget);
    });
  });
}
