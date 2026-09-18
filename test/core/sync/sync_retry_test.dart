import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/sync/sync_engine.dart';

void main() {
  sqfliteFfiInit();

  late LocalDatabaseService localDb;
  late SyncEngine syncEngine;

  setUp(() async {
    localDb = LocalDatabaseService();
    await localDb.initialize(
      databaseFactory: databaseFactoryFfi,
      dbName: 'sync_retry_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    syncEngine = SyncEngine(localDb: localDb);
  });

  tearDown(() async {
    syncEngine.dispose();
    await localDb.close();
  });

  group('Phase 12.3 Sync Retry & Error Classification Tests (12.3.6 & 12.3.7)', () {
    test('Transient error increments retry count and backs off', () async {
      int attempts = 0;
      syncEngine.registerHandler('trip', (record) async {
        attempts++;
        throw const FormatException('SocketException: Network timeout occurred');
      });

      final opId = await syncEngine.enqueue(
        userId: 'user_retry',
        entityType: 'trip',
        entityId: 'trip_retry_1',
        action: 'create',
        payload: {'id': 'trip_retry_1', 'user_id': 'user_retry', 'destination': 'Kyoto'},
      );

      final count = await syncEngine.processPendingQueue('user_retry', isOnline: true);
      expect(count, equals(0));
      expect(attempts, equals(1));

      final records = await localDb.getPendingSyncRecords('user_retry');
      expect(records.length, equals(1));
      expect(records.first.operationId, equals(opId));
      expect(records.first.retryCount, equals(1));
      expect(records.first.status, equals('failed'));
    });

    test('Permanent authorization / validation error does not endlessly retry', () async {
      int attempts = 0;
      syncEngine.registerHandler('trip', (record) async {
        attempts++;
        throw StateError('403 Forbidden: Row Level Security policy violated');
      });

      await syncEngine.enqueue(
        userId: 'user_perm',
        entityType: 'trip',
        entityId: 'trip_perm_1',
        action: 'update',
        payload: {'id': 'trip_perm_1', 'user_id': 'user_perm', 'destination': 'Tokyo'},
      );

      final count = await syncEngine.processPendingQueue('user_perm', isOnline: true);
      expect(count, equals(0));
      expect(attempts, equals(1));

      final records = await localDb.getPendingSyncRecords('user_perm');
      expect(records.first.status, equals('failed'));
      expect(records.first.errorMessage, contains('403 Forbidden'));
    });

    test('Exceeding max retry bound (5) marks failed and stops retrying', () async {
      syncEngine.registerHandler('trip', (record) async {
        throw StateError('Server unavailable');
      });

      final opId = await syncEngine.enqueue(
        userId: 'user_bound',
        entityType: 'trip',
        entityId: 'trip_bound_1',
        action: 'create',
        payload: {'id': 'trip_bound_1', 'user_id': 'user_bound', 'destination': 'Osaka'},
      );

      // Artificially simulate 5 past failures
      await localDb.updateSyncRecordStatus(
        opId,
        'failed',
        retryCount: 5,
      );

      int attempts = 0;
      syncEngine.registerHandler('trip', (record) async {
        attempts++;
      });

      await syncEngine.processPendingQueue('user_bound', isOnline: true);
      expect(attempts, equals(0), reason: 'Must not retry after exceeding 5 attempts');

      final records = await localDb.getPendingSyncRecords('user_bound');
      expect(records.first.errorMessage, contains('Exceeded maximum retry limit'));
    });

    test('Authentication failure halts queue processing and sets authRequired', () async {
      syncEngine.registerHandler('trip', (record) async {
        throw StateError('401 Unauthorized: Session token expired');
      });

      await syncEngine.enqueue(
        userId: 'user_auth',
        entityType: 'trip',
        entityId: 'trip_auth_1',
        action: 'create',
        payload: {'id': 'trip_auth_1', 'user_id': 'user_auth', 'destination': 'Nagoya'},
      );

      await syncEngine.processPendingQueue('user_auth', isOnline: true);
      expect(syncEngine.status, equals(SyncEngineStatus.authRequired));
    });
  });
}
