import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/database_exceptions.dart';
import 'package:safemate/core/database/database_models.dart';
import 'package:safemate/core/database/local_database.dart';

void main() {
  sqfliteFfiInit();

  late LocalDatabase localDb;

  setUp(() async {
    localDb = LocalDatabase();
    await localDb.open(
      databaseFactory: databaseFactoryFfi,
      dbName: 'sync_queue_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
  });

  tearDown(() async {
    await localDb.close();
  });

  group('Phase 12.1 Sync Queue Storage Tests (12.1.12 & 12.1.13)', () {
    test('enqueues and retrieves sync operations for specific user', () async {
      final op = LocalSyncQueueRecord(
        id: 'sync_row_001',
        userId: 'user_alice',
        operationId: 'uuid-op-001',
        entityType: 'trip',
        entityId: 'trip_100',
        operationType: 'create',
        payload: '{"destination":"Prague"}',
        createdAt: DateTime.now(),
        status: 'PENDING',
      );

      await localDb.enqueueSyncOperation(op);

      final pending = await localDb.getPendingSyncOperations('user_alice');
      expect(pending.length, 1);
      expect(pending.first.operationId, 'uuid-op-001');
      expect(pending.first.entityType, 'trip');
    });

    test('enforces unique operation_id constraint and throws DatabaseConstraintException', () async {
      final op1 = LocalSyncQueueRecord(
        id: 'sync_row_002',
        userId: 'user_alice',
        operationId: 'uuid-duplicate-check',
        entityType: 'trip',
        entityId: 'trip_101',
        operationType: 'create',
        payload: '{"destination":"Vienna"}',
        createdAt: DateTime.now(),
        status: 'PENDING',
      );

      final op2 = LocalSyncQueueRecord(
        id: 'sync_row_003',
        userId: 'user_alice',
        operationId: 'uuid-duplicate-check', // Duplicate operation_id
        entityType: 'trip',
        entityId: 'trip_101',
        operationType: 'update',
        payload: '{"destination":"Vienna"}',
        createdAt: DateTime.now(),
        status: 'PENDING',
      );

      await localDb.enqueueSyncOperation(op1);

      expect(
        () => localDb.enqueueSyncOperation(op2),
        throwsA(isA<DatabaseConstraintException>()),
      );
    });

    test('updates sync operation status correctly', () async {
      final op = LocalSyncQueueRecord(
        id: 'sync_row_004',
        userId: 'user_bob',
        operationId: 'uuid-op-status-test',
        entityType: 'profile',
        entityId: 'user_bob',
        operationType: 'update',
        payload: '{"displayName":"Bob Updated"}',
        createdAt: DateTime.now(),
        status: 'PENDING',
      );

      await localDb.enqueueSyncOperation(op);
      await localDb.updateSyncOperationStatus('uuid-op-status-test', 'SYNCED');

      // Now pending query should return empty
      final pending = await localDb.getPendingSyncOperations('user_bob');
      expect(pending.isEmpty, isTrue);
    });
  });
}
