import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/sync/sync_engine.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_purpose.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';

void main() {
  sqfliteFfiInit();

  late LocalDatabaseService localDb;
  late SyncEngine syncEngine;

  setUp(() async {
    localDb = LocalDatabaseService();
    await localDb.initialize(
      databaseFactory: databaseFactoryFfi,
      dbName: 'sync_user_scope_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    syncEngine = SyncEngine(localDb: localDb);
  });

  tearDown(() async {
    syncEngine.dispose();
    await localDb.close();
  });

  group('Phase 12.3 User-Scoped Sync & Account Switch Tests (12.3.8 & 12.3.25)', () {
    test('User A pending operations are never processed when operating as User B', () async {
      final processedUsers = <String>[];
      syncEngine.registerHandler('trip', (record) async {
        processedUsers.add(record.userId);
      });

      // Enqueue operation for User A
      await syncEngine.enqueue(
        userId: 'user_A',
        entityType: 'trip',
        entityId: 'trip_A_1',
        action: 'create',
        payload: {'id': 'trip_A_1', 'user_id': 'user_A', 'destination': 'Kyoto'},
      );

      // Enqueue operation for User B
      await syncEngine.enqueue(
        userId: 'user_B',
        entityType: 'trip',
        entityId: 'trip_B_1',
        action: 'create',
        payload: {'id': 'trip_B_1', 'user_id': 'user_B', 'destination': 'Osaka'},
      );

      // Process only for User B
      final countB = await syncEngine.processPendingQueue('user_B', isOnline: true);
      expect(countB, equals(1));
      expect(processedUsers, equals(['user_B']));

      // User A's queue item must still be pending in database
      final pendingA = await localDb.getPendingSyncRecords('user_A');
      expect(pendingA.length, equals(1));
      expect(pendingA.first.userId, equals('user_A'));
    });

    test('Account switch purges old user cache and resets sync engine safely', () async {
      // Seed User A cached trip
      final tripA = Trip(
        id: 'trip_alice',
        userId: 'user_alice',
        destination: 'Fukuoka',
        origin: 'Tokyo',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)),
        tripPurpose: TripPurpose.vacation,
        budgetTier: TripBudgetTier.budget,
        status: TripStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await localDb.saveTrip(tripA);

      // Verify User A trip exists
      final cachedA = await localDb.getTrip('trip_alice');
      expect(cachedA, isNotNull);

      // Switch account from user_alice to user_bob
      await syncEngine.onAccountSwitched(
        oldUserId: 'user_alice',
        newUserId: 'user_bob',
      );

      // Verify User A cached data was completely purged
      final checkA = await localDb.getTrip('trip_alice');
      expect(checkA, isNull, reason: 'Old user cache must be purged on account switch');

      // User B operations can now proceed cleanly
      bool bobExecuted = false;
      syncEngine.registerHandler('trip', (record) async {
        if (record.userId == 'user_bob') bobExecuted = true;
      });

      await syncEngine.enqueue(
        userId: 'user_bob',
        entityType: 'trip',
        entityId: 'trip_bob_1',
        action: 'create',
        payload: {'id': 'trip_bob_1', 'user_id': 'user_bob', 'destination': 'Nagoya'},
      );

      final countBob = await syncEngine.processPendingQueue('user_bob', isOnline: true);
      expect(countBob, equals(1));
      expect(bobExecuted, isTrue);
    });
  });
}
