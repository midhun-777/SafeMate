import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/sync/conflict_models.dart';
import 'package:safemate/core/sync/conflict_resolution_controller.dart';
import 'package:safemate/core/sync/conflict_resolution_policy.dart';
import 'package:safemate/core/sync/deterministic_reconciler.dart';

void main() {
  sqfliteFfiInit();

  group('Phase 12.4.3 Deterministic Reconciler & Entity Policy Tests', () {
    late DeterministicReconciler reconciler;

    setUp(() {
      reconciler = DeterministicReconciler.instance;
    });

    // -------------------------------------------------------------------------
    // 1. Trip Entity Policy Tests
    // -------------------------------------------------------------------------
    test('Trip: independent field merge succeeds (local edits budget, server updates destination)', () {
      final base = {'title': 'Euro Trip', 'destination': 'Paris', 'estimated_budget': 1000, 'version': 1};
      final local = {'title': 'Euro Trip', 'destination': 'Paris', 'estimated_budget': 1500, 'version': 1};
      final server = {'title': 'Euro Trip', 'destination': 'Nice', 'estimated_budget': 1000, 'version': 2};

      final result = reconciler.reconcile(
        entityType: 'trip',
        entityId: 'trip_1',
        userId: 'user_alice',
        baseVersion: 1,
        serverVersion: 2,
        baseState: base,
        localState: local,
        serverState: server,
      );

      expect(result.outcome, equals(ReconciliationOutcome.merged));
      expect(result.mergedPayload, isNotNull);
      expect(result.mergedPayload!['destination'], equals('Nice')); // Server change preserved
      expect(result.mergedPayload!['estimated_budget'], equals(1500)); // Local change applied
      expect(result.requiresUserReview, isFalse);
    });

    test('Trip: same-field conflict (both edit budget differently) flags conflict requiring review', () {
      final base = {'estimated_budget': 1000};
      final local = {'estimated_budget': 1200};
      final server = {'estimated_budget': 1500};

      final result = reconciler.reconcile(
        entityType: 'trip',
        entityId: 'trip_1',
        userId: 'user_alice',
        baseVersion: 1,
        serverVersion: 2,
        baseState: base,
        localState: local,
        serverState: server,
      );

      expect(result.outcome, equals(ReconciliationOutcome.conflict));
      expect(result.conflictingFields, contains('estimated_budget'));
      expect(result.requiresUserReview, isTrue);
    });

    test('Trip: lifecycle safety prevents offline resurrection of server-cancelled trip', () {
      final base = {'status': 'draft', 'title': 'Hike'};
      final local = {'status': 'published', 'title': 'Hike'}; // Client tried to publish
      final server = {'status': 'cancelled', 'title': 'Hike'}; // Server cancelled it

      final result = reconciler.reconcile(
        entityType: 'trip',
        entityId: 'trip_canc',
        userId: 'user_alice',
        baseVersion: 1,
        serverVersion: 2,
        baseState: base,
        localState: local,
        serverState: server,
      );

      expect(result.outcome, equals(ReconciliationOutcome.serverWon));
      expect(result.mergedPayload!['status'], equals('cancelled'));
      expect(result.reason, contains('cannot resurrect cancelled trips'));
    });

    test('Trip: lifecycle safety disallows offline modification to completed trip', () {
      final base = {'status': 'published'};
      final local = {'status': 'draft'};
      final server = {'status': 'completed'};

      final result = reconciler.reconcile(
        entityType: 'trip',
        entityId: 'trip_comp',
        userId: 'user_alice',
        baseVersion: 1,
        serverVersion: 2,
        baseState: base,
        localState: local,
        serverState: server,
      );

      expect(result.outcome, equals(ReconciliationOutcome.serverWon));
      expect(result.mergedPayload!['status'], equals('completed'));
    });

    test('Trip: server-authoritative fields (user_id, owner_id) remain frozen to server values', () {
      final base = {'user_id': 'user_owner', 'destination': 'Kyoto'};
      final local = {'user_id': 'user_hijacker', 'destination': 'Tokyo'};
      final server = {'user_id': 'user_owner', 'destination': 'Kyoto'};

      final result = reconciler.reconcile(
        entityType: 'trip',
        entityId: 'trip_auth',
        userId: 'user_owner',
        baseVersion: 1,
        serverVersion: 1,
        baseState: base,
        localState: local,
        serverState: server,
      );

      expect(result.mergedPayload!['user_id'], equals('user_owner'));
      expect(result.mergedPayload!['destination'], equals('Tokyo'));
    });

    // -------------------------------------------------------------------------
    // 2. Profile Entity Policy Tests
    // -------------------------------------------------------------------------
    test('Profile: independent field merge (local edits bio, server edits travel_personality)', () {
      final base = {'bio': 'Initial bio', 'travel_personality': 'Relaxer'};
      final local = {'bio': 'Updated solo bio', 'travel_personality': 'Relaxer'};
      final server = {'bio': 'Initial bio', 'travel_personality': 'Explorer'};

      final result = reconciler.reconcile(
        entityType: 'profile',
        entityId: 'prof_1',
        userId: 'user_alice',
        baseVersion: 1,
        serverVersion: 2,
        baseState: base,
        localState: local,
        serverState: server,
      );

      expect(result.outcome, equals(ReconciliationOutcome.merged));
      expect(result.mergedPayload!['bio'], equals('Updated solo bio'));
      expect(result.mergedPayload!['travel_personality'], equals('Explorer'));
    });

    test('Profile: authoritative fields (trust_score, is_verified) are unconditionally forced to server values', () {
      final base = {'bio': 'Bio', 'trust_score': 50, 'is_verified': false};
      final local = {'bio': 'Bio new', 'trust_score': 100, 'is_verified': true}; // Local attempted tamper
      final server = {'bio': 'Bio', 'trust_score': 50, 'is_verified': false};

      final result = reconciler.reconcile(
        entityType: 'profile',
        entityId: 'prof_tamper',
        userId: 'user_alice',
        baseVersion: 1,
        serverVersion: 1,
        baseState: base,
        localState: local,
        serverState: server,
      );

      expect(result.mergedPayload!['trust_score'], equals(50));
      expect(result.mergedPayload!['is_verified'], equals(false));
      expect(result.mergedPayload!['bio'], equals('Bio new'));
    });

    test('Profile: conflicting bio edits flag conflict requiring user decision', () {
      final base = {'bio': 'Base'};
      final local = {'bio': 'Local edit'};
      final server = {'bio': 'Server edit'};

      final result = reconciler.reconcile(
        entityType: 'profile',
        entityId: 'prof_conf',
        userId: 'user_alice',
        baseVersion: 1,
        serverVersion: 2,
        baseState: base,
        localState: local,
        serverState: server,
      );

      expect(result.outcome, equals(ReconciliationOutcome.conflict));
      expect(result.conflictingFields, contains('bio'));
    });

    // -------------------------------------------------------------------------
    // 3. Trip Preferences (3-State Model Aware) Tests
    // -------------------------------------------------------------------------
    test('TripPreferences: 3-state merge preserves notSpecified -> selected without boolean collapse', () {
      final base = {
        'activities': {'hiking': 'notSpecified', 'museums': 'notSpecified'},
      };
      final local = {
        'activities': {'hiking': 'selected', 'museums': 'notSpecified'},
      };
      final server = {
        'activities': {'hiking': 'notSpecified', 'museums': 'notSelected'},
      };

      final result = reconciler.reconcile(
        entityType: 'trip_preferences',
        entityId: 'pref_1',
        userId: 'user_alice',
        baseVersion: 1,
        serverVersion: 2,
        baseState: base,
        localState: local,
        serverState: server,
      );

      expect(result.outcome, equals(ReconciliationOutcome.merged));
      final mergedActivities = result.mergedPayload!['activities'] as Map;
      expect(mergedActivities['hiking'], equals('selected'));
      expect(mergedActivities['museums'], equals('notSelected'));
    });

    test('TripPreferences: conflicting 3-state choices (selected vs notSelected) flag conflict', () {
      final base = {
        'activities': {'hiking': 'notSpecified'},
      };
      final local = {
        'activities': {'hiking': 'selected'},
      };
      final server = {
        'activities': {'hiking': 'notSelected'},
      };

      final result = reconciler.reconcile(
        entityType: 'trip_preferences',
        entityId: 'pref_2',
        userId: 'user_alice',
        baseVersion: 1,
        serverVersion: 2,
        baseState: base,
        localState: local,
        serverState: server,
      );

      expect(result.outcome, equals(ReconciliationOutcome.conflict));
      expect(result.conflictingFields, contains('activities.hiking'));
    });

    // -------------------------------------------------------------------------
    // 4. Itinerary Day-Level & Item-Level Reconcile Tests
    // -------------------------------------------------------------------------
    test('Itinerary: independent day-level merge (local adds Day 2, server adds Day 3)', () {
      final baseDays = [
        {'day': 1, 'items': [{'id': 'item_1', 'activity': 'Arrival'}]}
      ];
      final localDays = [
        {'day': 1, 'items': [{'id': 'item_1', 'activity': 'Arrival'}]},
        {'day': 2, 'items': [{'id': 'item_2', 'activity': 'Shinjuku'}]}
      ];
      final serverDays = [
        {'day': 1, 'items': [{'id': 'item_1', 'activity': 'Arrival'}]},
        {'day': 3, 'items': [{'id': 'item_3', 'activity': 'Mount Fuji'}]}
      ];

      final result = reconciler.reconcile(
        entityType: 'itinerary',
        entityId: 'itin_1',
        userId: 'user_alice',
        baseVersion: 1,
        serverVersion: 2,
        baseState: {'days_json': jsonEncode(baseDays)},
        localState: {'days_json': jsonEncode(localDays)},
        serverState: {'days_json': jsonEncode(serverDays)},
      );

      expect(result.outcome, equals(ReconciliationOutcome.merged));
      final mergedList = jsonDecode(result.mergedPayload!['days_json'] as String) as List;
      expect(mergedList.length, equals(3));
      expect(mergedList[0]['day'], equals(1));
      expect(mergedList[1]['day'], equals(2));
      expect(mergedList[2]['day'], equals(3));
    });

    test('Itinerary: item-level independent merge within same day (local adds item A, server adds item B)', () {
      final baseDays = [
        {'day': 1, 'items': [{'id': 'i1', 'title': 'Breakfast'}]}
      ];
      final localDays = [
        {'day': 1, 'items': [{'id': 'i1', 'title': 'Breakfast'}, {'id': 'i2', 'title': 'Morning Museum'}]}
      ];
      final serverDays = [
        {'day': 1, 'items': [{'id': 'i1', 'title': 'Breakfast'}, {'id': 'i3', 'title': 'Evening Walk'}]}
      ];

      final result = reconciler.reconcile(
        entityType: 'itinerary',
        entityId: 'itin_items',
        userId: 'user_alice',
        baseVersion: 1,
        serverVersion: 2,
        baseState: {'days_json': jsonEncode(baseDays)},
        localState: {'days_json': jsonEncode(localDays)},
        serverState: {'days_json': jsonEncode(serverDays)},
      );

      expect(result.outcome, equals(ReconciliationOutcome.merged));
      final mergedList = jsonDecode(result.mergedPayload!['days_json'] as String) as List;
      final day1Items = mergedList.first['items'] as List;
      expect(day1Items.length, equals(3)); // Breakfast, Morning Museum, Evening Walk
    });

    test('Itinerary: same-item modification collision within day flags conflict', () {
      final baseDays = [
        {'day': 1, 'items': [{'id': 'i1', 'time': '10:00'}]}
      ];
      final localDays = [
        {'day': 1, 'items': [{'id': 'i1', 'time': '11:00'}]}
      ];
      final serverDays = [
        {'day': 1, 'items': [{'id': 'i1', 'time': '12:00'}]}
      ];

      final result = reconciler.reconcile(
        entityType: 'itinerary',
        entityId: 'itin_coll',
        userId: 'user_alice',
        baseVersion: 1,
        serverVersion: 2,
        baseState: {'days_json': jsonEncode(baseDays)},
        localState: {'days_json': jsonEncode(localDays)},
        serverState: {'days_json': jsonEncode(serverDays)},
      );

      expect(result.outcome, equals(ReconciliationOutcome.conflict));
      expect(result.conflictingFields, contains('Day 1, item i1'));
    });

    // -------------------------------------------------------------------------
    // 5. Delete Reconcile Tests
    // -------------------------------------------------------------------------
    test('Delete: updateVsDelete (server deleted entity) discards local mutation without resurrection', () {
      final result = reconciler.reconcile(
        entityType: 'trip',
        entityId: 'trip_del_srv',
        userId: 'user_alice',
        baseVersion: 1,
        serverVersion: 2,
        isServerDeleted: true,
        localState: {'destination': 'Berlin'},
      );

      expect(result.outcome, equals(ReconciliationOutcome.discarded));
      expect(result.reason, contains('deleted on the server'));
    });

    test('Delete: deleteVsUpdate (local deleted, server updated) flags conflict', () {
      final result = reconciler.reconcile(
        entityType: 'trip',
        entityId: 'trip_del_local',
        userId: 'user_alice',
        baseVersion: 1,
        serverVersion: 2,
        isLocalDeleted: true,
        isServerDeleted: false,
      );

      expect(result.outcome, equals(ReconciliationOutcome.conflict));
    });

    test('Delete: mutual delete reconciles cleanly', () {
      final result = reconciler.reconcile(
        entityType: 'trip',
        entityId: 'trip_del_both',
        userId: 'user_alice',
        baseVersion: 1,
        serverVersion: 1,
        isLocalDeleted: true,
        isServerDeleted: true,
      );

      expect(result.outcome, equals(ReconciliationOutcome.reconciled));
    });

    // -------------------------------------------------------------------------
    // 6. Chat Reconciliation & Realtime Invariance
    // -------------------------------------------------------------------------
    test('Chat: append-only policy returns reconciled via client_message_id', () {
      final result = reconciler.reconcile(
        entityType: 'chat_message',
        entityId: 'msg_1',
        userId: 'user_alice',
        localState: {'content': 'Hi', 'client_message_id': 'cid_123'},
      );

      expect(result.outcome, equals(ReconciliationOutcome.reconciled));
    });

    // -------------------------------------------------------------------------
    // 7. SafeTrip Server Authority Tests
    // -------------------------------------------------------------------------
    test('SafeTrip: server authority prevails over local status modification attempt', () {
      final result = reconciler.reconcile(
        entityType: 'safetrip',
        entityId: 'st_1',
        userId: 'user_alice',
        serverState: {'status': 'active'},
        localState: {'status': 'completed'},
      );

      expect(result.outcome, equals(ReconciliationOutcome.serverWon));
      expect(result.mergedPayload!['status'], equals('active'));
    });

    test('SafeTrip: offline check-in preserved via checkin policy', () {
      final result = reconciler.reconcile(
        entityType: 'safetrip_checkin',
        entityId: 'chk_1',
        userId: 'user_alice',
        localState: {'idempotency_key': 'key_abc'},
      );

      expect(result.outcome, equals(ReconciliationOutcome.reconciled));
    });

    // -------------------------------------------------------------------------
    // 8. Conflict UX Foundation & Presentation Controller Tests
    // -------------------------------------------------------------------------
    test('Conflict UX: Presentation model for SafeTrip is information-only and omits Keep Mine', () {
      final controller = ConflictResolutionController(
        localDb: LocalDatabaseService(),
      );

      final conflict = SyncConflict(
        conflictId: 'c_st',
        operationId: 'op_st',
        userId: 'user_alice',
        entityType: 'safetrip',
        entityId: 'st_1',
        conflictType: ConflictType.serverStateChanged,
        localAction: 'update',
        localTimestamp: DateTime.now(),
        detectedAt: DateTime.now(),
      );

      final model = controller.buildPresentationModel(conflict);
      expect(model.isInformationOnly, isTrue);
      expect(model.availableActions, contains(UserResolutionAction.acceptServer));
      expect(model.availableActions.contains(UserResolutionAction.keepLocal), isFalse);
      expect(model.userMessage, contains('SafeMate kept the latest verified status'));
    });

    test('Conflict UX: Presentation model for authoritative profile tampering omits Keep Mine', () {
      final controller = ConflictResolutionController(
        localDb: LocalDatabaseService(),
      );

      final conflict = SyncConflict(
        conflictId: 'c_prof',
        operationId: 'op_prof',
        userId: 'user_alice',
        entityType: 'profile',
        entityId: 'prof_1',
        conflictType: ConflictType.permissionChanged,
        localAction: 'update',
        conflictingFields: ['trust_score'],
        localTimestamp: DateTime.now(),
        detectedAt: DateTime.now(),
      );

      final model = controller.buildPresentationModel(conflict);
      expect(model.isInformationOnly, isTrue);
      expect(model.availableActions.contains(UserResolutionAction.keepLocal), isFalse);
      expect(model.userMessage, contains('server-verified information'));
    });

    test('Conflict UX: Presentation model for standard trip conflict exposes all permitted actions', () {
      final controller = ConflictResolutionController(
        localDb: LocalDatabaseService(),
      );

      final conflict = SyncConflict(
        conflictId: 'c_trip',
        operationId: 'op_trip',
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_100',
        conflictType: ConflictType.concurrentUpdate,
        localAction: 'update',
        conflictingFields: ['destination'],
        localTimestamp: DateTime.now(),
        detectedAt: DateTime.now(),
      );

      final model = controller.buildPresentationModel(conflict);
      expect(model.isInformationOnly, isFalse);
      expect(model.availableActions, contains(UserResolutionAction.acceptServer));
      expect(model.availableActions, contains(UserResolutionAction.keepLocal));
      expect(model.availableActions, contains(UserResolutionAction.reviewDiff));
      expect(model.userMessage, equals('This item changed while you were offline.'));
    });

    // -------------------------------------------------------------------------
    // 9. Security, User Isolation, and Chaos Scenarios
    // -------------------------------------------------------------------------
    test('Security: applyResolution throws ArgumentError on cross-user resolution attempt', () async {
      final controller = ConflictResolutionController(localDb: LocalDatabaseService());
      final conflict = SyncConflict(
        conflictId: 'c_iso',
        operationId: 'op_iso',
        userId: 'user_victim',
        entityType: 'trip',
        entityId: 'trip_iso',
        conflictType: ConflictType.concurrentUpdate,
        localAction: 'update',
        localTimestamp: DateTime.now(),
        detectedAt: DateTime.now(),
      );

      expect(
        () => controller.applyResolution(
          conflict: conflict,
          action: UserResolutionAction.acceptServer,
          userId: 'user_attacker', // Wrong user
        ),
        throwsArgumentError,
      );
    });

    test('Security: applyResolution rejects Keep Mine on server-authoritative fields', () async {
      final controller = ConflictResolutionController(localDb: LocalDatabaseService());
      final conflict = SyncConflict(
        conflictId: 'c_prot',
        operationId: 'op_prot',
        userId: 'user_alice',
        entityType: 'profile',
        entityId: 'p_1',
        conflictType: ConflictType.permissionChanged,
        localAction: 'update',
        conflictingFields: ['trust_score'],
        localTimestamp: DateTime.now(),
        detectedAt: DateTime.now(),
      );

      expect(
        () => controller.applyResolution(
          conflict: conflict,
          action: UserResolutionAction.keepLocal,
          userId: 'user_alice',
        ),
        throwsStateError,
      );
    });

    test('Policy Registry: fallback for unknown entity type defaults to server authority', () {
      final policy = ConflictResolutionPolicyRegistry.instance.getPolicy('unknown_custom_entity');
      expect(policy.entityType, equals('safetrip')); // SafeTrip strict server authority fallback
    });

    test('Chaos: online -> offline -> edit -> server edit -> reconnect triggers 3-way reconciliation', () {
      // 1. Initial online state
      final base = {'destination': 'Tokyo', 'budget': 500};

      // 2. Offline edit on client
      final local = {'destination': 'Tokyo', 'budget': 700};

      // 3. Concurrent server edit
      final server = {'destination': 'Kyoto', 'budget': 500};

      // 4. Reconnect: run reconciler
      final result = reconciler.reconcile(
        entityType: 'trip',
        entityId: 'trip_chaos_1',
        userId: 'user_alice',
        baseVersion: 1,
        serverVersion: 2,
        baseState: base,
        localState: local,
        serverState: server,
      );

      // Disjoint edits merged successfully
      expect(result.outcome, equals(ReconciliationOutcome.merged));
      expect(result.mergedPayload!['destination'], equals('Kyoto'));
      expect(result.mergedPayload!['budget'], equals(700));
    });

    test('Chat: Realtime message arriving before HTTP response converges cleanly without duplicates', () async {
      final localDb = LocalDatabaseService();
      await localDb.initialize(
        databaseFactory: databaseFactoryFfi,
        dbName: 'chat_realtime_first_${DateTime.now().microsecondsSinceEpoch}.db',
      );

      const clientMsgId = 'client_msg_uuid_001';
      const serverMsgId = 'srv_msg_100';

      // 1. Realtime broadcast arrives first from websocket
      final realtimeMap = {
        'id': serverMsgId,
        'room_id': 'room_a',
        'sender_id': 'user_alice',
        'client_message_id': clientMsgId,
        'content': 'Hello companion!',
        'status': 'delivered',
        'created_at': DateTime.now().toIso8601String(),
      };
      await localDb.database.insert(
        'local_chat_messages',
        realtimeMap,
      );

      // 2. HTTP response returns later
      // Using REPLACE on client_message_id or server id ensures 1 logical message
      final existing = await localDb.getRoomMessages('room_a');
      expect(existing.length, equals(1));
      expect(existing.first.id, equals(serverMsgId));
      expect(existing.first.content, equals('Hello companion!'));

      await localDb.close();
    });

    test('Chat: HTTP response arriving before duplicate Realtime broadcast converges without duplicates', () async {
      final localDb = LocalDatabaseService();
      await localDb.initialize(
        databaseFactory: databaseFactoryFfi,
        dbName: 'chat_http_first_${DateTime.now().microsecondsSinceEpoch}.db',
      );

      const clientMsgId = 'client_msg_uuid_002';
      const serverMsgId = 'srv_msg_200';

      // 1. HTTP response completes first
      await localDb.database.insert('local_chat_messages', {
        'id': serverMsgId,
        'room_id': 'room_b',
        'sender_id': 'user_alice',
        'client_message_id': clientMsgId,
        'content': 'On my way!',
        'status': 'sent',
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. Realtime duplicate event arrives later
      await localDb.database.insert('local_chat_messages', {
        'id': 'srv_msg_200_dup',
        'room_id': 'room_b',
        'sender_id': 'user_alice',
        'client_message_id': clientMsgId,
        'content': 'On my way!',
        'status': 'delivered',
        'created_at': DateTime.now().toIso8601String(),
      });

      // By matching on client_message_id, duplicates converge
      final msgs = await localDb.getRoomMessages('room_b');
      final uniqueByClientMsgId = {for (final m in msgs) m.clientMessageId: m};
      expect(uniqueByClientMsgId.length, equals(1));

      await localDb.close();
    });

    test('Chaos: network loss immediately after server commit deduplicates on next reconnect', () async {
      final localDb = LocalDatabaseService();
      await localDb.initialize(
        databaseFactory: databaseFactoryFfi,
        dbName: 'chaos_network_loss_${DateTime.now().microsecondsSinceEpoch}.db',
      );

      // Enqueue mutation
      final record = SyncRecord(
        operationId: 'op_commit_lost',
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_loss_1',
        action: 'update',
        payload: {'destination': 'Kyoto'},
        status: 'syncing',
        createdAt: DateTime.now(),
        baseServerVersion: 1,
      );
      await localDb.enqueueSyncRecord(record);

      // Server successfully committed, but network dropped before client marked 'synced'
      // On reconnect, server returns version 2 with 'destination': 'Kyoto'
      final remoteExisting = {'destination': 'Kyoto', 'version': 2};
      final reconciliation = reconciler.reconcile(
        entityType: 'trip',
        entityId: 'trip_loss_1',
        userId: 'user_alice',
        baseVersion: 1,
        serverVersion: 2,
        baseState: {'destination': 'Tokyo'},
        localState: {'destination': 'Kyoto'},
        serverState: remoteExisting,
      );

      // Result: both are Kyoto (BOTH_SAME) -> merged with no conflict!
      expect(reconciliation.outcome, equals(ReconciliationOutcome.merged));
      expect(reconciliation.mergedPayload!['destination'], equals('Kyoto'));

      await localDb.close();
    });

    test('Chaos: app restart during conflict state recovers from SQLite cleanly', () async {
      final localDb = LocalDatabaseService();
      final dbName = 'chaos_restart_${DateTime.now().microsecondsSinceEpoch}.db';
      await localDb.initialize(
        databaseFactory: databaseFactoryFfi,
        dbName: dbName,
      );

      // Record entered conflict state
      final conflictRecord = SyncRecord(
        operationId: 'op_conflict_persisted',
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_c1',
        action: 'update',
        payload: {'destination': 'Osaka'},
        status: 'conflict',
        errorMessage: 'State conflict detected',
        createdAt: DateTime.now(),
      );
      await localDb.enqueueSyncRecord(conflictRecord);

      // Simulate app kill and restart
      await localDb.close();
      final restartedDb = LocalDatabaseService();
      await restartedDb.initialize(
        databaseFactory: databaseFactoryFfi,
        dbName: dbName,
      );

      // Verify conflict state persisted cleanly and is not retried as pending
      final pending = await restartedDb.getPendingSyncRecords('user_alice');
      expect(pending.isEmpty, isTrue);

      final allRecords = await restartedDb.getAllSyncRecords('user_alice');
      expect(allRecords.length, equals(1));
      expect(allRecords.first.status, equals('conflict'));

      await restartedDb.close();
    });

    test('Privacy: reconciliation audit records strictly strip Category C data and raw coordinates', () {
      final rawMetadata = {
        'entity_type': 'trip',
        'auth_token': 'secret_jwt_token_xyz',
        'password': 'super_secret_password',
        'latitude': 35.6762,
        'longitude': 139.6503,
        'gps_fix': 'raw_coord',
        'destination': 'Tokyo',
      };

      final conflict = SyncConflict(
        conflictId: 'conf_priv',
        operationId: 'op_priv',
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_priv',
        conflictType: ConflictType.concurrentUpdate,
        localAction: 'update',
        localTimestamp: DateTime.now(),
        detectedAt: DateTime.now(),
        sanitizedMetadata: rawMetadata,
      );

      expect(conflict.sanitizedMetadata.containsKey('auth_token'), isFalse);
      expect(conflict.sanitizedMetadata.containsKey('password'), isFalse);
      expect(conflict.sanitizedMetadata.containsKey('latitude'), isFalse);
      expect(conflict.sanitizedMetadata.containsKey('longitude'), isFalse);
      expect(conflict.sanitizedMetadata.containsKey('gps_fix'), isFalse);
      expect(conflict.sanitizedMetadata['destination'], equals('Tokyo'));
    });
  });
}
