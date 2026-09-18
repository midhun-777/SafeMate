import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/safety/domain/models/safetrip_models.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late LocalDatabaseService dbService;

  setUp(() async {
    dbService = LocalDatabaseService();
    await dbService.init(
      databaseFactory: databaseFactoryFfi,
      dbName: 'isolation_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
  });

  tearDown(() async {
    await dbService.close();
  });

  group('Phase 12.19 & 12.20 Security Red Team — Account Isolation & Logout Purge', () {
    test('User A data is completely purged on logout; User B sees zero leaked records', () async {
      final now = DateTime.now();

      // 1. User Alice populates local SQLite with sensitive personal journey data
      final aliceProfile = UserProfile(
        id: 'user_alice',
        displayName: 'Alice Private',
        bio: 'Solo traveler',
        createdAt: now,
        updatedAt: now,
      );
      await dbService.saveProfile(aliceProfile);

      final aliceTrip = Trip(
        id: 'trip_alice_secret',
        userId: 'user_alice',
        origin: 'Quiet Town',
        destination: 'Private Sanctuary',
        startDate: now,
        endDate: now.add(const Duration(days: 4)),
        status: TripStatus.published,
        createdAt: now,
        updatedAt: now,
      );
      await dbService.saveTrip(aliceTrip);

      final aliceSafeTrip = SafeTrip(
        id: 'safetrip_alice',
        tripId: 'trip_alice_secret',
        ownerId: 'user_alice',
        status: SafeTripStatus.active,
        expectedStartTime: now,
        expectedArrivalTime: now.add(const Duration(hours: 2)),
        createdAt: now,
        updatedAt: now,
      );
      await dbService.saveSafeTrip(aliceSafeTrip);

      final aliceCheckin = JourneyCheckin(
        id: 'checkin_alice',
        journeyId: 'safetrip_alice',
        userId: 'user_alice',
        checkinNumber: 1,
        status: CheckinStatus.completed,
        scheduledFor: now,
        completedAt: now,
      );
      await dbService.saveCheckin(aliceCheckin);

      await dbService.enqueueSyncRecord(SyncRecord(
        operationId: 'op_alice_sync',
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_alice_secret',
        action: 'create',
        payload: {'destination': 'Private Sanctuary'},
        status: 'pending',
        createdAt: now,
      ));

      // Verify Alice data is present
      expect((await dbService.getUserTrips('user_alice')).length, 1);
      expect(await dbService.getProfile('user_alice'), isNotNull);

      // 2. User Alice logs out -> System executes purgeUserData('user_alice')
      await dbService.purgeUserData('user_alice');

      // 3. User Bob logs into the same physical device
      final bobTrips = await dbService.getUserTrips('user_bob');
      expect(bobTrips, isEmpty);

      // Red-Team Attack: Bob attempts to access Alice's records from SQLite
      final leakedAliceTrip = await dbService.getTrip('trip_alice_secret');
      expect(leakedAliceTrip, isNull);

      final leakedAliceProfile = await dbService.getProfile('user_alice');
      expect(leakedAliceProfile, isNull);

      final leakedAliceSafeTrip = await dbService.getSafeTrip('safetrip_alice');
      expect(leakedAliceSafeTrip, isNull);

      final leakedAliceCheckins = await dbService.getJourneyCheckins('safetrip_alice');
      expect(leakedAliceCheckins, isEmpty);

      final leakedAliceSync = await dbService.getPendingSyncRecords('user_alice');
      expect(leakedAliceSync, isEmpty);
    });
  });
}
