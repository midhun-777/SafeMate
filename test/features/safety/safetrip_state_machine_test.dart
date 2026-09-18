import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/safety/domain/models/safetrip_models.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip_purpose.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';
import 'package:safemate/features/trips/domain/models/trip_transport.dart';
import 'package:safemate/features/trips/domain/models/trip_visibility.dart';

void main() {
  group('SafeTripStatus Transitions', () {
    test('PREPARING can only transition to READY or CANCELLED', () {
      expect(SafeTripStatus.preparing.canTransitionTo(SafeTripStatus.ready), isTrue);
      expect(SafeTripStatus.preparing.canTransitionTo(SafeTripStatus.cancelled), isTrue);
      expect(SafeTripStatus.preparing.canTransitionTo(SafeTripStatus.active), isFalse);
      expect(SafeTripStatus.preparing.canTransitionTo(SafeTripStatus.arrived), isFalse);
      expect(SafeTripStatus.preparing.canTransitionTo(SafeTripStatus.completed), isFalse);
    });

    test('READY can only transition to ACTIVE or CANCELLED', () {
      expect(SafeTripStatus.ready.canTransitionTo(SafeTripStatus.active), isTrue);
      expect(SafeTripStatus.ready.canTransitionTo(SafeTripStatus.cancelled), isTrue);
      expect(SafeTripStatus.ready.canTransitionTo(SafeTripStatus.arrived), isFalse);
      expect(SafeTripStatus.ready.canTransitionTo(SafeTripStatus.completed), isFalse);
    });

    test('ACTIVE can transition to PAUSED, ARRIVED, CANCELLED, EXPIRED', () {
      expect(SafeTripStatus.active.canTransitionTo(SafeTripStatus.paused), isTrue);
      expect(SafeTripStatus.active.canTransitionTo(SafeTripStatus.arrived), isTrue);
      expect(SafeTripStatus.active.canTransitionTo(SafeTripStatus.cancelled), isTrue);
      expect(SafeTripStatus.active.canTransitionTo(SafeTripStatus.expired), isTrue);
      expect(SafeTripStatus.active.canTransitionTo(SafeTripStatus.completed), isFalse);
      expect(SafeTripStatus.active.canTransitionTo(SafeTripStatus.ready), isFalse);
    });

    test('PAUSED can transition to ACTIVE, CANCELLED, EXPIRED', () {
      expect(SafeTripStatus.paused.canTransitionTo(SafeTripStatus.active), isTrue);
      expect(SafeTripStatus.paused.canTransitionTo(SafeTripStatus.cancelled), isTrue);
      expect(SafeTripStatus.paused.canTransitionTo(SafeTripStatus.expired), isTrue);
      expect(SafeTripStatus.paused.canTransitionTo(SafeTripStatus.arrived), isFalse);
    });

    test('ARRIVED can transition to COMPLETED or CANCELLED', () {
      expect(SafeTripStatus.arrived.canTransitionTo(SafeTripStatus.completed), isTrue);
      expect(SafeTripStatus.arrived.canTransitionTo(SafeTripStatus.cancelled), isTrue);
      expect(SafeTripStatus.arrived.canTransitionTo(SafeTripStatus.active), isFalse);
    });

    test('Terminal states (COMPLETED, CANCELLED, EXPIRED) cannot transition anywhere', () {
      for (final terminal in [
        SafeTripStatus.completed,
        SafeTripStatus.cancelled,
        SafeTripStatus.expired,
      ]) {
        for (final target in SafeTripStatus.values) {
          expect(terminal.canTransitionTo(target), isFalse);
        }
      }
    });

    test('Self-transition is always false', () {
      for (final status in SafeTripStatus.values) {
        expect(status.canTransitionTo(status), isFalse);
      }
    });
  });

  group('SafeTripStateMachine Domain Logic', () {
    late SafeTrip baseTrip;
    final now = DateTime(2026, 9, 16, 10, 0);

    setUp(() {
      baseTrip = SafeTrip(
        id: 'journey-001',
        tripId: 'trip-001',
        ownerId: 'user-001',
        status: SafeTripStatus.preparing,
        expectedStartTime: now,
        expectedArrivalTime: now.add(const Duration(hours: 4)),
        checkinIntervalMinutes: 60,
        gracePeriodMinutes: 15,
        locationSharingMode: LocationSharingMode.off,
        createdAt: now,
        updatedAt: now,
      );
    });

    test('Transitions from PREPARING to READY to ACTIVE correctly', () {
      final readyTrip = SafeTripStateMachine.transition(
        current: baseTrip,
        target: SafeTripStatus.ready,
        timestamp: now,
      );
      expect(readyTrip.status, equals(SafeTripStatus.ready));

      final activeTrip = SafeTripStateMachine.transition(
        current: readyTrip,
        target: SafeTripStatus.active,
        timestamp: now,
      );
      expect(activeTrip.status, equals(SafeTripStatus.active));
      expect(activeTrip.lastCheckinAt, equals(now));
      expect(
        activeTrip.nextCheckinDeadline,
        equals(now.add(const Duration(minutes: 60))),
      );
    });

    test('Transitions from ACTIVE to ARRIVED stops location sharing and sets arrival time', () {
      final activeTrip = baseTrip.copyWith(
        status: SafeTripStatus.active,
        locationSharingMode: LocationSharingMode.approximate,
      );

      final arrivalTime = now.add(const Duration(hours: 3, minutes: 45));
      final arrivedTrip = SafeTripStateMachine.transition(
        current: activeTrip,
        target: SafeTripStatus.arrived,
        timestamp: arrivalTime,
      );

      expect(arrivedTrip.status, equals(SafeTripStatus.arrived));
      expect(arrivedTrip.actualArrivalTime, equals(arrivalTime));
      expect(arrivedTrip.locationSharingMode, equals(LocationSharingMode.off));
    });

    test('Transitions from ARRIVED to COMPLETED sets completedAt timestamp', () {
      final arrivedTrip = baseTrip.copyWith(
        status: SafeTripStatus.arrived,
        actualArrivalTime: now.add(const Duration(hours: 3, minutes: 45)),
      );

      final completionTime = now.add(const Duration(hours: 4));
      final completedTrip = SafeTripStateMachine.transition(
        current: arrivedTrip,
        target: SafeTripStatus.completed,
        timestamp: completionTime,
      );

      expect(completedTrip.status, equals(SafeTripStatus.completed));
      expect(completedTrip.completedAt, equals(completionTime));
    });

    test('Illegal transition throws StateError', () {
      expect(
        () => SafeTripStateMachine.transition(
          current: baseTrip, // status: PREPARING
          target: SafeTripStatus.completed,
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        () => SafeTripStateMachine.transition(
          current: baseTrip, // status: PREPARING
          target: SafeTripStatus.active,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Check-in deadline calculation and grace period checks', () {
      final checkinTime = DateTime(2026, 9, 16, 12, 0);
      final nextDeadline = SafeTripStateMachine.calculateNextDeadline(
        lastCheckinTime: checkinTime,
        intervalMinutes: 45,
      );
      expect(nextDeadline, equals(DateTime(2026, 9, 16, 12, 45)));

      // Within deadline
      expect(
        SafeTripStateMachine.isGracePeriodExceeded(
          deadline: nextDeadline,
          gracePeriodMinutes: 15,
          currentTime: DateTime(2026, 9, 16, 12, 40),
        ),
        isFalse,
      );

      // Within grace period (12:45 to 13:00)
      expect(
        SafeTripStateMachine.isGracePeriodExceeded(
          deadline: nextDeadline,
          gracePeriodMinutes: 15,
          currentTime: DateTime(2026, 9, 16, 12, 55),
        ),
        isFalse,
      );

      // Exceeded grace period (after 13:00)
      expect(
        SafeTripStateMachine.isGracePeriodExceeded(
          deadline: nextDeadline,
          gracePeriodMinutes: 15,
          currentTime: DateTime(2026, 9, 16, 13, 05),
        ),
        isTrue,
      );
    });

    test('Auto-expiry calculation handles safety buffer', () {
      final trip = baseTrip.copyWith(
        expectedArrivalTime: DateTime(2026, 9, 16, 16, 0),
        gracePeriodMinutes: 15,
      );

      // Auto expiry should be 16:00 + (15 * 2) = 16:30
      expect(trip.autoExpiryTime, equals(DateTime(2026, 9, 16, 16, 30)));
      expect(
        trip.isPastExpiry(currentTime: DateTime(2026, 9, 16, 16, 15)),
        isFalse,
      );
      expect(
        trip.isPastExpiry(currentTime: DateTime(2026, 9, 16, 16, 35)),
        isTrue,
      );
    });
  });

  group('CheckinStatus Transitions', () {
    test('SCHEDULED can transition to COMPLETED, MISSED, CANCELLED', () {
      expect(CheckinStatus.scheduled.canTransitionTo(CheckinStatus.completed), isTrue);
      expect(CheckinStatus.scheduled.canTransitionTo(CheckinStatus.missed), isTrue);
      expect(CheckinStatus.scheduled.canTransitionTo(CheckinStatus.cancelled), isTrue);
      expect(CheckinStatus.scheduled.canTransitionTo(CheckinStatus.expired), isFalse);
    });

    test('MISSED can transition to COMPLETED (I am OK), EXPIRED, CANCELLED', () {
      expect(CheckinStatus.missed.canTransitionTo(CheckinStatus.completed), isTrue);
      expect(CheckinStatus.missed.canTransitionTo(CheckinStatus.expired), isTrue);
      expect(CheckinStatus.missed.canTransitionTo(CheckinStatus.cancelled), isTrue);
      expect(CheckinStatus.missed.canTransitionTo(CheckinStatus.scheduled), isFalse);
    });

    test('COMPLETED is terminal', () {
      expect(CheckinStatus.completed.canTransitionTo(CheckinStatus.scheduled), isFalse);
      expect(CheckinStatus.completed.canTransitionTo(CheckinStatus.missed), isFalse);
    });
  });

  group('SafeTripEligibility Evaluation', () {
    late Trip validTrip;

    setUp(() {
      validTrip = Trip(
        id: 'trip-100',
        userId: 'user-alice',
        origin: 'Hyderabad',
        destination: 'Vijayawada',
        startDate: DateTime.now().add(const Duration(hours: 1)),
        endDate: DateTime.now().add(const Duration(hours: 6)),
        transportMode: TripTransport.train,
        tripPurpose: TripPurpose.vacation,
        budgetTier: TripBudgetTier.moderate,
        visibility: TripVisibility.visibleForMatching,
        status: TripStatus.published,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    test('Valid published trip by owner is eligible', () {
      final result = SafeTripEligibility.validateTrip(
        trip: validTrip,
        currentUserId: 'user-alice',
      );
      expect(result.isEligible, isTrue);
      expect(result.reason, isNull);
    });

    test('Mismatched user is ineligible', () {
      final result = SafeTripEligibility.validateTrip(
        trip: validTrip,
        currentUserId: 'user-bob',
      );
      expect(result.isEligible, isFalse);
      expect(result.reason, contains('owner'));
    });

    test('Draft or paused trip is ineligible', () {
      final draftTrip = validTrip.copyWith(status: TripStatus.draft);
      final result = SafeTripEligibility.validateTrip(
        trip: draftTrip,
        currentUserId: 'user-alice',
      );
      expect(result.isEligible, isFalse);
      expect(result.reason, contains('published'));
    });

    test('Trip with empty destination is ineligible', () {
      final emptyDestTrip = validTrip.copyWith(destination: '   ');
      final result = SafeTripEligibility.validateTrip(
        trip: emptyDestTrip,
        currentUserId: 'user-alice',
      );
      expect(result.isEligible, isFalse);
      expect(result.reason, contains('destination'));
    });
  });

  group('SafeTrip JSON Serialization Roundtrips', () {
    test('SafeTrip serializes and deserializes accurately', () {
      final original = SafeTrip(
        id: 'safe-001',
        tripId: 'trip-001',
        ownerId: 'user-001',
        companionUserId: 'user-002',
        trustedContactId: 'contact-001',
        status: SafeTripStatus.active,
        expectedStartTime: DateTime(2026, 9, 16, 8, 0),
        expectedArrivalTime: DateTime(2026, 9, 16, 12, 0),
        checkinIntervalMinutes: 45,
        gracePeriodMinutes: 15,
        locationSharingMode: LocationSharingMode.approximate,
        consent: JourneyConsent(
          shareStatusWithTrustedContact: true,
          shareApproximateLocation: true,
          sendCheckinReminders: true,
          consentedAt: DateTime(2026, 9, 16, 7, 50),
        ),
        createdAt: DateTime(2026, 9, 16, 7, 50),
        updatedAt: DateTime(2026, 9, 16, 8, 0),
      );

      final json = original.toJson();
      final parsed = SafeTrip.fromJson(json);

      expect(parsed.id, equals(original.id));
      expect(parsed.status, equals(SafeTripStatus.active));
      expect(parsed.locationSharingMode, equals(LocationSharingMode.approximate));
      expect(parsed.consent?.shareStatusWithTrustedContact, isTrue);
      expect(parsed.consent?.shareApproximateLocation, isTrue);
    });

    test('LocationShareSession active and expired evaluation', () {
      final session = LocationShareSession(
        id: 'loc-01',
        journeyId: 'safe-01',
        userId: 'user-01',
        mode: LocationSharingMode.approximate,
        approxGeohash: 'tf34b',
        startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        expiresAt: DateTime.now().add(const Duration(minutes: 50)),
        updatedAt: DateTime.now(),
      );

      expect(session.isActive, isTrue);
      expect(session.isExpired, isFalse);
      expect(session.isRevoked, isFalse);
    });
  });
}
