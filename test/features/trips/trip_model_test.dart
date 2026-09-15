import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';

void main() {
  group('Trip Model Tests', () {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 10);
    final end = DateTime(now.year, now.month, 20);

    test('Trip instantiates correctly with valid parameters', () {
      final trip = Trip(
        id: 'trip-1',
        userId: 'user-1',
        title: 'Alpine Trekking',
        origin: 'Geneva',
        destination: 'Zermatt',
        startDate: start,
        endDate: end,
        estimatedBudget: 800.0,
        currency: 'CHF',
        transportMode: 'train',
        tripPurpose: 'adventure',
      );

      expect(trip.id, equals('trip-1'));
      expect(trip.title, equals('Alpine Trekking'));
      expect(trip.transportMode, equals('train'));
      expect(trip.estimatedBudget, equals(800.0));
      expect(trip.status, equals('planned'));
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
        originGeohash: 'u4xsuy',
        destinationGeohash: 'u4eyfs',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 7, 10),
        estimatedBudget: 1200.0,
        currency: 'EUR',
        transportMode: 'road_trip',
        tripPurpose: 'adventure',
        status: 'planned',
        maxCompanions: 2,
      );

      final json = trip.toJson();
      final fromJson = Trip.fromJson(json);

      expect(fromJson.id, equals(trip.id));
      expect(fromJson.userId, equals(trip.userId));
      expect(fromJson.title, equals(trip.title));
      expect(fromJson.origin, equals(trip.origin));
      expect(fromJson.destination, equals(trip.destination));
      expect(fromJson.originGeohash, equals(trip.originGeohash));
      expect(fromJson.destinationGeohash, equals(trip.destinationGeohash));
      expect(fromJson.transportMode, equals(trip.transportMode));
      expect(fromJson.tripPurpose, equals(trip.tripPurpose));
      expect(fromJson.maxCompanions, equals(trip.maxCompanions));
    });

    test('Trip throws AssertionError when endDate precedes startDate', () {
      expect(
        () => Trip(
          id: 'invalid-trip',
          userId: 'user-1',
          title: 'Time Travel',
          origin: 'London',
          destination: 'Edinburgh',
          startDate: DateTime(2026, 8, 15),
          endDate: DateTime(2026, 8, 10),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
