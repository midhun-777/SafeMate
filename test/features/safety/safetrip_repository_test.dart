import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/safety/data/repositories/supabase_safetrip_repository.dart';
import 'package:safemate/features/safety/domain/models/safetrip_models.dart';

void main() {
  group('SupabaseSafeTripRepository Tests', () {
    late SupabaseSafeTripRepository repository;
    final now = DateTime(2026, 9, 16, 9, 0);

    setUp(() {
      repository = SupabaseSafeTripRepository();
    });

    test('Prepares and retrieves SafeTrip by tripId and journeyId', () async {
      final trip = SafeTrip(
        id: 'journey-101',
        tripId: 'trip-202',
        ownerId: 'user-alice',
        status: SafeTripStatus.preparing,
        expectedStartTime: now,
        expectedArrivalTime: now.add(const Duration(hours: 4)),
        checkinIntervalMinutes: 45,
        gracePeriodMinutes: 15,
        createdAt: now,
        updatedAt: now,
      );

      final prepared = await repository.prepareSafeTrip(trip);
      expect(prepared.status, equals(SafeTripStatus.preparing));

      final byTrip = await repository.getSafeTripByTripId('trip-202');
      expect(byTrip, isNotNull);
      expect(byTrip!.id, equals('journey-101'));

      final byId = await repository.getSafeTripById('journey-101');
      expect(byId, isNotNull);
      expect(byId!.ownerId, equals('user-alice'));
    });

    test('Activates SafeTrip idempotently and auto-schedules first check-in', () async {
      final trip = SafeTrip(
        id: 'journey-102',
        tripId: 'trip-203',
        ownerId: 'user-alice',
        status: SafeTripStatus.ready,
        expectedStartTime: now,
        expectedArrivalTime: now.add(const Duration(hours: 4)),
        checkinIntervalMinutes: 30,
        createdAt: now,
        updatedAt: now,
      );
      await repository.prepareSafeTrip(trip);

      final consent = JourneyConsent(
        shareStatusWithTrustedContact: true,
        shareApproximateLocation: true,
        sendCheckinReminders: true,
        consentedAt: now,
      );

      final activated = await repository.activateSafeTrip(
        journeyId: 'journey-102',
        idempotencyKey: 'act-key-001',
        consent: consent,
      );

      expect(activated.status, equals(SafeTripStatus.active));
      expect(activated.consent?.shareApproximateLocation, isTrue);
      expect(activated.nextCheckinDeadline, isNotNull);

      // Check scheduled check-in was auto-created
      final checkins = await repository.getCheckins('journey-102');
      expect(checkins.length, equals(1));
      expect(checkins.first.status, equals(CheckinStatus.scheduled));

      // Duplicate activation returns existing active trip without creating new check-ins
      final duplicateActivation = await repository.activateSafeTrip(
        journeyId: 'journey-102',
        idempotencyKey: 'act-key-001',
        consent: consent,
      );
      expect(duplicateActivation.status, equals(SafeTripStatus.active));
      final checkinsAfter = await repository.getCheckins('journey-102');
      expect(checkinsAfter.length, equals(1));
    });

    test('Records check-in (I am OK) with idempotency and next deadline calculation', () async {
      final trip = SafeTrip(
        id: 'journey-103',
        tripId: 'trip-204',
        ownerId: 'user-alice',
        status: SafeTripStatus.ready,
        expectedStartTime: now,
        expectedArrivalTime: now.add(const Duration(hours: 5)),
        checkinIntervalMinutes: 60,
        createdAt: now,
        updatedAt: now,
      );
      await repository.prepareSafeTrip(trip);
      await repository.activateSafeTrip(
        journeyId: 'journey-103',
        idempotencyKey: 'act-103',
        consent: JourneyConsent(
          shareStatusWithTrustedContact: false,
          shareApproximateLocation: false,
          sendCheckinReminders: true,
          consentedAt: now,
        ),
      );

      final checkin1 = await repository.recordCheckin(
        journeyId: 'journey-103',
        userId: 'user-alice',
        idempotencyKey: 'chk-key-001',
        notes: 'Smooth ride',
      );

      expect(checkin1.status, equals(CheckinStatus.completed));
      expect(checkin1.notes, equals('Smooth ride'));

      // Check that SafeTrip has updated lastCheckinAt and nextCheckinDeadline
      final updatedTrip = await repository.getSafeTripById('journey-103');
      expect(updatedTrip?.lastCheckinAt, isNotNull);
      expect(updatedTrip?.nextCheckinDeadline, isNotNull);

      // Duplicate check-in with same key returns existing record
      final duplicateCheckin = await repository.recordCheckin(
        journeyId: 'journey-103',
        userId: 'user-alice',
        idempotencyKey: 'chk-key-001',
      );
      expect(duplicateCheckin.id, equals(checkin1.id));
    });

    test('Confirm arrival stops location sharing and transitions to completed', () async {
      final trip = SafeTrip(
        id: 'journey-104',
        tripId: 'trip-205',
        ownerId: 'user-alice',
        status: SafeTripStatus.ready,
        expectedStartTime: now,
        expectedArrivalTime: now.add(const Duration(hours: 3)),
        createdAt: now,
        updatedAt: now,
      );
      await repository.prepareSafeTrip(trip);
      await repository.activateSafeTrip(
        journeyId: 'journey-104',
        idempotencyKey: 'act-104',
        consent: JourneyConsent(
          shareStatusWithTrustedContact: true,
          shareApproximateLocation: true,
          sendCheckinReminders: true,
          consentedAt: now,
        ),
      );

      // Start location sharing session
      await repository.startLocationSharing(
        journeyId: 'journey-104',
        userId: 'user-alice',
        mode: LocationSharingMode.approximate,
        duration: const Duration(hours: 2),
        approxGeohash: 'tf32a',
      );

      var activeLoc = await repository.getActiveLocationSession('journey-104');
      expect(activeLoc, isNotNull);
      expect(activeLoc!.isActive, isTrue);

      // Confirm arrival
      final arrived = await repository.confirmArrival(
        journeyId: 'journey-104',
        idempotencyKey: 'arr-104',
      );
      expect(arrived.status, equals(SafeTripStatus.arrived));
      expect(arrived.actualArrivalTime, isNotNull);

      // Location sharing must be stopped
      activeLoc = await repository.getActiveLocationSession('journey-104');
      expect(activeLoc, isNull);

      // Complete SafeTrip
      final completed = await repository.completeSafeTrip(
        journeyId: 'journey-104',
        idempotencyKey: 'comp-104',
      );
      expect(completed.status, equals(SafeTripStatus.completed));
      expect(completed.completedAt, isNotNull);

      // Audit trail check
      final events = await repository.getJourneyEvents('journey-104');
      final eventTypes = events.map((e) => e['event_type']).toList();
      expect(eventTypes, contains('journey_activated'));
      expect(eventTypes, contains('arrival_confirmed'));
      expect(eventTypes, contains('journey_completed'));
    });
  });
}
