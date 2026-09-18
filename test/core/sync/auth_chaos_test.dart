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
      dbName: 'auth_chaos_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    syncEngine = SyncEngine(localDb: localDb);
  });

  tearDown(() async {
    syncEngine.dispose();
    await localDb.close();
  });

  group('Phase 12.5.5 — Authentication Chaos & Multi-Account Isolation Tests', () {
    test('CRITICAL INVARIANT: User A queue remains completely isolated when User B logs in', () async {
      const userA = 'user_alice_uuid';
      const userB = 'user_bob_uuid';

      final userADispatches = <String>[];
      final userBDispatches = <String>[];

      syncEngine.registerHandler('trip', (record) async {
        if (record.userId == userA) {
          userADispatches.add(record.operationId);
        } else if (record.userId == userB) {
          userBDispatches.add(record.operationId);
        }
      });

      // 1. User A enqueues 2 operations while offline
      await syncEngine.enqueue(
        userId: userA,
        entityType: 'trip',
        entityId: 'trip_alice_1',
        action: 'create',
        operationId: 'op_alice_1',
        payload: {'destination': 'Paris', 'notes': 'Alice trip notes'},
      );
      await syncEngine.enqueue(
        userId: userA,
        entityType: 'trip',
        entityId: 'trip_alice_2',
        action: 'save_draft',
        operationId: 'op_alice_2',
        payload: {'destination': 'Nice', 'notes': 'Alice secret draft'},
      );

      // Verify User A has 2 pending operations
      final alicePendingBefore = await localDb.getPendingSyncRecords(userA);
      expect(alicePendingBefore.length, equals(2));

      // 2. User A logs out (Sync engine is notified or user session switches)
      // 3. User B logs in and enqueues their own operation
      await syncEngine.enqueue(
        userId: userB,
        entityType: 'trip',
        entityId: 'trip_bob_1',
        action: 'create',
        operationId: 'op_bob_1',
        payload: {'destination': 'Tokyo', 'notes': 'Bob trip notes'},
      );

      // 4. User B syncs their queue online
      await syncEngine.processPendingQueue(userB, isOnline: true);

      // Invariant: User B's sync MUST ONLY dispatch User B's operations
      expect(userBDispatches, contains('op_bob_1'));
      expect(userBDispatches.length, equals(1));

      // Invariant: User A's operations were NEVER touched or dispatched under User B's session
      expect(userADispatches.isEmpty, isTrue);

      // Invariant: User A's operations remain safely isolated in SQLite
      final alicePendingAfter = await localDb.getPendingSyncRecords(userA);
      expect(alicePendingAfter.length, equals(2));
      expect(alicePendingAfter.map((r) => r.operationId), containsAll(['op_alice_1', 'op_alice_2']));

      // User B's pending operations are now empty
      final bobPendingAfter = await localDb.getPendingSyncRecords(userB);
      expect(bobPendingAfter.isEmpty, isTrue);
    });

    test('Expired Access Token with auto-refresh success resumes sync cleanly', () async {
      int authAttempts = 0;
      bool tokenRefreshed = false;

      syncEngine.registerHandler('trip', (record) async {
        authAttempts++;
        if (!tokenRefreshed) {
          // Token expired on attempt 1
          tokenRefreshed = true; // Auto-refreshed by client auth provider
          throw const FormatException('SocketException: 401 Unauthorized token expired');
        }
        // Attempt 2 succeeds with refreshed token
      });

      await syncEngine.enqueue(
        userId: 'user_auth_exp',
        entityType: 'trip',
        entityId: 'trip_exp_1',
        action: 'create',
        operationId: 'op_auth_exp',
        payload: {'destination': 'London'},
      );

      // Attempt 1: Fails due to 401
      await syncEngine.processPendingQueue('user_auth_exp', isOnline: true);
      expect(authAttempts, equals(1));

      // Reset cooldown to simulate immediate post-refresh retry
      await localDb.updateSyncRecordStatus(
        'op_auth_exp',
        'pending',
        lastAttemptAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      // Attempt 2: Succeeds with refreshed token
      await syncEngine.processPendingQueue('user_auth_exp', isOnline: true);
      expect(authAttempts, equals(2));

      final pending = await localDb.getPendingSyncRecords('user_auth_exp');
      expect(pending.isEmpty, isTrue);
    });

    test('Refresh Failure pauses queue, marks authentication error, preserves data', () async {
      syncEngine.registerHandler('profile', (record) async {
        throw const FormatException('401 Invalid Refresh Token: Session terminated');
      });

      await syncEngine.enqueue(
        userId: 'user_perm_auth_fail',
        entityType: 'profile',
        entityId: 'prof_perm_fail',
        action: 'update',
        operationId: 'op_perm_fail',
        payload: {'bio': 'Traveler bio'},
      );

      await syncEngine.processPendingQueue('user_perm_auth_fail', isOnline: true);

      // Must be marked authentication error without losing data
      final records = await localDb.getPendingSyncRecords('user_perm_auth_fail');
      expect(records.length, equals(1));
      expect(records.first.errorMessage, contains('Authentication expired'));
    });

    test('Logout during active sync gracefully terminates remaining queue', () async {
      final processedOps = <String>[];
      bool loggedOut = false;

      syncEngine.registerHandler('trip', (record) async {
        if (loggedOut) {
          throw const FormatException('401 User logged out');
        }
        processedOps.add(record.operationId);
        // Simulate user clicking logout during first item processing
        loggedOut = true;
      });

      await syncEngine.enqueue(
        userId: 'user_concurrent_logout',
        entityType: 'trip',
        entityId: 'trip_c1',
        action: 'create',
        operationId: 'op_logout_1',
        payload: {'destination': 'Rome'},
      );
      await syncEngine.enqueue(
        userId: 'user_concurrent_logout',
        entityType: 'trip',
        entityId: 'trip_c2',
        action: 'create',
        operationId: 'op_logout_2',
        payload: {'destination': 'Venice'},
      );

      await syncEngine.processPendingQueue('user_concurrent_logout', isOnline: true);

      // First op succeeded; second op was stopped by auth termination
      expect(processedOps, contains('op_logout_1'));

      final pending = await localDb.getPendingSyncRecords('user_concurrent_logout');
      expect(pending.length, equals(1));
      expect(pending.first.operationId, equals('op_logout_2'));
    });
  });
}
