import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/errors/app_exception.dart';
import 'package:safemate/features/matching/data/repositories/supabase_match_repository.dart';
import 'package:safemate/features/trips/data/repositories/supabase_trip_repository.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip_purpose.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';
import 'package:safemate/features/trips/domain/models/trip_transport.dart';
import 'package:safemate/features/trips/domain/models/trip_visibility.dart';

void main() {
  late SupabaseTripRepository tripRepository;
  late SupabaseMatchRepository matchRepository;

  final testTrip = Trip(
    id: 'test_trip_kyoto',
    userId: 'test_user_owner',
    title: 'Kyoto Autumn Walk',
    origin: 'Tokyo',
    destination: 'Kyoto, Japan',
    startDate: DateTime(2026, 11, 1),
    endDate: DateTime(2026, 11, 10),
    transportMode: TripTransport.train,
    tripPurpose: TripPurpose.exploration,
    budgetTier: TripBudgetTier.moderate,
    status: TripStatus.published,
    visibility: TripVisibility.visibleForMatching,
  );

  setUp(() async {
    tripRepository = SupabaseTripRepository();
    matchRepository = SupabaseMatchRepository(tripRepository: tripRepository);

    // Save test trip in dev repository
    await tripRepository.createTrip(testTrip);
  });

  group('SupabaseMatchRepository Tests (Dev Offline Simulation)', () {
    test('findMatches returns ranked simulated candidates in dev mode', () async {
      final matches = await matchRepository.findMatches(
        userId: 'test_user_owner',
        tripId: 'test_trip_kyoto',
      );

      expect(matches, isNotEmpty);
      expect(matches.length, greaterThanOrEqualTo(2));

      // Sorted descending by score
      for (var i = 0; i < matches.length - 1; i++) {
        expect(matches[i].score.total,
            greaterThanOrEqualTo(matches[i + 1].score.total));
      }

      // Check top match details
      final topMatch = matches.first;
      expect(topMatch.candidate.trip.destination, equals('Kyoto, Japan'));
      expect(topMatch.reasons, isNotEmpty);
      expect(topMatch.score.scoreVersion, equals('v1'));
    });

    test('findMatches respects minScore threshold', () async {
      final matchesAll = await matchRepository.findMatches(
        userId: 'test_user_owner',
        tripId: 'test_trip_kyoto',
        minScore: 50,
      );

      final matchesHighOnly = await matchRepository.findMatches(
        userId: 'test_user_owner',
        tripId: 'test_trip_kyoto',
        minScore: 85,
      );

      expect(matchesAll.length, greaterThanOrEqualTo(matchesHighOnly.length));
      for (final m in matchesHighOnly) {
        expect(m.score.total, greaterThanOrEqualTo(85));
      }
    });

    test('getMatchDetails retrieves detailed match by match ID', () async {
      final matches = await matchRepository.findMatches(
        userId: 'test_user_owner',
        tripId: 'test_trip_kyoto',
      );
      final firstMatchId = matches.first.id;

      final detailedMatch = await matchRepository.getMatchDetails(
        tripId: 'test_trip_kyoto',
        matchId: firstMatchId,
      );

      expect(detailedMatch, isNotNull);
      expect(detailedMatch!.id, equals(firstMatchId));
      expect(detailedMatch.score.total, equals(matches.first.score.total));
      expect(detailedMatch.candidate.profile.displayName.isNotEmpty, isTrue);
    });

    test('dismissMatch suppresses match from subsequent discovery queries', () async {
      final initialMatches = await matchRepository.findMatches(
        userId: 'test_user_owner',
        tripId: 'test_trip_kyoto',
      );

      final matchToDismiss = initialMatches.first;

      await matchRepository.dismissMatch(
        userId: 'test_user_owner',
        matchId: matchToDismiss.id,
      );

      final refreshedMatches = await matchRepository.findMatches(
        userId: 'test_user_owner',
        tripId: 'test_trip_kyoto',
      );

      expect(
        refreshedMatches.any((m) => m.id == matchToDismiss.id),
        isFalse,
      );
    });

    test('findMatches throws AppException when target journey does not exist', () async {
      expect(
        () => matchRepository.findMatches(
          userId: 'test_user_owner',
          tripId: 'non_existent_trip_id',
        ),
        throwsA(isA<AppException>()),
      );
    });
  });
}
