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
    final tempDir = Directory.systemTemp.createTempSync('safemate_durability_');
    dbPath = '${tempDir.path}/durability_test.db';

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

  group('Phase 12.5.2 — Offline Queue Durability Tests', () {
    test('INVARIANT: PENDING OPERATION + APP RESTART = PENDING OPERATION STILL EXISTS', () async {
      const userId = 'user_durability_1';

      // 1. Enqueue 3 operations while offline
      await syncEngine.enqueue(
        userId: userId,
        entityType: 'trip',
        entityId: 'trip_101',
        action: 'create',
        operationId: 'op_trip_101',
        payload: {'destination': 'Kyoto', 'status': 'draft'},
        baseServerVersion: 1,
        localRevision: 2,
      );

      await syncEngine.enqueue(
        userId: userId,
        entityType: 'profile',
        entityId: 'prof_101',
        action: 'update',
        operationId: 'op_prof_101',
        payload: {'bio': 'Solo traveler visiting shrines'},
        baseServerVersion: 3,
        localRevision: 4,
      );

      await syncEngine.enqueue(
        userId: userId,
        entityType: 'safetrip_checkin',
        entityId: 'chk_101',
        action: 'record_checkin',
        operationId: 'op_chk_101',
        payload: {'journey_id': 'j_101', 'notes': 'Arrived at station'},
        baseServerVersion: 1,
        localRevision: 2,
      );

      // Verify all 3 pending before simulated kill
      final initialPending = await localDb.getPendingSyncRecords(userId);
      expect(initialPending.length, equals(3));

      // 2. Simulate OS Process Death / Force Close
      syncEngine.dispose();
      await localDb.close();

      // 3. Simulate App Cold Restart (reopen existing database file)
      final restartedDb = LocalDatabaseService();
      await restartedDb.initialize(
        databaseFactory: databaseFactoryFfi,
        dbName: dbPath,
      );
      final restartedSyncEngine = SyncEngine(localDb: restartedDb);

      try {
        // 4. Verify all 3 operations survived intact
        final survivedRecords = await restartedDb.getPendingSyncRecords(userId);
        expect(survivedRecords.length, equals(3));

        final tripOp = survivedRecords.firstWhere((r) => r.operationId == 'op_trip_101');
        expect(tripOp.entityType, equals('trip'));
        expect(tripOp.payload['destination'], equals('Kyoto'));
        expect(tripOp.baseServerVersion, equals(1));
        expect(tripOp.status, equals('pending'));

        final profOp = survivedRecords.firstWhere((r) => r.operationId == 'op_prof_101');
        expect(profOp.entityType, equals('profile'));
        expect(profOp.payload['bio'], equals('Solo traveler visiting shrines'));

        final chkOp = survivedRecords.firstWhere((r) => r.operationId == 'op_chk_101');
        expect(chkOp.entityType, equals('safetrip_checkin'));
        expect(chkOp.payload['journey_id'], equals('j_101'));
      } finally {
        restartedSyncEngine.dispose();
        await restartedDb.close();
      }
    });

    test('Pending operations survive temporary network loss and authentication pauses without deletion', () async {
      const userId = 'user_durability_2';

      await syncEngine.enqueue(
        userId: userId,
        entityType: 'trip',
        entityId: 'trip_202',
        action: 'save_draft',
        operationId: 'op_trip_202',
        payload: {'destination': 'Osaka'},
      );

      // Attempt sync while offline -> Should remain pending without deletion
      await syncEngine.processPendingQueue(userId, isOnline: false);
      var records = await localDb.getPendingSyncRecords(userId);
      expect(records.length, equals(1));
      expect(records.first.operationId, equals('op_trip_202'));

      // Register handler that throws authentication error
      syncEngine.registerHandler('trip', (record) async {
        throw const FormatException('401 Unauthorized: Session expired');
      });

      // Attempt sync online -> auth failure pauses queue, does NOT silently delete operation
      await syncEngine.processPendingQueue(userId, isOnline: true);

      records = await localDb.getPendingSyncRecords(userId);
      expect(records.length, equals(1));
      expect(records.first.operationId, equals('op_trip_202'));
      expect(records.first.errorMessage, contains('Authentication expired'));
    });

    test('No silent deletion: records only leave pending on explicit success, resolution, or cancellation', () async {
      const userId = 'user_durability_3';

      await syncEngine.enqueue(
        userId: userId,
        entityType: 'trip',
        entityId: 'trip_303',
        action: 'update',
        operationId: 'op_trip_303',
        payload: {'destination': 'Nara'},
      );

      // Fails with transient error 5 times
      int attempts = 0;
      syncEngine.registerHandler('trip', (record) async {
        attempts++;
        throw const FormatException('SocketException: Connection timeout');
      });

      // Run multiple failed attempts
      for (int i = 0; i < 3; i++) {
        await localDb.updateSyncRecordStatus(
          'op_trip_303',
          'pending',
          lastAttemptAt: DateTime.now().subtract(const Duration(minutes: 10)),
        );
        await syncEngine.processPendingQueue(userId, isOnline: true);
      }

      // Record is still persisted in SQLite
      final queueDb = localDb.database;
      final rawRows = await queueDb.query(
        'sync_queue',
        where: 'operation_id = ?',
        whereArgs: ['op_trip_303'],
      );
      expect(attempts, equals(3));
      expect(rawRows.isNotEmpty, isTrue);
      expect(rawRows.first['retry_count'], equals(3));
      expect(rawRows.first['operation_id'], equals('op_trip_303'));
    });
  });
}
