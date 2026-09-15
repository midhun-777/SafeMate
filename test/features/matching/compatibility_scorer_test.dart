import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/matching/domain/services/compatibility_scorer.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';

void main() {
  group('CompatibilityScorer Tests', () {
    test('Calculates high compatibility score for identical destination, dates, and purpose', () {
      final tripA = Trip(
        id: 'trip-a',
        userId: 'user-a',
        title: 'Tokyo Exploration',
        origin: 'San Francisco',
        destination: 'Tokyo',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 10),
        transportMode: 'flight',
        tripPurpose: 'cultural',
      );

      final tripB = Trip(
        id: 'trip-b',
        userId: 'user-b',
        title: 'Tokyo Autumn',
        origin: 'San Francisco',
        destination: 'Tokyo',
        startDate: DateTime(2026, 10, 2),
        endDate: DateTime(2026, 10, 9),
        transportMode: 'flight',
        tripPurpose: 'cultural',
      );

      final result = CompatibilityScorer.calculate(
        matchId: 'match-1',
        tripA: tripA,
        tripB: tripB,
      );

      // Destination: 30, Origin: 15, Date overlap (>=3 days): 25, Transport: 15, Purpose: 15 = 100
      expect(result.compatibilityScore, equals(100));
      expect(result.matchReasons, contains('Same destination: Tokyo'));
      expect(result.matchReasons, contains('Same starting point: San Francisco'));
      expect(result.matchReasons, contains('Same preferred transport: flight'));
      expect(result.matchReasons, contains('Shared trip purpose: cultural'));
      expect(result.scoreBreakdown['destination_points'], equals(30));
      expect(result.scoreBreakdown['date_overlap_points'], equals(25));
    });

    test('Calculates lower score when destinations and dates differ', () {
      final tripA = Trip(
        id: 'trip-a',
        userId: 'user-a',
        title: 'Rome Holiday',
        origin: 'London',
        destination: 'Rome',
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 7),
        transportMode: 'flight',
        tripPurpose: 'leisure',
      );

      final tripB = Trip(
        id: 'trip-b',
        userId: 'user-b',
        title: 'Berlin Tech Trip',
        origin: 'Manchester',
        destination: 'Berlin',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 7),
        transportMode: 'train',
        tripPurpose: 'workation',
      );

      final result = CompatibilityScorer.calculate(
        matchId: 'match-2',
        tripA: tripA,
        tripB: tripB,
      );

      // Destination: 0, Origin: 0, Date overlap: 0, Transport: 0, Purpose: 0 = 0
      expect(result.compatibilityScore, equals(0));
      expect(result.matchReasons, isEmpty);
      expect(result.scoreBreakdown['destination_points'], equals(0));
    });

    test('Score is always strictly bounded between 0 and 100', () {
      final tripA = Trip(
        id: 'trip-a',
        userId: 'user-a',
        title: 'Trip A',
        origin: 'City A',
        destination: 'City B',
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 5),
      );

      final tripB = Trip(
        id: 'trip-b',
        userId: 'user-b',
        title: 'Trip B',
        origin: 'City A',
        destination: 'City B',
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 5),
      );

      final result = CompatibilityScorer.calculate(
        matchId: 'match-3',
        tripA: tripA,
        tripB: tripB,
      );

      expect(result.compatibilityScore, greaterThanOrEqualTo(0));
      expect(result.compatibilityScore, lessThanOrEqualTo(100));
    });
  });
}
