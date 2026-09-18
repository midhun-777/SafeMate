import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/sync/conflict_models.dart';
import 'package:safemate/core/sync/deterministic_conflict_detector.dart';

void main() {
  group('Phase 12.4.2 Deterministic Conflict Detector Tests', () {
    final fixedLocalTime = DateTime.utc(2026, 9, 17, 12, 0, 0);
    final fixedServerTime = DateTime.utc(2026, 9, 17, 12, 5, 0);

    // ------------------------------------------------------------------------
    // 1. Core Version Optimistic Concurrency Rules
    // ------------------------------------------------------------------------
    test('no conflict when local.baseServerVersion == server.version and fields match', () {
      final input = ConflictDetectionInput(
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_100',
        operation: EntityOperation.update,
        localBaseVersion: 10,
        localRevision: 1,
        serverVersion: 10,
        baseState: {'destination': 'Tokyo', 'estimated_budget': 1000},
        localState: {'destination': 'Kyoto', 'estimated_budget': 1000},
        serverState: {'destination': 'Tokyo', 'estimated_budget': 1000},
        localTimestamp: fixedLocalTime,
        serverTimestamp: fixedServerTime,
      );

      final result = DeterministicConflictDetector.detectConflict(input);
      expect(result.hasConflict, isFalse);
      expect(result.conflictType, isNull);
      expect(result.threeWayComparison, isNotNull);
      expect(result.threeWayComparison!.localOnlyFields, contains('destination'));
      expect(result.threeWayComparison!.hasConflicts, isFalse);
    });

    test('stale base detected when local.baseServerVersion < server.version', () {
      final input = ConflictDetectionInput(
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_100',
        operation: EntityOperation.update,
        localBaseVersion: 10,
        localRevision: 1,
        serverVersion: 11,
        baseState: {'destination': 'Tokyo'},
        localState: {'destination': 'Kyoto'},
        serverState: {'destination': 'Osaka'},
        localTimestamp: fixedLocalTime,
        serverTimestamp: fixedServerTime,
      );

      final result = DeterministicConflictDetector.detectConflict(input);
      expect(result.hasConflict, isTrue);
      expect(result.conflictType, equals(ConflictType.staleBase));
      expect(result.conflict, isNotNull);
      expect(result.conflict!.baseServerVersion, equals(10));
      expect(result.conflict!.serverVersion, equals(11));
      expect(result.reason, contains('Stale base version'));
    });

    test('concurrent update scenario: Device A advances server to 11, Device B syncs base 10', () {
      // Device A synced successfully and bumped server to 11
      const serverVersionAfterDeviceA = 11;

      // Device B was offline with base 10
      final deviceBInput = ConflictDetectionInput(
        userId: 'user_bob',
        entityType: 'trip',
        entityId: 'trip_shared',
        operation: EntityOperation.update,
        localBaseVersion: 10,
        localRevision: 2,
        serverVersion: serverVersionAfterDeviceA,
        baseState: {'title': 'Original Trip'},
        localState: {'title': 'Bob Local Edit'},
        serverState: {'title': 'Alice Remote Edit'},
        localTimestamp: fixedLocalTime,
        serverTimestamp: fixedServerTime,
      );

      final result = DeterministicConflictDetector.detectConflict(deviceBInput);
      expect(result.hasConflict, isTrue);
      expect(result.conflictType, equals(ConflictType.staleBase));
      expect(result.conflict!.baseServerVersion, equals(10));
      expect(result.conflict!.serverVersion, equals(11));
      expect(result.conflict!.userId, equals('user_bob'));
    });

    test('invalid or future base version flags concurrentUpdate conflict', () {
      final input = ConflictDetectionInput(
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_100',
        operation: EntityOperation.update,
        localBaseVersion: 15,
        serverVersion: 10,
        localTimestamp: fixedLocalTime,
      );

      final result = DeterministicConflictDetector.detectConflict(input);
      expect(result.hasConflict, isTrue);
      expect(result.conflictType, equals(ConflictType.concurrentUpdate));
      expect(result.reason, contains('exceeds current server version'));
    });

    // ------------------------------------------------------------------------
    // 2. Delete Conflict Matrix (Cases A, B, C)
    // ------------------------------------------------------------------------
    test('Case A: local update + server deleted -> updateVsDelete', () {
      final input = ConflictDetectionInput(
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_deleted_on_server',
        operation: EntityOperation.update,
        localBaseVersion: 2,
        serverVersion: 3,
        isServerDeleted: true,
        localState: {'destination': 'Paris'},
        localTimestamp: fixedLocalTime,
      );

      final result = DeterministicConflictDetector.detectConflict(input);
      expect(result.hasConflict, isTrue);
      expect(result.conflictType, equals(ConflictType.updateVsDelete));
      expect(result.conflict!.serverAction, equals('deleted'));
      expect(result.reason, contains('deleted on the server'));
    });

    test('Case B: local delete + server updated -> deleteVsUpdate', () {
      final input = ConflictDetectionInput(
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_modified_on_server',
        operation: EntityOperation.delete,
        isLocalDeleted: true,
        localBaseVersion: 2,
        serverVersion: 3,
        isServerDeleted: false,
        localTimestamp: fixedLocalTime,
      );

      final result = DeterministicConflictDetector.detectConflict(input);
      expect(result.hasConflict, isTrue);
      expect(result.conflictType, equals(ConflictType.deleteVsUpdate));
      expect(result.conflict!.serverAction, equals('updated'));
      expect(result.reason, contains('server entity was updated concurrently'));
    });

    test('Case C: mutual delete (local and server both deleted) -> reconciled without conflict', () {
      final input = ConflictDetectionInput(
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_both_deleted',
        operation: EntityOperation.delete,
        isLocalDeleted: true,
        isServerDeleted: true,
        localBaseVersion: 2,
        serverVersion: 2,
        localTimestamp: fixedLocalTime,
      );

      final result = DeterministicConflictDetector.detectConflict(input);
      expect(result.hasConflict, isFalse);
      expect(result.isReconciled, isTrue);
      expect(result.reason, contains('reconciled without conflict'));
    });

    test('Case D: local delete matching server version executes cleanly with no conflict', () {
      final input = ConflictDetectionInput(
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_clean_delete',
        operation: EntityOperation.delete,
        isLocalDeleted: true,
        localBaseVersion: 5,
        serverVersion: 5,
        isServerDeleted: false,
        localTimestamp: fixedLocalTime,
      );

      final result = DeterministicConflictDetector.detectConflict(input);
      expect(result.hasConflict, isFalse);
      expect(result.reason, contains('safe to delete'));
    });

    // ------------------------------------------------------------------------
    // 3. Three-Way Field Difference Engine
    // ------------------------------------------------------------------------
    test('three-way diff correctly categorizes UNCHANGED, LOCAL_ONLY, SERVER_ONLY, BOTH_SAME, BOTH_DIFFERENT', () {
      final base = {
        'field_unchanged': 'A',
        'field_local_only': 'B',
        'field_server_only': 'C',
        'field_both_same': 'D',
        'field_conflict': 'E',
      };

      final local = {
        'field_unchanged': 'A',
        'field_local_only': 'B_modified',
        'field_server_only': 'C',
        'field_both_same': 'D_converged',
        'field_conflict': 'E_local',
      };

      final server = {
        'field_unchanged': 'A',
        'field_local_only': 'B',
        'field_server_only': 'C_remote',
        'field_both_same': 'D_converged',
        'field_conflict': 'E_remote',
      };

      final threeWay = DeterministicConflictDetector.compareThreeWay(
        base,
        local,
        server,
        entityType: 'trip',
      );

      expect(threeWay.differences['field_unchanged']!.changeType, equals(FieldChangeType.unchanged));
      expect(threeWay.differences['field_local_only']!.changeType, equals(FieldChangeType.localOnly));
      expect(threeWay.differences['field_server_only']!.changeType, equals(FieldChangeType.serverOnly));
      expect(threeWay.differences['field_both_same']!.changeType, equals(FieldChangeType.bothSame));
      expect(threeWay.differences['field_conflict']!.changeType, equals(FieldChangeType.bothDifferent));

      expect(threeWay.conflictingFields, equals(['field_conflict']));
      expect(threeWay.localOnlyFields, equals(['field_local_only']));
      expect(threeWay.serverOnlyFields, equals(['field_server_only']));
      expect(threeWay.bothSameFields, equals(['field_both_same']));
      expect(threeWay.hasConflicts, isTrue);
    });

    test('three-way diff on Trip entity correctly handles scalar and collection fields', () {
      final base = {
        'origin': 'Tokyo',
        'destination': 'Kyoto',
        'estimated_budget': 10000,
        'transport_mode': 'train',
      };

      final local = {
        'origin': 'Tokyo',
        'destination': 'Osaka', // Local changed
        'estimated_budget': 12000, // Both changed differently
        'transport_mode': 'flight', // Both changed to same
      };

      final server = {
        'origin': 'Tokyo',
        'destination': 'Kyoto', // Unchanged on server
        'estimated_budget': 15000, // Both changed differently
        'transport_mode': 'flight', // Both changed to same
      };

      final diff = DeterministicConflictDetector.compareThreeWay(base, local, server, entityType: 'trip');
      expect(diff.localOnlyFields, contains('destination'));
      expect(diff.bothSameFields, contains('transport_mode'));
      expect(diff.conflictingFields, contains('estimated_budget'));
      expect(diff.hasConflicts, isTrue);
    });

    test('three-way diff on Itinerary entity with day and activity items', () {
      final base = {
        'title': 'Tokyo Tour',
        'days_json': '[{"day": 1, "activity": "Shinjuku"}]',
      };

      final local = {
        'title': 'Tokyo Tour Extended', // Local changed
        'days_json': '[{"day": 1, "activity": "Shinjuku"}, {"day": 2, "activity": "Shibuya"}]',
      };

      final server = {
        'title': 'Tokyo Tour',
        'days_json': '[{"day": 1, "activity": "Shinjuku"}, {"day": 2, "activity": "Asakusa"}]',
      };

      final diff = DeterministicConflictDetector.compareThreeWay(base, local, server, entityType: 'itinerary');
      expect(diff.localOnlyFields, contains('title'));
      expect(diff.conflictingFields, contains('days_json'));
      expect(diff.hasConflicts, isTrue);
    });

    test('three-way diff on Profile entity detects conflicting bio but identical display_name', () {
      final base = {'display_name': 'Alice', 'bio': 'Solo explorer', 'home_city': 'London'};
      final local = {'display_name': 'Alice Wonder', 'bio': 'Solo mountaineer', 'home_city': 'London'};
      final server = {'display_name': 'Alice Wonder', 'bio': 'Hiker & photographer', 'home_city': 'London'};

      final diff = DeterministicConflictDetector.compareThreeWay(base, local, server, entityType: 'profile');
      expect(diff.bothSameFields, contains('display_name'));
      expect(diff.conflictingFields, contains('bio'));
      expect(diff.differences['home_city']!.changeType, equals(FieldChangeType.unchanged));
      expect(diff.hasConflicts, isTrue);
    });

    // ------------------------------------------------------------------------
    // 4. Server-Authoritative State & Security Detection
    // ------------------------------------------------------------------------
    test('local attempt to modify trust_score is rejected as permissionChanged', () {
      final input = ConflictDetectionInput(
        userId: 'user_attacker',
        entityType: 'profile',
        entityId: 'user_attacker',
        operation: EntityOperation.update,
        localBaseVersion: 5,
        serverVersion: 5,
        baseState: {'display_name': 'Eve', 'trust_score': 50},
        localState: {'display_name': 'Eve', 'trust_score': 100}, // Unauthorized alteration!
        serverState: {'display_name': 'Eve', 'trust_score': 50},
        localTimestamp: fixedLocalTime,
      );

      final result = DeterministicConflictDetector.detectConflict(input);
      expect(result.hasConflict, isTrue);
      expect(result.conflictType, equals(ConflictType.permissionChanged));
      expect(result.conflict!.conflictingFields, contains('trust_score'));
      expect(result.reason, contains('server-authoritative protected fields'));
    });

    test('local attempt to modify is_verified or verification_status is rejected', () {
      final input = ConflictDetectionInput(
        userId: 'user_attacker',
        entityType: 'profile',
        entityId: 'user_attacker',
        operation: EntityOperation.update,
        localBaseVersion: 2,
        serverVersion: 2,
        baseState: {'display_name': 'Malory', 'is_verified': false},
        localState: {'display_name': 'Malory', 'is_verified': true},
        serverState: {'display_name': 'Malory', 'is_verified': false},
        localTimestamp: fixedLocalTime,
      );

      final result = DeterministicConflictDetector.detectConflict(input);
      expect(result.hasConflict, isTrue);
      expect(result.conflictType, equals(ConflictType.permissionChanged));
      expect(result.conflict!.conflictingFields, contains('is_verified'));
    });

    test('local attempt to modify moderation_state or is_suspended is rejected', () {
      final input = ConflictDetectionInput(
        userId: 'user_attacker',
        entityType: 'profile',
        entityId: 'user_attacker',
        operation: EntityOperation.update,
        localBaseVersion: 1,
        serverVersion: 1,
        baseState: {'moderation_state': 'flagged', 'is_suspended': true},
        localState: {'moderation_state': 'approved', 'is_suspended': false},
        serverState: {'moderation_state': 'flagged', 'is_suspended': true},
        localTimestamp: fixedLocalTime,
      );

      final result = DeterministicConflictDetector.detectConflict(input);
      expect(result.hasConflict, isTrue);
      expect(result.conflictType, equals(ConflictType.permissionChanged));
      expect(result.conflict!.conflictingFields, contains('moderation_state'));
      expect(result.conflict!.conflictingFields, contains('is_suspended'));
    });

    test('local attempt to modify user_id / owner_id in trip is rejected', () {
      final input = ConflictDetectionInput(
        userId: 'user_attacker',
        entityType: 'trip',
        entityId: 'trip_100',
        operation: EntityOperation.update,
        localBaseVersion: 3,
        serverVersion: 3,
        baseState: {'user_id': 'user_alice', 'destination': 'Kyoto'},
        localState: {'user_id': 'user_attacker', 'destination': 'Kyoto'}, // Unauthorized hijack!
        serverState: {'user_id': 'user_alice', 'destination': 'Kyoto'},
        localTimestamp: fixedLocalTime,
      );

      final result = DeterministicConflictDetector.detectConflict(input);
      expect(result.hasConflict, isTrue);
      expect(result.conflictType, equals(ConflictType.permissionChanged));
      expect(result.conflict!.conflictingFields, contains('user_id'));
    });

    // ------------------------------------------------------------------------
    // 5. Clock-Skew Invariance
    // ------------------------------------------------------------------------
    test('clock skew invariance: +1 day device clock produces identical conflict result', () {
      final standardInput = ConflictDetectionInput(
        userId: 'user_skew',
        entityType: 'trip',
        entityId: 'trip_skew_1',
        operation: EntityOperation.update,
        localBaseVersion: 3,
        serverVersion: 4,
        localTimestamp: fixedLocalTime,
        serverTimestamp: fixedServerTime,
      );

      final skewedPlusOneDayInput = ConflictDetectionInput(
        userId: 'user_skew',
        entityType: 'trip',
        entityId: 'trip_skew_1',
        operation: EntityOperation.update,
        localBaseVersion: 3,
        serverVersion: 4,
        localTimestamp: fixedLocalTime.add(const Duration(days: 1)), // +1 day clock skew
        serverTimestamp: fixedServerTime,
      );

      final r1 = DeterministicConflictDetector.detectConflict(standardInput);
      final r2 = DeterministicConflictDetector.detectConflict(skewedPlusOneDayInput);

      expect(r1.hasConflict, equals(r2.hasConflict));
      expect(r1.conflictType, equals(r2.conflictType));
      expect(r1.conflictType, equals(ConflictType.staleBase));
    });

    test('clock skew invariance: -1 day device clock produces identical conflict result', () {
      final skewedMinusOneDayInput = ConflictDetectionInput(
        userId: 'user_skew',
        entityType: 'trip',
        entityId: 'trip_skew_1',
        operation: EntityOperation.update,
        localBaseVersion: 3,
        serverVersion: 4,
        localTimestamp: fixedLocalTime.subtract(const Duration(days: 1)), // -1 day clock skew
        serverTimestamp: fixedServerTime,
      );

      final result = DeterministicConflictDetector.detectConflict(skewedMinusOneDayInput);
      expect(result.hasConflict, isTrue);
      expect(result.conflictType, equals(ConflictType.staleBase));
    });

    test('clock skew invariance: +1 year device clock produces identical conflict result', () {
      final skewedPlusOneYearInput = ConflictDetectionInput(
        userId: 'user_skew',
        entityType: 'trip',
        entityId: 'trip_skew_1',
        operation: EntityOperation.update,
        localBaseVersion: 3,
        serverVersion: 4,
        localTimestamp: fixedLocalTime.add(const Duration(days: 365)), // +1 year
        serverTimestamp: fixedServerTime,
      );

      final result = DeterministicConflictDetector.detectConflict(skewedPlusOneYearInput);
      expect(result.hasConflict, isTrue);
      expect(result.conflictType, equals(ConflictType.staleBase));
    });

    test('clock skew invariance: divergent timezones produce identical conflict result', () {
      final localTzDate = DateTime.parse('2026-09-17T20:00:00+08:00');
      final serverUtcDate = DateTime.parse('2026-09-17T12:00:00Z');

      final input = ConflictDetectionInput(
        userId: 'user_tz',
        entityType: 'trip',
        entityId: 'trip_tz_1',
        operation: EntityOperation.update,
        localBaseVersion: 2,
        serverVersion: 2,
        baseState: {'destination': 'Rome'},
        localState: {'destination': 'Florence'},
        serverState: {'destination': 'Rome'},
        localTimestamp: localTzDate,
        serverTimestamp: serverUtcDate,
      );

      final result = DeterministicConflictDetector.detectConflict(input);
      expect(result.hasConflict, isFalse);
    });

    // ------------------------------------------------------------------------
    // 6. Domain Boundary Exclusions (Chat & SafeTrip)
    // ------------------------------------------------------------------------
    test('chat exclusion: chat messages use client_message_id and bypass 3-way conflict', () {
      final input = ConflictDetectionInput(
        userId: 'user_chat',
        entityType: 'chat_message',
        entityId: 'msg_temp_1',
        operation: EntityOperation.create,
        clientMessageId: 'client_msg_uuid_999',
        localState: {'content': 'Hello, are you available?', 'client_message_id': 'client_msg_uuid_999'},
        localTimestamp: fixedLocalTime,
      );

      final result = DeterministicConflictDetector.detectConflict(input);
      expect(result.hasConflict, isFalse);
      expect(result.isExcludedFromConflictResolution, isTrue);
      expect(result.reason, contains('client_message_id: client_msg_uuid_999'));
    });

    test('SafeTrip exclusion: server status authority cannot be overridden by local client', () {
      final input = ConflictDetectionInput(
        userId: 'user_safetrip',
        entityType: 'safetrip',
        entityId: 'st_123',
        operation: EntityOperation.update,
        localBaseVersion: 1,
        serverVersion: 1,
        baseState: {'status': 'active'},
        localState: {'status': 'completed'}, // Client claims completed while offline
        serverState: {'status': 'active'}, // Server is still active
        localTimestamp: fixedLocalTime,
      );

      final result = DeterministicConflictDetector.detectConflict(input);
      expect(result.hasConflict, isTrue);
      expect(result.isExcludedFromConflictResolution, isTrue);
      expect(result.conflictType, equals(ConflictType.serverStateChanged));
      expect(result.reason, contains('SafeTrip state machine is strictly server-authoritative'));
    });

    test('SafeTrip exclusion: matching status preserves server authority without conflict', () {
      final input = ConflictDetectionInput(
        userId: 'user_safetrip',
        entityType: 'safetrip',
        entityId: 'st_123',
        operation: EntityOperation.update,
        localBaseVersion: 1,
        serverVersion: 1,
        baseState: {'status': 'active'},
        localState: {'status': 'active'},
        serverState: {'status': 'active'},
        localTimestamp: fixedLocalTime,
      );

      final result = DeterministicConflictDetector.detectConflict(input);
      expect(result.hasConflict, isFalse);
      expect(result.isExcludedFromConflictResolution, isTrue);
    });

    // ------------------------------------------------------------------------
    // 7. Security, Isolation, and Boundary Testing
    // ------------------------------------------------------------------------
    test('user isolation: throws ArgumentError when userId is empty', () {
      expect(
        () => ConflictDetectionInput(
          userId: '   ',
          entityType: 'trip',
          entityId: 'trip_100',
          operation: EntityOperation.update,
          localTimestamp: fixedLocalTime,
        ),
        throwsArgumentError,
      );
    });

    test('authentication session invalid flags authenticationConflict', () {
      final input = ConflictDetectionInput(
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_100',
        operation: EntityOperation.update,
        sessionValid: false, // Expired or revoked session
        localTimestamp: fixedLocalTime,
      );

      final result = DeterministicConflictDetector.detectConflict(input);
      expect(result.hasConflict, isTrue);
      expect(result.conflictType, equals(ConflictType.authenticationConflict));
      expect(result.reason, contains('session is invalid'));
    });

    test('user lacking permissions flags permissionChanged', () {
      final input = ConflictDetectionInput(
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_100',
        operation: EntityOperation.update,
        userHasPermission: false, // Dropped from group or RLS violation
        localTimestamp: fixedLocalTime,
      );

      final result = DeterministicConflictDetector.detectConflict(input);
      expect(result.hasConflict, isTrue);
      expect(result.conflictType, equals(ConflictType.permissionChanged));
      expect(result.reason, contains('permissions or role changed'));
    });

    test('sanitized metadata strips Category C and credentials from generated conflict', () {
      final input = ConflictDetectionInput(
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_100',
        operation: EntityOperation.update,
        localBaseVersion: 1,
        serverVersion: 2,
        localTimestamp: fixedLocalTime,
      );

      final result = DeterministicConflictDetector.detectConflict(input);
      expect(result.conflict, isNotNull);
      final meta = result.conflict!.sanitizedMetadata;
      expect(meta.containsKey('token'), isFalse);
      expect(meta.containsKey('password'), isFalse);
      expect(meta.containsKey('secret'), isFalse);
      expect(meta.containsKey('latitude'), isFalse);
      expect(meta.containsKey('longitude'), isFalse);
      expect(meta['entity_id'], equals('trip_100'));
    });

    test('boundary handling: handles null base or server version safely', () {
      final input = ConflictDetectionInput(
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_new',
        operation: EntityOperation.create,
        localBaseVersion: null,
        serverVersion: null,
        baseState: null,
        localState: {'destination': 'Seoul'},
        serverState: null,
        localTimestamp: fixedLocalTime,
      );

      final result = DeterministicConflictDetector.detectConflict(input);
      expect(result.hasConflict, isFalse);
    });
  });
}
