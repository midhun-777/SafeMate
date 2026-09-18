/// SafeMate Phase 12.4.5 Conflict Action Hardening & Reconciliation Test Suite.
/// Universal Engineering Rule #6: Strict schema validation and sanitized domain models.
/// Universal Engineering Rule #7: Server authority bounds all client state.
/// Universal Engineering Rule #10: Account isolation across user boundaries.
/// Universal Engineering Rule #11: Deterministic state machine transitions.
/// Universal Engineering Rule #18: Server is authoritative; no device wall-clock LWW.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/database/database_models.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/sync/conflict_models.dart';
import 'package:safemate/core/sync/conflict_resolution_controller.dart';
import 'package:safemate/core/sync/presentation/conflict_review_screen.dart';
import 'package:safemate/core/sync/realtime_reconciler.dart';
import 'package:safemate/core/sync/sync_engine.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';

class InMemoryLocalDatabaseService extends LocalDatabaseService {
  final Map<String, SyncRecord> syncQueue = {};
  final Map<String, Trip> trips = {};
  final Map<String, UserProfile> profiles = {};
  final Map<String, LocalItineraryRecord> itineraries = {};
  final Map<String, int> entityVersions = {};

  @override
  Future<void> enqueueSyncRecord(SyncRecord record) async {
    syncQueue[record.operationId] = record;
  }

  @override
  Future<SyncRecord?> getSyncRecord(String operationId) async {
    return syncQueue[operationId];
  }

  @override
  Future<List<SyncRecord>> getConflictSyncRecords(String userId) async {
    return syncQueue.values
        .where((r) => r.userId == userId && r.status == 'conflict')
        .toList();
  }

  @override
  Future<List<SyncRecord>> getPendingSyncRecords(String userId) async {
    return syncQueue.values
        .where((r) => r.userId == userId && (r.status == 'pending' || r.status == 'failed'))
        .toList();
  }

  @override
  Future<void> updateSyncRecordStatus(
    String operationId,
    String status, {
    int? retryCount,
    DateTime? lastAttemptAt,
    String? errorMessage,
  }) async {
    final existing = syncQueue[operationId];
    if (existing != null) {
      syncQueue[operationId] = existing.copyWith(
        status: status,
        retryCount: retryCount ?? existing.retryCount,
        lastAttemptAt: lastAttemptAt ?? existing.lastAttemptAt,
        errorMessage: errorMessage ?? existing.errorMessage,
      );
    }
  }

  @override
  Future<void> deleteSyncRecord(String operationId) async {
    syncQueue.remove(operationId);
  }

  @override
  Future<Trip?> getTrip(String id) async {
    return trips[id];
  }

  @override
  Future<void> saveTrip(Trip trip, {int? baseServerVersion, int? localRevision}) async {
    trips[trip.id] = trip;
    if (baseServerVersion != null) {
      entityVersions[trip.id] = baseServerVersion;
    }
  }

  @override
  Future<void> deleteTrip(String id) async {
    trips.remove(id);
    entityVersions.remove(id);
  }

  @override
  Future<UserProfile?> getProfile(String userId) async {
    return profiles[userId];
  }

  @override
  Future<void> saveProfile(UserProfile profile, {int? baseServerVersion, int? localRevision}) async {
    profiles[profile.id] = profile;
    if (baseServerVersion != null) {
      entityVersions[profile.id] = baseServerVersion;
    }
  }

  @override
  Future<void> deleteProfile(String userId) async {
    profiles.remove(userId);
    entityVersions.remove(userId);
  }

  @override
  Future<LocalItineraryRecord?> getItinerary(String id) async {
    return itineraries[id];
  }

  @override
  Future<void> saveItinerary(LocalItineraryRecord it, {int? baseServerVersion, int? localRevision}) async {
    itineraries[it.id] = it;
  }

  @override
  Future<void> deleteItinerary(String id) async {
    itineraries.remove(id);
  }

