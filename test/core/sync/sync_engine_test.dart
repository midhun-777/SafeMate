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
      dbName: 'sync_engine_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    syncEngine = SyncEngine(localDb: localDb);
  });

  tearDown(() async {
    syncEngine.dispose();
    await localDb.close();
  });

  group('Phase 12.3 SyncEngine Core Tests (12.3.5)', () {
    test('Enqueues valid mutation and processes successfully with registered handler', () async {
      final executed = <String>[];
      syncEngine.registerHandler('trip', (record) async {
        executed.add(record.operationId);
      });

      final opId = await syncEngine.enqueue(
        userId: 'user_1',
        entityType: 'trip',
        entityId: 'trip_100',
        action: 'create',
        payload: {
          'id': 'trip_100',
          'user_id': 'user_1',
          'destination': 'Tokyo',
          'origin': 'Kyoto',
        },
      );

      expect(opId, isNotEmpty);
      final count = await syncEngine.processPendingQueue('user_1', isOnline: true);

      expect(count, equals(1));
      expect(executed, contains(opId));

      // Queue item should be deleted after successful sync
      final remaining = await localDb.getPendingSyncRecords('user_1');
      expect(remaining, isEmpty);
    });

    test('Single-flight processing prevents concurrent queue execution', () async {
      int handlerCalls = 0;
      syncEngine.registerHandler('trip', (record) async {
        handlerCalls++;
        await Future.delayed(const Duration(milliseconds: 100));
      });

      await syncEngine.enqueue(
        userId: 'user_2',
        entityType: 'trip',
        entityId: 'trip_200',
        action: 'create',
        payload: {
          'id': 'trip_200',
          'user_id': 'user_2',
          'destination': 'Osaka',
        },
      );

      // Start first process run
      final future1 = syncEngine.processPendingQueue('user_2', isOnline: true);

      // Trigger second process run immediately while first is in-flight
      final count2 = await syncEngine.processPendingQueue('user_2', isOnline: true);
      expect(count2, equals(0), reason: 'Concurrent sync execution must be rejected');

      final count1 = await future1;
      expect(count1, equals(1));
      expect(handlerCalls, equals(1));
    });

    test('Offline status pauses sync processing without calling handler', () async {
      bool handlerCalled = false;
      syncEngine.registerHandler('trip', (record) async {
        handlerCalled = true;
      });

      await syncEngine.enqueue(
        userId: 'user_3',
        entityType: 'trip',
        entityId: 'trip_300',
        action: 'create',
        payload: {
          'id': 'trip_300',
          'user_id': 'user_3',
          'destination': 'Nara',
        },
      );

      final count = await syncEngine.processPendingQueue('user_3', isOnline: false);
      expect(count, equals(0));
      expect(handlerCalled, isFalse);
      expect(syncEngine.status, equals(SyncEngineStatus.offline));
    });
  });
}
