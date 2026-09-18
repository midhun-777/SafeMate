import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/network/connectivity_service.dart';
import 'package:safemate/core/sync/sync_engine.dart';

void main() {
  sqfliteFfiInit();

  late String dbName;
  late LocalDatabaseService localDb;
  late DefaultConnectivityService connectivity;
  late SyncEngine syncEngine;

  setUp(() async {
    dbName = 'network_chaos_test_${DateTime.now().microsecondsSinceEpoch}.db';
    localDb = LocalDatabaseService();
    await localDb.initialize(
      databaseFactory: databaseFactoryFfi,
      dbName: dbName,
    );
    connectivity = DefaultConnectivityService(
      lookupHost: 'localhost',
      autoStartHeartbeat: false,
    );
    syncEngine = SyncEngine(localDb: localDb, connectivity: connectivity);
  });

  tearDown(() async {
    syncEngine.dispose();
    connectivity.dispose();
    await localDb.close();
  });

  group('Phase 12.3 Network Chaos & Restart Resilience Tests (12.3.26 & 12.3.27)', () {
    test('Simulated network loss pauses sync; reconnection safely resumes without duplicate mutations', () async {
      int serverSyncCalls = 0;
      syncEngine.registerHandler('trip', (record) async {
        serverSyncCalls++;
      });

      // 1. Enqueue operation while device is online
      await syncEngine.enqueue(
        userId: 'user_chaos',
        entityType: 'trip',
        entityId: 'trip_chaos_1',
        action: 'create',
        payload: {'destination': 'Hiroshima'},
      );

      // 2. Network drops: connectivity transitions to offline
      connectivity.setManualStatus(ConnectivityStatus.offline);
      await Future.delayed(const Duration(milliseconds: 30));
      expect(syncEngine.status, equals(SyncEngineStatus.offline));

      // Attempt to sync while offline -> must reject execution
      final offlineCount = await syncEngine.processPendingQueue('user_chaos');
      expect(offlineCount, equals(0));
      expect(serverSyncCalls, equals(0));

      // 3. Network returns: connectivity transitions to online
      connectivity.setManualStatus(ConnectivityStatus.online);
      await Future.delayed(const Duration(milliseconds: 30));
      expect(syncEngine.status, equals(SyncEngineStatus.idle));

      // Resume sync processing
      final onlineCount = await syncEngine.processPendingQueue('user_chaos');
      expect(onlineCount, equals(1));
      expect(serverSyncCalls, equals(1));

      // Queue is empty
      final pending = await localDb.getPendingSyncRecords('user_chaos');
      expect(pending, isEmpty);
    });

    test('Database restart retains pending sync queue and resumes cleanly', () async {
      // 1. Enqueue operations
      final opId1 = await syncEngine.enqueue(
        userId: 'user_persist',
        entityType: 'trip',
        entityId: 'trip_p1',
        action: 'create',
        payload: {'destination': 'Sendai'},
      );
      final opId2 = await syncEngine.enqueue(
        userId: 'user_persist',
        entityType: 'trip',
        entityId: 'trip_p2',
        action: 'create',
        payload: {'destination': 'Morioka'},
      );

      // 2. Simulate application kill / database restart
      syncEngine.dispose();
      await localDb.close();

      // 3. Re-open database instance
      final restartedDb = LocalDatabaseService();
      await restartedDb.initialize(
        databaseFactory: databaseFactoryFfi,
        dbName: dbName,
      );

      // Verify pending operations persisted on disk
      final persistedRecords = await restartedDb.getPendingSyncRecords('user_persist');
      expect(persistedRecords.length, equals(2));
      expect(persistedRecords.map((r) => r.operationId), containsAll([opId1, opId2]));

      // 4. Resume sync engine with restarted database
      final restartedEngine = SyncEngine(localDb: restartedDb);
      final syncedIds = <String>[];
      restartedEngine.registerHandler('trip', (record) async {
        syncedIds.add(record.operationId);
      });

      final processed = await restartedEngine.processPendingQueue('user_persist', isOnline: true);
      expect(processed, equals(2));
      expect(syncedIds, containsAll([opId1, opId2]));

      final remaining = await restartedDb.getPendingSyncRecords('user_persist');
      expect(remaining, isEmpty);

      restartedEngine.dispose();
      await restartedDb.close();
    });
  });
}