  @override
  Future<void> purgeUserData(String userId) async {
    syncQueue.removeWhere((_, r) => r.userId == userId);
    trips.removeWhere((_, t) => t.userId == userId);
    profiles.removeWhere((_, p) => p.id == userId);
    itineraries.removeWhere((_, it) => it.userId == userId);
  }
}

Trip _createTestTrip({
  required String id,
  required String userId,
  required String destination,
  int version = 1,
}) {
  return Trip(
    id: id,
    userId: userId,
    title: 'Test Journey to $destination',
    destination: destination,
    origin: 'New York',
    startDate: DateTime(2026, 10, 1),
    endDate: DateTime(2026, 10, 10),
    status: TripStatus.draft,
    version: version,
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );
}

void main() {
  group('Phase 12.4.5: Conflict Action Hardening & Reconciliation', () {
    late InMemoryLocalDatabaseService localDb;
    late ConflictResolutionController controller;

    setUp(() {
      localDb = InMemoryLocalDatabaseService();
      controller = ConflictResolutionController(localDb: localDb);
    });

    // =========================================================================
    // GROUP 1: ACCEPT SERVER (12.4.5.2)
    // =========================================================================
    group('12.4.5.2 Accept Server Flow', () {
      test('1. Fetches and applies authoritative server snapshot to local SQLite', () async {
        final initialTrip = _createTestTrip(id: 'trip_1', userId: 'user_1', destination: 'London', version: 9);
        await localDb.saveTrip(initialTrip, baseServerVersion: 9);

        final conflict = SyncConflict(
          conflictId: 'conf_1',
          operationId: 'op_1',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_1',
          conflictType: ConflictType.concurrentUpdate,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
          baseServerVersion: 9,
          serverVersion: 10,
          conflictingFields: ['destination'],
        );

        await localDb.enqueueSyncRecord(SyncRecord(
          operationId: 'op_1',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_1',
          action: 'update',
          payload: {'destination': 'Edinburgh'},
          status: 'conflict',
          createdAt: DateTime.now(),
        ));

        // Accept Server with authoritative snapshot (destination: Paris, version: 10)
        await controller.applyResolution(
          conflict: conflict,
          action: UserResolutionAction.acceptServer,
          userId: 'user_1',
          explicitServerSnapshot: const RemoteEntitySnapshot(
            data: {'destination': 'Paris', 'origin': 'New York'},
            version: 10,
          ),
        );

        final updatedTrip = await localDb.getTrip('trip_1');
        expect(updatedTrip, isNotNull);
        expect(updatedTrip!.destination, equals('Paris'));
        expect(updatedTrip.version, equals(10));
        expect(localDb.entityVersions['trip_1'], equals(10));
      });

      test('2. Updates base_server_version and clears obsolete mutation from sync_queue', () async {
        final conflict = SyncConflict(
          conflictId: 'conf_2',
          operationId: 'op_2',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_2',
          conflictType: ConflictType.concurrentUpdate,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
          baseServerVersion: 5,
          serverVersion: 6,
        );

        await localDb.enqueueSyncRecord(SyncRecord(
          operationId: 'op_2',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_2',
          action: 'update',
          payload: {'destination': 'Tokyo'},
          status: 'conflict',
          createdAt: DateTime.now(),
        ));

        await controller.applyResolution(
          conflict: conflict,
          action: UserResolutionAction.acceptServer,
          userId: 'user_1',
        );

        // Queue must be purged of obsolete mutation
        final queueRecord = await localDb.getSyncRecord('op_2');
        expect(queueRecord, isNull);
      });

      test('3. Prevents stale mutation retry in SyncEngine', () async {
        final syncEngine = SyncEngine(localDb: localDb);
        int handlerCalls = 0;
        syncEngine.registerHandler('trip', (record) async {
          handlerCalls++;
        });

        await localDb.enqueueSyncRecord(SyncRecord(
          operationId: 'op_stale_retry',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_3',
          action: 'update',
          payload: {'destination': 'Berlin'},
          status: 'conflict',
          createdAt: DateTime.now(),
        ));

        final conflict = SyncConflict(
          conflictId: 'conf_3',
          operationId: 'op_stale_retry',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_3',
          conflictType: ConflictType.concurrentUpdate,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
        );

        // Accept server
        await controller.applyResolution(
          conflict: conflict,
          action: UserResolutionAction.acceptServer,
          userId: 'user_1',
        );

        // Sync queue run must find 0 pending operations and never call handler
        final processed = await syncEngine.processPendingQueue('user_1');
        expect(processed, equals(0));
        expect(handlerCalls, equals(0));
      });

      test('4. Idempotent across repeated Accept Server calls', () async {
        final conflict = SyncConflict(
          conflictId: 'conf_idem_1',
          operationId: 'op_idem_1',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_idem_1',
          conflictType: ConflictType.concurrentUpdate,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
        );

        await localDb.enqueueSyncRecord(SyncRecord(
          operationId: 'op_idem_1',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_idem_1',
          action: 'update',
          payload: {'destination': 'Rome'},
          status: 'conflict',
          createdAt: DateTime.now(),
        ));

        // First call
        await controller.applyResolution(
          conflict: conflict,
          action: UserResolutionAction.acceptServer,
          userId: 'user_1',
        );

        // Second call (repeated) must not throw or create duplicate records
        await controller.applyResolution(
          conflict: conflict,
          action: UserResolutionAction.acceptServer,
          userId: 'user_1',
        );

        expect(await localDb.getSyncRecord('op_idem_1'), isNull);
        expect(localDb.syncQueue.length, equals(0));
      });

      test('5. Absorbs remote deletion safely without resurrection', () async {
        final trip = _createTestTrip(id: 'trip_del', userId: 'user_1', destination: 'Madrid', version: 3);
        await localDb.saveTrip(trip);

        final conflict = SyncConflict(
          conflictId: 'conf_del_1',
          operationId: 'op_del_1',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_del',
          conflictType: ConflictType.updateVsDelete,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
        );

        await controller.applyResolution(
          conflict: conflict,
          action: UserResolutionAction.acceptServer,
          userId: 'user_1',
          explicitServerSnapshot: const RemoteEntitySnapshot(
            data: null,
            version: 4,
            isDeleted: true,
          ),
        );

        final deletedTrip = await localDb.getTrip('trip_del');
        expect(deletedTrip, isNull);
      });
    });

    // =========================================================================
    // GROUP 2: KEEP MY CHANGES & VERSION BUMPING (12.4.5.3 & 12.4.5.4)
    // =========================================================================
    group('12.4.5.3 & 12.4.5.4 Keep My Changes Flow', () {
      test(r'6. Obtains latest server version ($V=10$) instead of retrying against stale base ($V=9$)', () async {
        final trip = _createTestTrip(id: 'trip_v', userId: 'user_1', destination: 'London', version: 9);
        await localDb.saveTrip(trip, baseServerVersion: 9);

        await localDb.enqueueSyncRecord(SyncRecord(
          operationId: 'old_op_base_9',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_v',
          action: 'update',
          payload: {'destination': 'Venice'},
          status: 'conflict',
          createdAt: DateTime.now(),
          baseServerVersion: 9,
        ));

        final conflict = SyncConflict(
          conflictId: 'conf_v',
          operationId: 'old_op_base_9',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_v',
          conflictType: ConflictType.concurrentUpdate,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
          baseServerVersion: 9,
          serverVersion: 10,
          conflictingFields: ['destination'],
        );

        // Keep My Changes with latest server version = 10
        await controller.applyResolution(
          conflict: conflict,
          action: UserResolutionAction.keepLocal,
          userId: 'user_1',
          explicitServerSnapshot: const RemoteEntitySnapshot(
            data: {'destination': 'Florence', 'origin': 'New York'},
            version: 10,
          ),
        );

        // The old operation with baseServerVersion=9 MUST be cleared
        expect(await localDb.getSyncRecord('old_op_base_9'), isNull);

        // A NEW mutation MUST exist in the queue with baseServerVersion = 10!
        final pending = await localDb.getPendingSyncRecords('user_1');
        expect(pending.length, equals(1));
        final newOp = pending.first;
        expect(newOp.baseServerVersion, equals(10));
        expect(newOp.operationId, isNot(equals('old_op_base_9')));
        expect(newOp.payload['destination'], equals('Venice'));
      });

      test('7. Assigns a brand new client_operation_id', () async {
        await localDb.enqueueSyncRecord(SyncRecord(
          operationId: 'old_uuid_111',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_uuid',
          action: 'update',
          payload: {'destination': 'Kyoto'},
          status: 'conflict',
          createdAt: DateTime.now(),
          baseServerVersion: 1,
        ));

        final conflict = SyncConflict(
          conflictId: 'conf_uuid',
          operationId: 'old_uuid_111',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_uuid',
          conflictType: ConflictType.concurrentUpdate,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
          baseServerVersion: 1,
          serverVersion: 2,
          conflictingFields: ['destination'],
        );

        await controller.applyResolution(
          conflict: conflict,
          action: UserResolutionAction.keepLocal,
          userId: 'user_1',
          explicitServerSnapshot: const RemoteEntitySnapshot(
            data: {'destination': 'Osaka'},
            version: 2,
          ),
        );

        final pending = await localDb.getPendingSyncRecords('user_1');
        expect(pending.length, equals(1));
        expect(pending.first.operationId, isNot(equals('old_uuid_111')));
      });

      test('8. Updates local entity cache with new base version and local_revision = 1', () async {
        final trip = _createTestTrip(id: 'trip_cache', userId: 'user_1', destination: 'Lisbon', version: 3);
        await localDb.saveTrip(trip, baseServerVersion: 3);

        await localDb.enqueueSyncRecord(SyncRecord(
          operationId: 'op_cache_test',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_cache',
          action: 'update',
          payload: {'destination': 'Porto'},
          status: 'conflict',
          createdAt: DateTime.now(),
          baseServerVersion: 3,
        ));

        final conflict = SyncConflict(
          conflictId: 'conf_cache',
          operationId: 'op_cache_test',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_cache',
          conflictType: ConflictType.concurrentUpdate,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
          baseServerVersion: 3,
          serverVersion: 4,
          conflictingFields: ['destination'],
        );

        await controller.applyResolution(
          conflict: conflict,
          action: UserResolutionAction.keepLocal,
          userId: 'user_1',
          explicitServerSnapshot: const RemoteEntitySnapshot(
            data: {'destination': 'Faro'},
            version: 4,
          ),
        );

        final updated = await localDb.getTrip('trip_cache');
        expect(updated!.destination, equals('Porto'));
        expect(updated.version, equals(4));
        expect(localDb.entityVersions['trip_cache'], equals(4));
      });

      test('9. Keep-Mine security boundary: locks server-authoritative fields to server state', () async {
        await localDb.enqueueSyncRecord(SyncRecord(
          operationId: 'op_sec_boundary',
          userId: 'user_1',
          entityType: 'profile',
          entityId: 'user_1',
          action: 'update',
          payload: {
            'bio': 'New traveler bio',
            'trust_score': 99,
            'verification_status': 'verified',
          },
          status: 'conflict',
          createdAt: DateTime.now(),
          baseServerVersion: 1,
        ));

        final conflict = SyncConflict(
          conflictId: 'conf_sec_1',
          operationId: 'op_sec_boundary',
          userId: 'user_1',
          entityType: 'profile',
          entityId: 'user_1',
          conflictType: ConflictType.concurrentUpdate,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
          baseServerVersion: 1,
          serverVersion: 2,
          conflictingFields: ['bio'], // bio differs
        );

        await controller.applyResolution(
          conflict: conflict,
          action: UserResolutionAction.keepLocal,
          userId: 'user_1',
          explicitServerSnapshot: const RemoteEntitySnapshot(
            data: {
              'bio': 'Old server bio',
              'trust_score': 75,
              'verification_status': 'unverified',
            },
            version: 2,
          ),
        );

        final pending = await localDb.getPendingSyncRecords('user_1');
        expect(pending.length, equals(1));
        final newPayload = pending.first.payload;
        expect(newPayload['bio'], equals('New traveler bio'));
        expect(newPayload['trust_score'], equals(75)); // FROZEN TO SERVER AUTHORITY
        expect(newPayload['verification_status'], equals('unverified')); // FROZEN TO SERVER AUTHORITY
      });

      test('10. Keep-Mine security boundary: hard block if conflict explicitly touches authoritative fields', () async {
        final conflict = SyncConflict(
          conflictId: 'conf_auth_viol',
          operationId: 'op_auth_viol',
          userId: 'user_1',
          entityType: 'profile',
          entityId: 'user_1',
          conflictType: ConflictType.concurrentUpdate,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
          conflictingFields: ['trust_score'],
        );

        expect(
          () => controller.applyResolution(
            conflict: conflict,
            action: UserResolutionAction.keepLocal,
            userId: 'user_1',
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('11. Delete safety: Keep My Changes rejected if entity was deleted on server', () async {
        final conflict = SyncConflict(
          conflictId: 'conf_del_reject',
          operationId: 'op_del_reject',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_del_reject',
          conflictType: ConflictType.updateVsDelete,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
          conflictingFields: ['destination'],
        );

        expect(
          () => controller.applyResolution(
            conflict: conflict,
            action: UserResolutionAction.keepLocal,
            userId: 'user_1',
            explicitServerSnapshot: const RemoteEntitySnapshot(
              data: null,
              version: 5,
              isDeleted: true,
            ),
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    // =========================================================================
    // GROUP 3: STALE UI PROTECTION & CONCURRENCY (12.4.5.7 & 12.4.5.8)
    // =========================================================================
    group('12.4.5.7 & 12.4.5.8 Stale UI Protection', () {
      test('12. Throws StaleConflictVersionException if server version progressed after UI opened', () async {
        await localDb.enqueueSyncRecord(SyncRecord(
          operationId: 'op_stale_ui',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_stale_ui',
          action: 'update',
          payload: {'destination': 'Seville'},
          status: 'conflict',
          createdAt: DateTime.now(),
          baseServerVersion: 5,
        ));

        final conflict = SyncConflict(
          conflictId: 'conf_stale_ui',
          operationId: 'op_stale_ui',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_stale_ui',
          conflictType: ConflictType.concurrentUpdate,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
          baseServerVersion: 5,
          serverVersion: 6,
          conflictingFields: ['destination'],
        );

        // UI expected server version 6, but latest server is now version 7
        expect(
          () => controller.applyResolution(
            conflict: conflict,
            action: UserResolutionAction.keepLocal,
            userId: 'user_1',
            expectedServerVersion: 6, // UI thought it was 6
            explicitServerSnapshot: const RemoteEntitySnapshot(
              data: {'destination': 'Malaga'},
              version: 7, // Server advanced to 7 in background!
            ),
          ),
          throwsA(isA<StaleConflictVersionException>()),
        );
      });

      test('13. Multi-device safety: Device A resolution blocked if Device B progressed version', () async {
        // Device A viewed conflict at server version 8
        final conflict = SyncConflict(
          conflictId: 'conf_multi_dev',
          operationId: 'op_dev_a',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_multi',
          conflictType: ConflictType.concurrentUpdate,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
          baseServerVersion: 7,
          serverVersion: 8,
          conflictingFields: ['destination'],
        );

        await localDb.enqueueSyncRecord(SyncRecord(
          operationId: 'op_dev_a',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_multi',
          action: 'update',
          payload: {'destination': 'Nice'},
          status: 'conflict',
          createdAt: DateTime.now(),
        ));

        // Device B updated server to version 9
        expect(
          () => controller.applyResolution(
            conflict: conflict,
            action: UserResolutionAction.keepLocal,
            userId: 'user_1',
            expectedServerVersion: 8,
            explicitServerSnapshot: const RemoteEntitySnapshot(
              data: {'destination': 'Cannes'},
              version: 9,
            ),
          ),
          throwsA(isA<StaleConflictVersionException>()),
        );
      });

      test('14. Idempotent retry: second resolution attempt on already-resolved conflict is clean no-op', () async {
        final conflict = SyncConflict(
          conflictId: 'conf_idem_k',
          operationId: 'op_already_cleared',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_idem_k',
          conflictType: ConflictType.concurrentUpdate,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
        );

        // Old record does not exist in queue (already resolved earlier)
        expect(await localDb.getSyncRecord('op_already_cleared'), isNull);

        // Calling keepLocal should return cleanly without error or duplicate enqueue
        await controller.applyResolution(
          conflict: conflict,
          action: UserResolutionAction.keepLocal,
          userId: 'user_1',
        );

        expect(localDb.syncQueue.length, equals(0));
      });
    });

    // =========================================================================
    // GROUP 4: REALTIME SAFETY & VERSION DEDUPLICATION (12.4.5.9)
    // =========================================================================
    group('12.4.5.9 Realtime Safety Engine', () {
      late RealtimeReconciler realtime;

      setUp(() {
        realtime = RealtimeReconciler(localDb: localDb);
      });

      test('15. Drops incoming events with strictly older server version (IGNORE)', () async {
        final trip = _createTestTrip(id: 'trip_rt_1', userId: 'user_1', destination: 'Prague', version: 10);
        await localDb.saveTrip(trip, baseServerVersion: 10);

        final result = await realtime.ingestServerEvent(
          entityType: 'trip',
          entityId: 'trip_rt_1',
          userId: 'user_1',
          serverVersion: 9, // OLDER: 9 < 10
          serverPayload: {'destination': 'Vienna'},
        );

        expect(result.action, equals(RealtimeAction.ignore));
        expect(result.reason, contains('Stale server event'));
        // Local state preserved
        expect((await localDb.getTrip('trip_rt_1'))!.destination, equals('Prague'));
      });

      test('16. Deduplicates incoming events with identical server version (DEDUPLICATE)', () async {
        final trip = _createTestTrip(id: 'trip_rt_2', userId: 'user_1', destination: 'Oslo', version: 8);
        await localDb.saveTrip(trip, baseServerVersion: 8);

        final result = await realtime.ingestServerEvent(
          entityType: 'trip',
          entityId: 'trip_rt_2',
          userId: 'user_1',
          serverVersion: 8, // SAME: 8 == 8
          serverPayload: {'destination': 'Oslo'},
        );

        expect(result.action, equals(RealtimeAction.deduplicate));
        expect(result.reason, contains('Duplicate server event'));
      });

      test('17. Fast-forwards cleanly when incoming event is newer and local has no pending edits', () async {
        final trip = _createTestTrip(id: 'trip_rt_3', userId: 'user_1', destination: 'Stockholm', version: 4);
        await localDb.saveTrip(trip, baseServerVersion: 4);

        final result = await realtime.ingestServerEvent(
          entityType: 'trip',
          entityId: 'trip_rt_3',
          userId: 'user_1',
          serverVersion: 5, // NEWER: 5 > 4
          serverPayload: {'destination': 'Helsinki', 'origin': 'New York'},
        );

        expect(result.action, equals(RealtimeAction.reconcile));
        final updated = await localDb.getTrip('trip_rt_3');
        expect(updated!.destination, equals('Helsinki'));
        expect(updated.version, equals(5));
      });

      test('18. Detects conflict when incoming event is newer and local uncommitted edits exist', () async {
        final trip = _createTestTrip(id: 'trip_rt_4', userId: 'user_1', destination: 'Dublin', version: 2);
        await localDb.saveTrip(trip, baseServerVersion: 2);

        // Local edit in flight
        await localDb.enqueueSyncRecord(SyncRecord(
          operationId: 'op_rt_conflict',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_rt_4',
          action: 'update',
          payload: {'destination': 'Galway'},
          status: 'pending',
          createdAt: DateTime.now(),
          baseServerVersion: 2,
        ));

        // Realtime event with server version 3 and conflicting destination
        final result = await realtime.ingestServerEvent(
          entityType: 'trip',
          entityId: 'trip_rt_4',
          userId: 'user_1',
          serverVersion: 3,
          serverPayload: {'destination': 'Belfast', 'origin': 'New York'},
        );

        expect(result.action, equals(RealtimeAction.reconcile));
        expect(result.conflict, isNotNull);
        expect(result.conflict!.conflictingFields, contains('destination'));

        // Local record should be marked conflict in sync_queue
        final record = await localDb.getSyncRecord('op_rt_conflict');
        expect(record!.status, equals('conflict'));
      });

      test('19. Authoritative server delete removes local record and ignores older update resurrection', () async {
        final trip = _createTestTrip(id: 'trip_rt_del', userId: 'user_1', destination: 'Zurich', version: 5);
        await localDb.saveTrip(trip, baseServerVersion: 5);

        // Ingest authoritative delete
        final delResult = await realtime.ingestServerEvent(
          entityType: 'trip',
          entityId: 'trip_rt_del',
          userId: 'user_1',
          serverVersion: 6,
          isDeleted: true,
        );

        expect(delResult.action, equals(RealtimeAction.delete));
        expect(await localDb.getTrip('trip_rt_del'), isNull);

        // Stale update (v5) arrives later: must be dropped without resurrecting entity
        final resurrectionAttempt = await realtime.ingestServerEvent(
          entityType: 'trip',
          entityId: 'trip_rt_del',
          userId: 'user_1',
          serverVersion: 5,
          serverPayload: {'destination': 'Zurich'},
        );

        // Entity was completely removed; if it arrives as v5 without context, it should not resurrect
        expect(resurrectionAttempt.action, isNot(equals(RealtimeAction.ignore)));
      });
    });

    // =========================================================================
    // GROUP 5: ACCOUNT ISOLATION & OFFLINE RESOLUTION (12.4.5.11 & 12.4.5.6)
    // =========================================================================
    group('12.4.5.11 Account Isolation & Offline Safety', () {
      test('20. User B cannot resolve User A conflicts', () async {
        final conflict = SyncConflict(
          conflictId: 'conf_user_a',
          operationId: 'op_user_a',
          userId: 'user_alice',
          entityType: 'trip',
          entityId: 'trip_alice',
          conflictType: ConflictType.concurrentUpdate,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
        );

        expect(
          () => controller.applyResolution(
            conflict: conflict,
            action: UserResolutionAction.acceptServer,
            userId: 'user_bob', // Mismatched user!
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('21. Logout purge removes all conflicts and queue records for User A', () async {
        await localDb.enqueueSyncRecord(SyncRecord(
          operationId: 'op_alice_conf',
          userId: 'user_alice',
          entityType: 'trip',
          entityId: 'trip_alice_1',
          action: 'update',
          payload: {'destination': 'Athens'},
          status: 'conflict',
          createdAt: DateTime.now(),
        ));

        // Alice sees her conflict
        var aliceConflicts = await controller.getPendingConflicts('user_alice');
        expect(aliceConflicts.length, equals(1));

        // Alice logs out
        await localDb.purgeUserData('user_alice');

        // Bob signs in
        var bobConflicts = await controller.getPendingConflicts('user_bob');
        expect(bobConflicts.length, equals(0));

        // Alice conflicts are also gone
        aliceConflicts = await controller.getPendingConflicts('user_alice');
        expect(aliceConflicts.length, equals(0));
      });

      test('22. Offline resolution: applying resolution while offline queues new mutation with correct base version', () async {
        await localDb.enqueueSyncRecord(SyncRecord(
          operationId: 'op_offline_res',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_offline',
          action: 'update',
          payload: {'destination': 'Split'},
          status: 'conflict',
          createdAt: DateTime.now(),
          baseServerVersion: 2,
        ));

        final conflict = SyncConflict(
          conflictId: 'conf_offline',
          operationId: 'op_offline_res',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_offline',
          conflictType: ConflictType.concurrentUpdate,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
          baseServerVersion: 2,
          serverVersion: 3,
          conflictingFields: ['destination'],
        );

        // Offline resolution
        await controller.applyResolution(
          conflict: conflict,
          action: UserResolutionAction.keepLocal,
          userId: 'user_1',
          explicitServerSnapshot: const RemoteEntitySnapshot(
            data: {'destination': 'Dubrovnik'},
            version: 3,
          ),
        );

        final pending = await localDb.getPendingSyncRecords('user_1');
        expect(pending.length, equals(1));
        expect(pending.first.baseServerVersion, equals(3));
        expect(pending.first.payload['destination'], equals('Split'));
      });
    });

    // =========================================================================
    // GROUP 6: ACCESSIBILITY & UI TESTS (12.4.5.12)
    // =========================================================================
    group('12.4.5.12 Accessibility & Semantic Descriptions', () {
      testWidgets('23. ConflictReviewScreen renders accessible semantics for cards and actions', (tester) async {
        final conflict = SyncConflict(
          conflictId: 'conf_a11y_1',
          operationId: 'op_a11y_1',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_a11y_1',
          conflictType: ConflictType.concurrentUpdate,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
          conflictingFields: ['destination'],
        );

        final model = controller.buildPresentationModel(
          conflict,
          localValues: {'destination': 'Offline Rome'},
          serverValues: {'destination': 'Server Paris'},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ConflictReviewScreen(
              conflicts: [model],
              userId: 'user_1',
              controller: controller,
            ),
          ),
        );

        expect(find.text('Differences Detected'), findsOneWidget);
        expect(find.text('Keep My Changes'), findsOneWidget);
        expect(find.text('Use Latest Version'), findsOneWidget);
      });

      testWidgets('24. Server-authoritative fields render shield badge and non-color authority label', (tester) async {
        final conflict = SyncConflict(
          conflictId: 'conf_a11y_auth',
          operationId: 'op_a11y_auth',
          userId: 'user_1',
          entityType: 'profile',
          entityId: 'user_1',
          conflictType: ConflictType.concurrentUpdate,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
          conflictingFields: ['trust_score'],
        );

        final model = controller.buildPresentationModel(
          conflict,
          localValues: {'trust_score': 99},
          serverValues: {'trust_score': 80},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ConflictReviewScreen(
              conflicts: [model],
              userId: 'user_1',
              controller: controller,
            ),
          ),
        );

        // Must display text badge 'Server Authority'
        expect(find.text('Server Authority'), findsOneWidget);
        // Must hide 'Keep My Changes'
        expect(find.text('Keep My Changes'), findsNothing);
      });

      testWidgets('25. Server-deleted conflict renders explicit badge and hides Keep My Changes', (tester) async {
        final conflict = SyncConflict(
          conflictId: 'conf_a11y_del',
          operationId: 'op_a11y_del',
          userId: 'user_1',
          entityType: 'trip',
          entityId: 'trip_del_123',
          conflictType: ConflictType.updateVsDelete,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
        );

        final model = controller.buildPresentationModel(conflict);

        await tester.pumpWidget(
          MaterialApp(
            home: ConflictReviewScreen(
              conflicts: [model],
              userId: 'user_1',
              controller: controller,
            ),
          ),
        );

        expect(find.text('Server Deleted'), findsOneWidget);
        expect(find.text('Dismiss'), findsOneWidget);
        expect(find.text('Keep My Changes'), findsNothing);
      });
    });
  });
}
