import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/sync/sync_engine.dart';
import 'package:safemate/features/trips/data/repositories/offline_first_trip_repository.dart';
import 'package:safemate/features/trips/data/repositories/supabase_trip_repository.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_purpose.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';

void main() {
  sqfliteFfiInit();

  late LocalDatabaseService localDb;
  late SyncEngine syncEngine;
  late SupabaseTripRepository remoteRepo;

  setUp(() async {
    localDb = LocalDatabaseService();
    await localDb.initialize(
      databaseFactory: databaseFactoryFfi,
      dbName: 'sync_conflict_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    syncEngine = SyncEngine(localDb: localDb);
    remoteRepo = SupabaseTripRepository();
    OfflineFirstTripRepository(
      remoteRepo: remoteRepo,
      localDb: localDb,
      syncEngine: syncEngine,
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await localDb.close();
  });

  group('Phase 12.3 Sync Conflict Detection Tests (12.3.11)', () {
    test('Server 409 conflict marks operation as conflict in queue', () async {
      syncEngine.registerHandler('trip', (record) async {
        throw StateError('409 Conflict: Concurrent modification detected on server');
      });

      final opId = await syncEngine.enqueue(
        userId: 'user_conf',
        entityType: 'trip',
        entityId: 'trip_conf_1',
        action: 'update',
        payload: {'id': 'trip_conf_1', 'user_id': 'user_conf', 'destination': 'Sapporo'},
      );

      final count = await syncEngine.processPendingQueue('user_conf', isOnline: true);
      expect(count, equals(0));

      final records = await localDb.getAllSyncRecords('user_conf');
      expect(records.length, equals(1));
      expect(records.first.operationId, equals(opId));
      expect(records.first.status, equals('conflict'));
      expect(records.first.errorMessage, contains('State conflict'));
    });

    test('OfflineTripRepository detects divergence when server version is newer than local base', () async {
      final baseDate = DateTime(2020, 1, 1);
      final serverTrip = Trip(
        id: 'trip_div_1',
        userId: 'user_div',
        destination: 'Sapporo',
        origin: 'Tokyo',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 5),
        tripPurpose: TripPurpose.vacation,
        budgetTier: TripBudgetTier.moderate,
        status: TripStatus.published,
        createdAt: baseDate,
        updatedAt: DateTime.now(), // Server updated later
      );

      // Save initial server trip to remote
      await remoteRepo.createTrip(serverTrip);

      // Now prepare a stale local edit with older updatedAt
      final staleLocalTrip = serverTrip.copyWith(
        destination: 'Otaru',
        updatedAt: baseDate, // Older base timestamp
      );

      // Queue an update with stale timestamp
      await syncEngine.enqueue(
        userId: 'user_div',
        entityType: 'trip',
        entityId: staleLocalTrip.id,
        action: 'update',
        payload: staleLocalTrip.toJson(),
      );

      // SyncEngine runs the registered trip mutation handler
      await syncEngine.processPendingQueue('user_div', isOnline: true);

      // Operation should be marked as conflict because server updatedAt was newer
      final records = await localDb.getAllSyncRecords('user_div');
      expect(records.first.status, equals('conflict'));
      expect(records.first.errorMessage, contains('Trip conflict'));
    });
  });
}
