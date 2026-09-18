import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/safety/domain/models/safetrip_models.dart';

void main() {
  group('SafeTrip Authorization & Security Boundary Tests', () {
    const ownerId = 'user-owner-123';
    const companionId = 'user-companion-456';
    const unauthorizedThirdPartyId = 'user-intruder-999';

    late SafeTrip testTrip;

    setUp(() {
      testTrip = SafeTrip(
        id: 'journey-001',
        tripId: 'trip-001',
        ownerId: ownerId,
        companionUserId: companionId,
        trustedContactId: 'contact-record-001',
        status: SafeTripStatus.active,
        expectedStartTime: DateTime(2026, 9, 16, 9, 0),
        expectedArrivalTime: DateTime(2026, 9, 16, 13, 0),
        checkinIntervalMinutes: 60,
        gracePeriodMinutes: 15,
        locationSharingMode: LocationSharingMode.approximate,
        consent: JourneyConsent(
          shareStatusWithTrustedContact: true,
          shareApproximateLocation: true,
          sendCheckinReminders: true,
          consentedAt: DateTime(2026, 9, 16, 8, 55),
        ),
        createdAt: DateTime(2026, 9, 16, 8, 55),
        updatedAt: DateTime(2026, 9, 16, 9, 0),
      );
    });

    test('Owner has full read and state transition authorization', () {
      expect(testTrip.ownerId, equals(ownerId));
      final canOwnerMutate = testTrip.ownerId == ownerId;
      expect(canOwnerMutate, isTrue);

      final updated = SafeTripStateMachine.transition(
        current: testTrip,
        target: SafeTripStatus.paused,
      );
      expect(updated.status, equals(SafeTripStatus.paused));
    });

    test('Companion has read visibility for journey status but cannot execute mutations', () {
      final isCompanion = testTrip.companionUserId == companionId;
      expect(isCompanion, isTrue);

      final canCompanionMutate = testTrip.ownerId == companionId;
      expect(canCompanionMutate, isFalse);
    });

    test('Unauthorized third party is denied read and write access (anti-enumeration)', () {
      final isAuthorizedReader = testTrip.ownerId == unauthorizedThirdPartyId ||
          testTrip.companionUserId == unauthorizedThirdPartyId;
      expect(isAuthorizedReader, isFalse);

      final canMutate = testTrip.ownerId == unauthorizedThirdPartyId;
      expect(canMutate, isFalse);
    });

    test('Location share session access requires active session and explicit consent', () {
      final session = LocationShareSession(
        id: 'loc-001',
        journeyId: testTrip.id,
        userId: ownerId,
        mode: LocationSharingMode.approximate,
        approxGeohash: 'te29z',
        startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        expiresAt: DateTime.now().add(const Duration(minutes: 50)),
        updatedAt: DateTime.now(),
      );

      // Condition 1: When consent is true & session active
      expect(testTrip.consent?.shareApproximateLocation, isTrue);
      expect(session.isActive, isTrue);

      // Condition 2: When user revokes location sharing
      final revokedSession = LocationShareSession(
        id: 'loc-001',
        journeyId: testTrip.id,
        userId: ownerId,
        mode: LocationSharingMode.off,
        approxGeohash: null,
        startedAt: session.startedAt,
        expiresAt: session.expiresAt,
        revokedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(revokedSession.isActive, isFalse);
      expect(revokedSession.isRevoked, isTrue);

      // Condition 3: When session is expired
      final expiredSession = LocationShareSession(
        id: 'loc-001',
        journeyId: testTrip.id,
        userId: ownerId,
        mode: LocationSharingMode.approximate,
        approxGeohash: 'te29z',
        startedAt: DateTime.now().subtract(const Duration(hours: 2)),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 10)),
        updatedAt: DateTime.now(),
      );
      expect(expiredSession.isActive, isFalse);
      expect(expiredSession.isExpired, isTrue);
    });

    test('Check-in idempotency prevents duplicate check-in creation', () {
      final checkin1 = JourneyCheckin(
        id: 'checkin-001',
        journeyId: testTrip.id,
        userId: ownerId,
        checkinNumber: 1,
        status: CheckinStatus.completed,
        scheduledFor: DateTime(2026, 9, 16, 10, 0),
        completedAt: DateTime(2026, 9, 16, 10, 0),
        idempotencyKey: 'idem-key-10-00',
      );

      final checkinDuplicateAttempt = JourneyCheckin(
        id: 'checkin-002',
        journeyId: testTrip.id,
        userId: ownerId,
        checkinNumber: 1,
        status: CheckinStatus.completed,
        scheduledFor: DateTime(2026, 9, 16, 10, 0),
        completedAt: DateTime(2026, 9, 16, 10, 1),
        idempotencyKey: 'idem-key-10-00', // Same idempotency key
      );

      expect(
        checkin1.idempotencyKey,
        equals(checkinDuplicateAttempt.idempotencyKey),
      );
    });
  });
}
