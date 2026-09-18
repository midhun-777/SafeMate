import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip_purpose.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';
import 'package:safemate/features/trips/domain/models/trip_transport.dart';
import 'package:safemate/features/trips/domain/models/trip_visibility.dart';

void main() {
  group('Trip Model Tests (Phase 6 Journey Management)', () {
    final start = DateTime(2026, 8, 10);
    final end = DateTime(2026, 8, 20);

    test('Trip instantiates correctly with valid parameters and enums', () {
      final trip = Trip(
        id: 'trip-1',
        userId: 'user-1',
        title: 'Alpine Trekking',
        origin: 'Geneva',
        destination: 'Zermatt',
        startDate: start,
        endDate: end,
        transportMode: TripTransport.train,
        tripPurpose: TripPurpose.adventure,
        budgetTier: TripBudgetTier.moderate,
        visibility: TripVisibility.visibleForMatching,
        status: TripStatus.published,
        maxCompanions: 3,
        tripStyles: const ['mountain', 'hiking'],
      );

      expect(trip.id, equals('trip-1'));
      expect(trip.title, equals('Alpine Trekking'));
      expect(trip.transportMode, equals(TripTransport.train));
      expect(trip.tripPurpose, equals(TripPurpose.adventure));
      expect(trip.budgetTier, equals(TripBudgetTier.moderate));
      expect(trip.visibility, equals(TripVisibility.visibleForMatching));
      expect(trip.status, equals(TripStatus.published));
      expect(trip.durationDays, equals(11));
      expect(trip.durationLabel, equals('11 days'));
      expect(trip.isPublished, isTrue);
      expect(trip.isDraft, isFalse);
    });

    test('Trip duration calculations work as expected', () {
      final singleDayTrip = Trip(
        id: 'single-day',
        userId: 'user-1',
        origin: 'Tokyo',
        destination: 'Kamakura',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 1),
      );
      expect(singleDayTrip.durationDays, equals(1));
      expect(singleDayTrip.durationLabel, equals('1 day'));

      final multiDayTrip = Trip(
        id: 'multi-day',
        userId: 'user-1',
        origin: 'Tokyo',
        destination: 'Kyoto',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 7),
      );
      expect(multiDayTrip.durationDays, equals(7));
      expect(multiDayTrip.durationLabel, equals('7 days'));
    });


    test('Trip.withCoordinates generates geohashes automatically', () {
      final trip = Trip.withCoordinates(
        id: 'trip-coords',
        userId: 'user-1',
        title: 'Kyoto Cultural Trip',
        origin: 'Tokyo',
        destination: 'Kyoto',
        originLat: 35.6762,
        originLon: 139.6503,
        destLat: 35.0116,
        destLon: 135.7681,
        startDate: start,
        endDate: end,
      );

      expect(trip.originGeohash, isNotNull);
      expect(trip.destinationGeohash, isNotNull);
      expect(trip.originGeohash!.length, equals(6));
      expect(trip.destinationGeohash!.length, equals(6));
    });

    test('Trip serialization and deserialization is symmetric', () {
      final trip = Trip(
        id: 'trip-serial',
        userId: 'user-2',
        title: 'Road Trip Norway',
        origin: 'Oslo',
        destination: 'Bergen',
        originCountry: 'Norway',
        destinationCountry: 'Norway',
        originGeohash: 'u4xsuy',
        destinationGeohash: 'u4eyfs',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 7, 10),
        transportMode: TripTransport.car,
        tripPurpose: TripPurpose.adventure,
        budgetTier: TripBudgetTier.comfortable,
        visibility: TripVisibility.private,
        status: TripStatus.draft,
        maxCompanions: 2,
        tripStyles: const ['road_trip', 'nature'],
      );

      final json = trip.toJson();
      final fromJson = Trip.fromJson(json);

      expect(fromJson.id, equals(trip.id));
      expect(fromJson.userId, equals(trip.userId));
      expect(fromJson.title, equals(trip.title));
      expect(fromJson.origin, equals(trip.origin));
      expect(fromJson.destination, equals(trip.destination));
      expect(fromJson.originCountry, equals(trip.originCountry));
      expect(fromJson.destinationCountry, equals(trip.destinationCountry));
      expect(fromJson.originGeohash, equals(trip.originGeohash));
      expect(fromJson.destinationGeohash, equals(trip.destinationGeohash));
      expect(fromJson.transportMode, equals(TripTransport.car));
      expect(fromJson.tripPurpose, equals(TripPurpose.adventure));
      expect(fromJson.budgetTier, equals(TripBudgetTier.comfortable));
      expect(fromJson.visibility, equals(TripVisibility.private));
      expect(fromJson.status, equals(TripStatus.draft));
      expect(fromJson.maxCompanions, equals(2));
      expect(fromJson.tripStyles, equals(['road_trip', 'nature']));
    });

    test('Trip validation succeeds for valid draft and fails on publishing violations', () {
      final incompleteDraft = Trip(
        id: 'draft-1',
        userId: 'user-1',
        origin: '',
        destination: '',
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2026, 12, 5),
        status: TripStatus.draft,
      );

      // Draft validation should fail if origin or destination empty
      final draftErrors = incompleteDraft.validate(isPublishing: false);
      expect(draftErrors, contains('Starting point (origin) is required.'));
      expect(draftErrors, contains('Destination is required.'));

      // In the past check
      final pastTrip = Trip(
        id: 'past-1',
        userId: 'user-1',
        origin: 'London',
        destination: 'Paris',
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2020, 1, 5),
        status: TripStatus.draft,
      );
      final publishErrors = pastTrip.validate(isPublishing: true);
      expect(publishErrors, contains('Cannot publish a journey that has already concluded in the past.'));
    });


    test('Trip validation catches invalid date ordering and companion range', () {
      final invalidDatesTrip = Trip(
        id: 'invalid-dates',
        userId: 'user-1',
        origin: 'Paris',
        destination: 'Nice',
        startDate: DateTime(2026, 9, 20),
        endDate: DateTime(2026, 9, 10),
        maxCompanions: 15,
      );

      final errors = invalidDatesTrip.validate(isPublishing: false);
      expect(errors, contains('Return date cannot be earlier than departure date.'));
      expect(errors, contains('Maximum companions must be between 1 and 10.'));
    });

    test('Trip validation catches excessive duration exceeding 365 days', () {
      final excessiveTrip = Trip(
        id: 'long-trip',
        userId: 'user-1',
        origin: 'Berlin',
        destination: 'Munich',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2027, 3, 1), // > 365 days
      );

      final errors = excessiveTrip.validate(isPublishing: false);
      expect(errors, contains('Trip duration cannot exceed 365 days.'));
    });
  });
}
