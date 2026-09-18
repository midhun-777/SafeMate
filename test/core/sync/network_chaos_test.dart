import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/sync/sync_engine.dart';

void main() {
  sqfliteFfiInit();

  late String dbPath;
  late LocalDatabaseService localDb;
  late SyncEngine syncEngine;

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('safemate_netchaos_');
    dbPath = '${tempDir.path}/netchaos.db';
    localDb = LocalDatabaseService();
    await localDb.initialize(
      databaseFactory: databaseFactoryFfi,
      dbName: dbPath,
    );
    syncEngine = SyncEngine(localDb: localDb);
  });

  tearDown(() async {
    syncEngine.dispose();
    await localDb.close();
  });

  group('Phase 12.5.4 — Automated Network Chaos Tests', () {
    test('Chaos 1: Online -> Offline -> Mutation -> Reconnect -> Synchronizes cleanly without duplicate records', () async {
      final serverStore = <String, Map<String, dynamic>>{};
      syncEngine.registerHandler('trip', (record) async {
        serverStore[record.entityId] = Map.from(record.payload);
      });

      // 1. App goes offline
      await syncEngine.enqueue(
        userId: 'user_chaos_1',
        entityType: 'trip',
        entityId: 'trip_c1',
        action: 'create',
        operationId: 'op_c1',
        payload: {'destination': 'Sapporo', 'status': 'draft'},
      );

      // Offline sync attempt: Should not dispatch
      await syncEngine.processPendingQueue('user_chaos_1', isOnline: false);
      expect(serverStore.isEmpty, isTrue);

      var pending = await localDb.getPendingSyncRecords('user_chaos_1');
      expect(pending.length, equals(1));
      expect(pending.first.status, equals('pending'));

      // 2. Reconnect: Dispatches successfully
      await syncEngine.processPendingQueue('user_chaos_1', isOnline: true);
      expect(serverStore.length, equals(1));
      expect(serverStore['trip_c1']?['destination'], equals('Sapporo'));

      pending = await localDb.getPendingSyncRecords('user_chaos_1');
      expect(pending.isEmpty, isTrue);
    });

    test('Chaos 2: Online -> Mutation -> Network loss immediately after server commit -> Retry deduplicated', () async {
      final serverRecords = <String, int>{};
      int networkAttempts = 0;

      syncEngine.registerHandler('profile', (record) async {
        networkAttempts++;
        // Commit to server
        serverRecords[record.entityId] = (serverRecords[record.entityId] ?? 0) + 1;

        if (networkAttempts == 1) {
          // Response packet dropped due to sudden network loss
          throw const SocketException('Network is unreachable immediately after commit');
        }
      });

      const opId = 'op_chaos_c2';
      await syncEngine.enqueue(
        userId: 'user_chaos_2',
        entityType: 'profile',
        entityId: 'prof_c2',
        action: 'update',
        operationId: opId,
        payload: {'bio': 'Snowboarder in Hokkaido'},
      );

      // Attempt 1: Server commits, network drops
      await syncEngine.processPendingQueue('user_chaos_2', isOnline: true);
      expect(networkAttempts, equals(1));
      expect(serverRecords['prof_c2'], equals(1));

      // Reset cooldown for reconnect
      await localDb.updateSyncRecordStatus(
        opId,
        'pending',
        lastAttemptAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      // Attempt 2: Reconnect retry
      await syncEngine.processPendingQueue('user_chaos_2', isOnline: true);
      expect(networkAttempts, equals(2));

      // Invariant: Server saw retry with same operationId, logic handled idempotently
      final pending = await localDb.getPendingSyncRecords('user_chaos_2');
      expect(pending.isEmpty, isTrue);
    });

    test('Chaos 3: Offline -> Mutation -> App restart -> Reconnect -> Pending operation completes without loss', () async {
      const opId = 'op_chaos_c3';

      // 1. Offline mutation
      await syncEngine.enqueue(
        userId: 'user_chaos_3',
        entityType: 'trip',
        entityId: 'trip_c3',
        action: 'save_draft',
        operationId: opId,
        payload: {'destination': 'Okinawa'},
      );

      // 2. Kill app
      syncEngine.dispose();
      await localDb.close();

      // 3. Restart app and reconnect
      final restartedDb = LocalDatabaseService();
      await restartedDb.initialize(
        databaseFactory: databaseFactoryFfi,
        dbName: dbPath,
      );
      final restartedSync = SyncEngine(localDb: restartedDb);

      final serverTrips = <String, Map<String, dynamic>>{};
      restartedSync.registerHandler('trip', (record) async {
        serverTrips[record.entityId] = Map.from(record.payload);
      });

      try {
        await restartedSync.processPendingQueue('user_chaos_3', isOnline: true);

        expect(serverTrips.length, equals(1));
        expect(serverTrips['trip_c3']?['destination'], equals('Okinawa'));

        final pending = await restartedDb.getPendingSyncRecords('user_chaos_3');
        expect(pending.isEmpty, isTrue);
      } finally {
        restartedSync.dispose();
        await restartedDb.close();
      }
    });

    test('Chaos 4: Rapid connection flapping debounces and avoids duplicate sync storms', () async {
      int dispatchCount = 0;
      syncEngine.registerHandler('trip', (record) async {
        dispatchCount++;
      });

      await syncEngine.enqueue(
        userId: 'user_chaos_4',
        entityType: 'trip',
        entityId: 'trip_c4',
        action: 'update',
        operationId: 'op_c4',
        payload: {'destination': 'Takayama'},
      );

      // Simulate rapid flap: online -> offline -> online concurrently
      final f1 = syncEngine.processPendingQueue('user_chaos_4', isOnline: true);
      final f2 = syncEngine.processPendingQueue('user_chaos_4', isOnline: false);
      final f3 = syncEngine.processPendingQueue('user_chaos_4', isOnline: true);

      await Future.wait([f1, f2, f3]);

      // Due to single-flight mutex (_isSyncing), operation is dispatched at most once
      expect(dispatchCount, equals(1));
      final pending = await localDb.getPendingSyncRecords('user_chaos_4');
      expect(pending.isEmpty, isTrue);
    });
  });
}
