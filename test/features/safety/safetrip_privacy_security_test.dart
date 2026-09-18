import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/services/analytics_service.dart';
import 'package:safemate/features/safety/domain/models/safetrip_models.dart';

void main() {
  group('SafeTrip Privacy & Security Guardrails', () {
    test('Location sharing mode defaults strictly to OFF', () {
      final trip = SafeTrip(
        id: 'journey-sec-01',
        tripId: 'trip-01',
        ownerId: 'user-alice',
        status: SafeTripStatus.preparing,
        expectedStartTime: DateTime.now(),
        expectedArrivalTime: DateTime.now().add(const Duration(hours: 4)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(trip.locationSharingMode, equals(LocationSharingMode.off));
      expect(trip.locationSharingExpiresAt, isNull);
    });

    test('Approximate location session stores only coarse geohash, never raw lat/lon', () {
      final session = LocationShareSession(
        id: 'loc-sess-01',
        journeyId: 'journey-sec-01',
        userId: 'user-alice',
        mode: LocationSharingMode.approximate,
        approxGeohash: 'te29z', // ~20km resolution
        startedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
        updatedAt: DateTime.now(),
      );

      final json = session.toJson();
      expect(json.containsKey('latitude'), isFalse);
      expect(json.containsKey('longitude'), isFalse);
      expect(json.containsKey('lat'), isFalse);
      expect(json.containsKey('lon'), isFalse);
      expect(json['mode'], equals('approximate'));
      expect(json['approx_geohash'], equals('te29z'));
    });

    test('Location sharing session is automatically revoked on arrival or completion', () {
      final activeTrip = SafeTrip(
        id: 'journey-sec-02',
        tripId: 'trip-02',
        ownerId: 'user-alice',
        status: SafeTripStatus.active,
        expectedStartTime: DateTime.now(),
        expectedArrivalTime: DateTime.now().add(const Duration(hours: 4)),
        locationSharingMode: LocationSharingMode.approximate,
        locationSharingExpiresAt: DateTime.now().add(const Duration(hours: 2)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Transition to ARRIVED
      final arrivedTrip = SafeTripStateMachine.transition(
        current: activeTrip,
        target: SafeTripStatus.arrived,
        timestamp: DateTime.now(),
      );

      expect(arrivedTrip.locationSharingMode, equals(LocationSharingMode.off));
      expect(arrivedTrip.actualArrivalTime, isNotNull);

      // Transition to CANCELLED also stops location sharing
      final cancelledTrip = SafeTripStateMachine.transition(
        current: activeTrip,
        target: SafeTripStatus.cancelled,
        timestamp: DateTime.now(),
      );
      expect(cancelledTrip.locationSharingMode, equals(LocationSharingMode.off));
    });

    test('Analytics events never contain coordinates or PII parameters', () {
      final allowedParams = <String, dynamic>{
        'journey_id': 'journey-001',
        'sharing_status': true,
        'sharing_loc': false,
        'checkin_number': 1,
      };

      const SafeMateAnalyticsService().logEvent(
        'safetrip_activated',
        parameters: allowedParams,
      );

      for (final forbiddenKey in [
        'latitude',
        'longitude',
        'lat',
        'lon',
        'phone',
        'email',
        'address',
        'emergency_contact',
      ]) {
        expect(allowedParams.containsKey(forbiddenKey), isFalse);
      }
    });

    test('Expired SafeTrip cannot transition to active or arrived', () {
      final expiredTrip = SafeTrip(
        id: 'journey-sec-03',
        tripId: 'trip-03',
        ownerId: 'user-alice',
        status: SafeTripStatus.expired,
        expectedStartTime: DateTime.now().subtract(const Duration(hours: 8)),
        expectedArrivalTime: DateTime.now().subtract(const Duration(hours: 2)),
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      expect(expiredTrip.status.canTransitionTo(SafeTripStatus.active), isFalse);
      expect(expiredTrip.status.canTransitionTo(SafeTripStatus.arrived), isFalse);
      expect(expiredTrip.status.canTransitionTo(SafeTripStatus.ready), isFalse);
      expect(expiredTrip.status.canTransitionTo(SafeTripStatus.completed), isFalse);
    });

    test('Check-in status transitions prevent duplicate "completed" transitions', () {
      const scheduled = CheckinStatus.scheduled;
      expect(scheduled.canTransitionTo(CheckinStatus.completed), isTrue);

      const completed = CheckinStatus.completed;
      expect(completed.canTransitionTo(CheckinStatus.completed), isFalse);
      expect(completed.canTransitionTo(CheckinStatus.missed), isFalse);
    });
  });
}
