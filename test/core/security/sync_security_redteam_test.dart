import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/database_exceptions.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/sync/deterministic_reconciler.dart';
import 'package:safemate/core/sync/realtime_reconciler.dart';
import 'package:safemate/core/sync/sync_engine.dart';

void main() {
  sqfliteFfiInit();

  late LocalDatabaseService localDb;
  late SyncEngine syncEngine;
  late RealtimeReconciler realtimeReconciler;
  late DeterministicReconciler reconciler;

  setUp(() async {
    localDb = LocalDatabaseService();
    await localDb.initialize(
      databaseFactory: databaseFactoryFfi,
      dbName: 'security_redteam_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    syncEngine = SyncEngine(localDb: localDb);
    reconciler = DeterministicReconciler.instance;
    realtimeReconciler = RealtimeReconciler(localDb: localDb, reconciler: reconciler);
  });

  tearDown(() async {
    syncEngine.dispose();
    await localDb.close();
  });

  group('Phase 12.5.14 — Security Red Team Attack Scenarios', () {
    test('RED TEAM ATTACK 1: Cross-user queue execution is completely isolated and rejected', () async {
      const victimUser = 'victim_traveler_uuid';
      const attackerUser = 'attacker_user_uuid';

      // Victim enqueues sensitive draft while offline
      await syncEngine.enqueue(
        userId: victimUser,
        entityType: 'trip',
        entityId: 'trip_victim_1',
        action: 'create',
        operationId: 'op_victim_1',
        payload: {'destination': 'Zurich', 'notes': 'Confidential itinerary'},
      );

      final dispatchedOps = <String>[];
      syncEngine.registerHandler('trip', (record) async {
        dispatchedOps.add(record.operationId);
      });

      // Attacker invokes processPendingQueue with attacker's session
      await syncEngine.processPendingQueue(attackerUser, isOnline: true);

      // Invariant: Attacker execution dispatched ZERO victim operations
      expect(dispatchedOps, isEmpty);

      // Victim operations remain safely in victim's isolated queue
      final victimPending = await localDb.getPendingSyncRecords(victimUser);
      expect(victimPending.length, equals(1));
      expect(victimPending.first.operationId, equals('op_victim_1'));
    });

    test('RED TEAM ATTACK 2: Forged verification status & trust score in profile payload are frozen', () {
      const userId = 'user_impostor';

      // Attacker attempts to forge verified status and trust score of 100 locally
      final baseProfile = {
        'display_name': 'Original Name',
        'verification_level': 'unverified',
        'trust_score': 30,
        'badge_count': 0,
        'version': 1,
      };

      final localForgedProfile = {
        'display_name': 'Hacked Name',
        'verification_level': 'fully_verified', // FORGED
        'trust_score': 100,                     // FORGED
        'badge_count': 10,                      // FORGED
        'version': 1,
      };

      final serverAuthoritativeProfile = {
        'display_name': 'Original Name',
        'verification_level': 'unverified',
        'trust_score': 30,
        'badge_count': 0,
        'version': 2,
      };

      final result = reconciler.reconcile(
        entityType: 'profile',
        entityId: 'prof_impostor',
        userId: userId,
        baseVersion: 1,
        serverVersion: 2,
        baseState: baseProfile,
        localState: localForgedProfile,
        serverState: serverAuthoritativeProfile,
      );

      // Invariant: Reconciler must freeze server-authoritative fields
      final finalPayload = result.mergedPayload;
      expect(finalPayload, isNotNull);
      expect(finalPayload!['verification_level'], equals('unverified'),
          reason: 'Forged verification_level must be rejected; server authority wins');
      expect(finalPayload['trust_score'], equals(30),
          reason: 'Forged trust_score must be rejected; server authority wins');
      expect(finalPayload['badge_count'], equals(0));
    });

    test('RED TEAM ATTACK 3: Category C credentials/PII injection into sync payload is blocked at gateway', () async {
      bool caughtPolicyViolation = false;

      try {
        await syncEngine.enqueue(
          userId: 'user_malicious',
          entityType: 'profile',
          entityId: 'prof_malicious',
          action: 'update',
          payload: {
            'bio': 'Harmless bio',
            'auth_token': 'secret_jwt_token_attempt', // Prohibited Category C
            'aadhaar_number': '1234-5678-9012',       // Prohibited Category C
          },
        );
      } on DatabasePolicyViolationException {
        caughtPolicyViolation = true;
      }

      // Invariant: Enqueue must be blocked by LocalDataPolicy before touching SQLite
      expect(caughtPolicyViolation, isTrue);

      final records = await localDb.getPendingSyncRecords('user_malicious');
      expect(records, isEmpty);
    });

    test('RED TEAM ATTACK 4: Deleted-record resurrection via stale replay is rejected', () async {
      // Entity was deleted on server and is absent locally
      final absent = await localDb.getTrip('trip_deleted_target');
      expect(absent, isNull);

      // Attacker attempts to replay an older update event (version 1)
      await realtimeReconciler.ingestServerEvent(
        entityType: 'trip',
        entityId: 'trip_deleted_target',
        userId: 'user_attacker',
        serverVersion: 1,
        serverPayload: {
          'id': 'trip_deleted_target',
          'user_id': 'user_attacker',
          'destination': 'Resurrected Trip',
          'version': 1,
        },
      );

      // Invariant: The entity is NOT resurrected in local SQLite
      final stillAbsent = await localDb.getTrip('trip_deleted_target');
      expect(stillAbsent, isNull,
          reason: 'Stale update on an absent or deleted entity must never recreate/resurrect it in SQLite');
    });
  });
}
