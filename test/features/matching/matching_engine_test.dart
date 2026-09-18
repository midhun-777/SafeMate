import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/matching/domain/models/compatibility_score.dart';
import 'package:safemate/features/matching/domain/models/match_candidate.dart';
import 'package:safemate/features/matching/domain/models/match_eligibility.dart';
import 'package:safemate/features/matching/domain/services/matching_engine.dart';
import 'package:safemate/features/profile/domain/models/profile_visibility.dart';
import 'package:safemate/features/profile/domain/models/travel_personality.dart';
import 'package:safemate/features/profile/domain/models/travel_preferences.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip_preferences.dart';
import 'package:safemate/features/trips/domain/models/trip_purpose.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';
import 'package:safemate/features/trips/domain/models/trip_transport.dart';
import 'package:safemate/features/trips/domain/models/trip_visibility.dart';

void main() {
  const engine = MatchingEngine();
  final baseDate = DateTime(2026, 6, 1);
  final endDate = DateTime(2026, 6, 10);

  Trip createTestTrip({
    String id = 'trip_target',
    String userId = 'user_target',
    String origin = 'Singapore',
    String destination = 'Kyoto, Japan',
    DateTime? start,
    DateTime? end,
    TripTransport transport = TripTransport.flight,
    TripBudgetTier budget = TripBudgetTier.moderate,
    TripPurpose purpose = TripPurpose.vacation,
    List<String> styles = const ['Culture', 'Food'],
    TripStatus status = TripStatus.published,
    TripVisibility visibility = TripVisibility.visibleForMatching,
    TripPreferences? preferences,
  }) {
    return Trip(
      id: id,
      userId: userId,
      title: 'Journey to $destination',
      origin: origin,
      destination: destination,
      startDate: start ?? baseDate,
      endDate: end ?? endDate,
      transportMode: transport,
      budgetTier: budget,
      tripPurpose: purpose,
      tripStyles: styles,
      status: status,
      visibility: visibility,
      preferences: preferences,
    );
  }

  UserProfile createTestProfile({
    String id = 'user_target',
    String displayName = 'Target User',
    ProfileVisibility visibility = ProfileVisibility.publicToMatches,
    int trustScore = 80,
    int completion = 90,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName,
      visibility: visibility,
      trustScore: trustScore,
      completionPercentage: completion,
      createdAt: baseDate,
      updatedAt: baseDate,
    );
  }

  MatchCandidate createTestCandidate({
    String tripId = 'trip_cand_1',
    String userId = 'user_cand_1',
    String origin = 'Singapore',
    String destination = 'Kyoto, Japan',
    DateTime? start,
    DateTime? end,
    TripTransport transport = TripTransport.flight,
    TripBudgetTier budget = TripBudgetTier.moderate,
    TripPurpose purpose = TripPurpose.vacation,
    List<String> styles = const ['Culture', 'Food'],
    TripStatus status = TripStatus.published,
    TripVisibility visibility = TripVisibility.visibleForMatching,
    ProfileVisibility profileVisibility = ProfileVisibility.publicToMatches,
    int trustScore = 85,
    int completion = 85,
    TravelPreferences? preferences,
    TripPreferences? tripPreferences,
  }) {
    return MatchCandidate(
      trip: Trip(
        id: tripId,
        userId: userId,
        title: 'Exploring $destination',
        origin: origin,
        destination: destination,
        startDate: start ?? baseDate,
        endDate: end ?? endDate,
        transportMode: transport,
        budgetTier: budget,
        tripPurpose: purpose,
        tripStyles: styles,
        status: status,
        visibility: visibility,
        preferences: tripPreferences,
      ),
      profile: UserProfile(
        id: userId,
        displayName: 'Candidate $userId',
        visibility: profileVisibility,
        trustScore: trustScore,
        completionPercentage: completion,
        createdAt: baseDate,
        updatedAt: baseDate,
      ),
      preferences: preferences ??
          TravelPreferences(
            id: 'pref_$userId',
            userId: userId,
            travelPace: TravelPace.moderate,
            planningStyle: PlanningStyle.flexible,
            schedulePreference: ScheduleStyle.flexible,
            activityInterests: const ['Culture', 'Food'],
            dietaryPreferences: const ['Vegetarian'],
            createdAt: baseDate,
            updatedAt: baseDate,
          ),
    );
  }

  group('MatchingEngine — Hard Eligibility Rules (Pre-Scoring)', () {
    final userTrip = createTestTrip();
    final userProfile = createTestProfile();

    test('Rejects self-matching (same user ID on trip and candidate)', () {
      final candidate = createTestCandidate(userId: userTrip.userId);
      final eligibility = engine.evaluateEligibility(
        userTrip: userTrip,
        userProfile: userProfile,
        candidateTrip: candidate.trip,
        candidateProfile: candidate.profile,
      );

      expect(eligibility.isEligible, isFalse);
      expect(eligibility.failureReason, equals(MatchFailureReason.selfMatch));
    });

    test('Rejects blocked candidates', () {
      final candidate = createTestCandidate(userId: 'blocked_user_99');
      final eligibility = engine.evaluateEligibility(
        userTrip: userTrip,
        userProfile: userProfile,
        candidateTrip: candidate.trip,
        candidateProfile: candidate.profile,
        isBlocked: true,
      );

      expect(eligibility.isEligible, isFalse);
      expect(eligibility.failureReason, equals(MatchFailureReason.blockedUser));
    });

    test('Rejects candidates with non-published trip status', () {
      final draftCandidate = createTestCandidate(status: TripStatus.draft);
      expect(
        engine.evaluateEligibility(
          userTrip: userTrip,
          userProfile: userProfile,
          candidateTrip: draftCandidate.trip,
          candidateProfile: draftCandidate.profile,
        ).failureReason,
        equals(MatchFailureReason.tripDraft),
      );

      final cancelledCandidate = createTestCandidate(status: TripStatus.cancelled);
      expect(
        engine.evaluateEligibility(
          userTrip: userTrip,
          userProfile: userProfile,
          candidateTrip: cancelledCandidate.trip,
          candidateProfile: cancelledCandidate.profile,
        ).failureReason,
        equals(MatchFailureReason.tripCancelled),
      );

      final completedCandidate = createTestCandidate(status: TripStatus.completed);
      expect(
        engine.evaluateEligibility(
          userTrip: userTrip,
          userProfile: userProfile,
          candidateTrip: completedCandidate.trip,
          candidateProfile: completedCandidate.profile,
        ).failureReason,
        equals(MatchFailureReason.tripCompleted),
      );
    });

    test('Rejects candidates with private trip visibility', () {
      final candidate = createTestCandidate(visibility: TripVisibility.private);
      final eligibility = engine.evaluateEligibility(
        userTrip: userTrip,
        userProfile: userProfile,
        candidateTrip: candidate.trip,
        candidateProfile: candidate.profile,
      );

      expect(eligibility.isEligible, isFalse);
      expect(eligibility.failureReason, equals(MatchFailureReason.privateTrip));
    });

    test('Rejects candidates with hidden profile visibility', () {
      final candidate = createTestCandidate(profileVisibility: ProfileVisibility.hidden);
      final eligibility = engine.evaluateEligibility(
        userTrip: userTrip,
        userProfile: userProfile,
        candidateTrip: candidate.trip,
        candidateProfile: candidate.profile,
      );

      expect(eligibility.isEligible, isFalse);
      expect(eligibility.failureReason, equals(MatchFailureReason.hiddenProfile));
    });

    test('Rejects candidates with low profile completion (<30%)', () {
      final incompleteCandidate = createTestCandidate(completion: 20);

      final eligibility = engine.evaluateEligibility(
        userTrip: userTrip,
        userProfile: userProfile,
        candidateTrip: incompleteCandidate.trip,
        candidateProfile: incompleteCandidate.profile,
      );

      expect(eligibility.isEligible, isFalse);
      expect(eligibility.failureReason, equals(MatchFailureReason.profileIncomplete));
    });

    test('Rejects candidates with zero date overlap and gap exceeding tolerance', () {
      final distantCandidate = createTestCandidate(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 10),
      );

      final eligibility = engine.evaluateEligibility(
        userTrip: userTrip,
        userProfile: userProfile,
        candidateTrip: distantCandidate.trip,
        candidateProfile: distantCandidate.profile,
      );

      expect(eligibility.isEligible, isFalse);
      expect(eligibility.failureReason, equals(MatchFailureReason.datesIncompatible));
    });

    test('Approves candidates with exact destination and overlapping dates', () {
      final candidate = createTestCandidate();
      final eligibility = engine.evaluateEligibility(
        userTrip: userTrip,
        userProfile: userProfile,
        candidateTrip: candidate.trip,
        candidateProfile: candidate.profile,
      );

      expect(eligibility.isEligible, isTrue);
      expect(eligibility.failureReason, isNull);
    });
  });

  group('MatchingEngine — Component Compatibility Scoring', () {
    final userTrip = createTestTrip();
    final userProfile = createTestProfile();

    test('Calculates high score for matching criteria', () {
      final candidate = createTestCandidate();
      final score = engine.calculateScore(
        userTrip: userTrip,
        userProfile: userProfile,
        candidateTrip: candidate.trip,
        candidateProfile: candidate.profile,
        candidatePreferences: candidate.preferences,
      );

      expect(score.scoreVersion, equals('v1'));
      expect(score.total, greaterThanOrEqualTo(80));
      expect(score.band, equals(MatchQualityBand.excellent));
      expect(score.components.routeScore, equals(100));
      expect(score.components.dateScore, equals(100));
      expect(score.components.transportScore, equals(100));
      expect(score.components.budgetScore, equals(100));
      expect(score.components.purposeScore, equals(100));
    });

    test('Date overlap scoring scales with overlap duration', () {
      // 5-day overlap out of 10 days
      final candidate50 = createTestCandidate(
        start: DateTime(2026, 6, 6),
        end: DateTime(2026, 6, 15),
      );

      final score50 = engine.calculateScore(
        userTrip: userTrip,
        userProfile: userProfile,
        candidateTrip: candidate50.trip,
        candidateProfile: candidate50.profile,
      );

      expect(score50.components.dateScore, equals(85));

      // Departure adjacent by 1 day, no calendar overlap (May 31 to May 31)
      final candidateAdjacent = createTestCandidate(
        start: DateTime(2026, 5, 31),
        end: DateTime(2026, 5, 31),
      );

      final scoreAdj = engine.calculateScore(
        userTrip: userTrip,
        userProfile: userProfile,
        candidateTrip: candidateAdjacent.trip,
        candidateProfile: candidateAdjacent.profile,
      );

      expect(scoreAdj.components.dateScore, equals(55));
    });

    test('Budget tier scoring handles flexible and adjacent tiers correctly', () {
      final candBudgetTiers = {
        TripBudgetTier.moderate: 100, // Identical
        TripBudgetTier.flexible: 90, // Flexible
        TripBudgetTier.budget: 75, // Adjacent tier
        TripBudgetTier.comfortable: 75, // Adjacent tier
      };

      for (final entry in candBudgetTiers.entries) {
        final candidate = createTestCandidate(budget: entry.key);
        final score = engine.calculateScore(
          userTrip: userTrip,
          userProfile: userProfile,
          candidateTrip: candidate.trip,
          candidateProfile: candidate.profile,
        );

        expect(score.components.budgetScore, equals(entry.value),
            reason: 'Failed for budget tier ${entry.key}');
      }
    });

    test('Transport mode scoring gives high marks for flexible and exact matches', () {
      final candTransport = {
        TripTransport.flight: 100,
        TripTransport.flexible: 90,
        TripTransport.train: 60,
      };

      for (final entry in candTransport.entries) {
        final candidate = createTestCandidate(transport: entry.key);
        final score = engine.calculateScore(
          userTrip: userTrip,
          userProfile: userProfile,
          candidateTrip: candidate.trip,
          candidateProfile: candidate.profile,
        );

        expect(score.components.transportScore, equals(entry.value));
      }
    });
  });

  group('MatchingEngine — 3-State Companion Preferences Evaluation', () {
    test('Evaluates SELECTED vs NOT_SELECTED vs NOT_SPECIFIED accurately', () {
      // User trip requires Vegetarian diet, Hiking activity, and Flight
      final userTripWithPrefs = createTestTrip(
        preferences: TripPreferences(
          tripId: 'trip_target',
          dietaryPreferences: const ['Vegetarian'],
          activityInterests: const ['Hiking', 'Photography'],
          preferredTransport: const ['flight'],
        ),
      );

      // Candidate 1: Matches Vegetarian and Hiking (SELECTED)
      final candidateMatch = createTestCandidate(
        preferences: TravelPreferences(
          id: 'p1',
          userId: 'c1',
          dietaryPreferences: const ['Vegetarian'],
          activityInterests: const ['Hiking', 'Photography', 'Food'],
          preferredTransport: const ['flight'],
          createdAt: baseDate,
          updatedAt: baseDate,
        ),
      );

      final scoreMatch = engine.calculateScore(
        userTrip: userTripWithPrefs,
        userProfile: createTestProfile(),
        candidateTrip: candidateMatch.trip,
        candidateProfile: candidateMatch.profile,
        candidatePreferences: candidateMatch.preferences,
      );

      expect(scoreMatch.components.preferenceScore, greaterThanOrEqualTo(95));

      // Candidate 2: Completely omitted preferences (NOT_SPECIFIED)
      final candidateNotSpecified = createTestCandidate(
        preferences: TravelPreferences(
          id: 'p2',
          userId: 'c2',
          dietaryPreferences: const [],
          activityInterests: const [],
          preferredTransport: const [],
          createdAt: baseDate,
          updatedAt: baseDate,
        ),
      );

      final scoreNotSpecified = engine.calculateScore(
        userTrip: userTripWithPrefs,
        userProfile: createTestProfile(),
        candidateTrip: candidateNotSpecified.trip,
        candidateProfile: candidateNotSpecified.profile,
        candidatePreferences: candidateNotSpecified.preferences,
      );

      expect(scoreNotSpecified.components.preferenceScore, equals(85));

      // Candidate 3: User selected non-overlapping interests (NOT_SELECTED)
      final candidateNotSelected = createTestCandidate(
        preferences: TravelPreferences(
          id: 'p3',
          userId: 'c3',
          dietaryPreferences: const ['Meat-lover'],
          activityInterests: const ['Nightclubbing'],
          preferredTransport: const ['car'],
          createdAt: baseDate,
          updatedAt: baseDate,
        ),
      );

      final scoreNotSelected = engine.calculateScore(
        userTrip: userTripWithPrefs,
        userProfile: createTestProfile(),
        candidateTrip: candidateNotSelected.trip,
        candidateProfile: candidateNotSelected.profile,
        candidatePreferences: candidateNotSelected.preferences,
      );

      expect(scoreNotSelected.components.preferenceScore, equals(85));
    });
  });

  group('MatchingEngine — Invariant & Determinism Tests', () {
    final userTrip = createTestTrip();
    final userProfile = createTestProfile();
    final candidate = createTestCandidate();

    test('Deterministic: Identical inputs produce identical score and reasons repeatedly', () {
      final run1 = engine.calculateScore(
        userTrip: userTrip,
        userProfile: userProfile,
        candidateTrip: candidate.trip,
        candidateProfile: candidate.profile,
        candidatePreferences: candidate.preferences,
      );

      final run2 = engine.calculateScore(
        userTrip: userTrip,
        userProfile: userProfile,
        candidateTrip: candidate.trip,
        candidateProfile: candidate.profile,
        candidatePreferences: candidate.preferences,
      );

      expect(run1.total, equals(run2.total));
      expect(run1.band, equals(run2.band));
      expect(run1.scoreVersion, equals(run2.scoreVersion));
      expect(run1.components.routeScore, equals(run2.components.routeScore));
      expect(run1.components.dateScore, equals(run2.components.dateScore));

      final reasons1 = engine.generateReasons(
        userTrip: userTrip,
        candidateTrip: candidate.trip,
        score: run1,
        candidatePreferences: candidate.preferences,
      );

      final reasons2 = engine.generateReasons(
        userTrip: userTrip,
        candidateTrip: candidate.trip,
        score: run2,
        candidatePreferences: candidate.preferences,
      );

      expect(reasons1.length, equals(reasons2.length));
      for (var i = 0; i < reasons1.length; i++) {
        expect(reasons1[i].title, equals(reasons2[i].title));
        expect(reasons1[i].explanation, equals(reasons2[i].explanation));
        expect(reasons1[i].type, equals(reasons2[i].type));
      }
    });

    test('Score total is strictly bounded between 0 and 100', () {
      final score = engine.calculateScore(
        userTrip: userTrip,
        userProfile: userProfile,
        candidateTrip: candidate.trip,
        candidateProfile: candidate.profile,
      );

      expect(score.total, greaterThanOrEqualTo(0));
      expect(score.total, lessThanOrEqualTo(100));
    });

    test('Mismatch notes identify transparent differences without judging', () {
      final differentCandidate = createTestCandidate(
        budget: TripBudgetTier.comfortable,
        transport: TripTransport.car,
        start: DateTime(2026, 6, 8),
        end: DateTime(2026, 6, 17),
      );

      final mismatches = engine.generateMismatches(
        userTrip: userTrip,
        candidateTrip: differentCandidate.trip,
      );

      expect(mismatches, isNotEmpty);
      expect(mismatches.any((m) => m.dimension == 'Budget Tier'), isTrue);
      expect(mismatches.any((m) => m.dimension == 'Travel Dates'), isTrue);
    });

    test('rankCandidates filters out ineligible candidates and sorts descending by score', () {
      final candHigh = createTestCandidate(userId: 'c_high');
      final candMid = createTestCandidate(
        userId: 'c_mid',
        budget: TripBudgetTier.budget,
        transport: TripTransport.bus,
      );
      final candIneligible = createTestCandidate(
        userId: 'c_ineligible',
        status: TripStatus.draft,
      );

      final results = engine.rankCandidates(
        userTrip: userTrip,
        userProfile: userProfile,
        candidates: [candMid, candIneligible, candHigh],
      );

      expect(results.length, equals(2));
      expect(results.first.candidateUserId, equals('c_high'));
      expect(results.last.candidateUserId, equals('c_mid'));
      expect(results.first.score.total, greaterThanOrEqualTo(results.last.score.total));
    });
  });
}
