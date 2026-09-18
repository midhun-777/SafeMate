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
      dbName: 'sync_idempotency_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    syncEngine = SyncEngine(localDb: localDb);
  });

  tearDown(() async {
    syncEngine.dispose();
    await localDb.close();
  });

  group('Phase 12.3 Sync Idempotency Tests (12.3.2)', () {
    test('Retrying preserves original operation_id and does not generate new ID', () async {
      final receivedOpIds = <String>[];
      int attempt = 0;

      syncEngine.registerHandler('trip', (record) async {
        receivedOpIds.add(record.operationId);
        attempt++;
        if (attempt == 1) {
          throw const FormatException('SocketException: Intermittent timeout');
        }
        // Second attempt succeeds
      });

      final fixedOpId = 'fixed_client_operation_uuid_123';
      await syncEngine.enqueue(
        userId: 'user_idem',
        entityType: 'trip',
        entityId: 'trip_idem_1',
        action: 'create',
        operationId: fixedOpId,
        payload: {'id': 'trip_idem_1', 'user_id': 'user_idem', 'destination': 'Hakone'},
      );

      // Attempt 1: Fails
      await syncEngine.processPendingQueue('user_idem', isOnline: true);

      // Verify record in database still has the same operationId
      final pendingAfterFail = await localDb.getPendingSyncRecords('user_idem');
      expect(pendingAfterFail.first.operationId, equals(fixedOpId));
      expect(pendingAfterFail.first.retryCount, equals(1));

      // Reset cooldown artificially to allow immediate retry in test
      await localDb.updateSyncRecordStatus(
        fixedOpId,
        'pending',
        lastAttemptAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      // Attempt 2: Succeeds
      await syncEngine.processPendingQueue('user_idem', isOnline: true);

      expect(receivedOpIds.length, equals(2));
      expect(receivedOpIds[0], equals(fixedOpId));
      expect(receivedOpIds[1], equals(fixedOpId), reason: 'Retry must reuse the exact same client operation ID');
    });

    test('Duplicate enqueue with same operationId replaces cleanly without duplicate rows', () async {
      final opId = 'op_dup_check_999';

      await syncEngine.enqueue(
        userId: 'user_dup',
        entityType: 'trip',
        entityId: 'trip_dup_1',
        action: 'create',
        operationId: opId,
        payload: {'destination': 'Yokohama'},
      );

      await syncEngine.enqueue(
        userId: 'user_dup',
        entityType: 'trip',
        entityId: 'trip_dup_1',
        action: 'create',
        operationId: opId,
        payload: {'destination': 'Yokohama Updated'},
      );

      final records = await localDb.getPendingSyncRecords('user_dup');
      expect(records.length, equals(1));
      expect(records.first.operationId, equals(opId));
      expect(records.first.payload['destination'], equals('Yokohama Updated'));
    });
  });
}
