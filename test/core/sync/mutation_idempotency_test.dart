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
      dbName: 'idempotency_chaos_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    syncEngine = SyncEngine(localDb: localDb);
  });

  tearDown(() async {
    syncEngine.dispose();
    await localDb.close();
  });

  group('Phase 12.5.3 — Exactly-Once Effect & Mutation Idempotency Tests', () {
    test('Trip Mutation: Server commits -> response lost -> client retries -> EXACTLY ONE SERVER EFFECT', () async {
      final serverDatabase = <String, Map<String, dynamic>>{};
      final serverProcessedKeys = <String>{};
      int serverExecutionCount = 0;

      syncEngine.registerHandler('trip', (record) async {
        serverExecutionCount++;
        final idempotencyKey = record.operationId;
        final tripId = record.entityId;

        // Idempotency check on server
        if (!serverProcessedKeys.contains(idempotencyKey)) {
          serverProcessedKeys.add(idempotencyKey);
          serverDatabase[tripId] = {
            ...record.payload,
            'server_version': (serverDatabase[tripId]?['server_version'] ?? 0) + 1,
          };
        }

        // Simulate dropped response on first attempt
        if (serverExecutionCount == 1) {
          throw const FormatException('NetworkError: Response packet dropped after server commit');
        }
      });

      const opId = 'op_trip_idem_001';
      await syncEngine.enqueue(
        userId: 'user_idem',
        entityType: 'trip',
        entityId: 'trip_100',
        action: 'update',
        operationId: opId,
        payload: {'destination': 'Nagoya', 'budget': 500},
      );

      // Attempt 1: Server commits, but response drops
      await syncEngine.processPendingQueue('user_idem', isOnline: true);
      expect(serverExecutionCount, equals(1));
      expect(serverDatabase['trip_100']?['destination'], equals('Nagoya'));
      expect(serverDatabase['trip_100']?['server_version'], equals(1));

      // Reset cooldown for retry
      await localDb.updateSyncRecordStatus(
        opId,
        'pending',
        lastAttemptAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      // Attempt 2: Client retries with same operationId
      await syncEngine.processPendingQueue('user_idem', isOnline: true);
      expect(serverExecutionCount, equals(2));

      // Server state must have exactly ONE logical update (server_version remains 1)
      expect(serverDatabase['trip_100']?['destination'], equals('Nagoya'));
      expect(serverDatabase['trip_100']?['server_version'], equals(1),
          reason: 'Idempotent replay must not re-increment version or duplicate entity');
    });

    test('Profile Mutation: Replayed update does not duplicate or corrupt profile', () async {
      final profileStore = <String, Map<String, dynamic>>{};
      final seenOpIds = <String>{};
      int attempts = 0;

      syncEngine.registerHandler('profile', (record) async {
        attempts++;
        if (!seenOpIds.contains(record.operationId)) {
          seenOpIds.add(record.operationId);
          profileStore[record.entityId] = Map.from(record.payload);
        }
        if (attempts == 1) {
          throw const FormatException('504 Gateway Timeout: Response dropped');
        }
      });

      const opId = 'op_prof_idem_002';
      await syncEngine.enqueue(
        userId: 'user_prof',
        entityType: 'profile',
        entityId: 'prof_200',
        action: 'update',
        operationId: opId,
        payload: {'full_name': 'Kenji Sato', 'bio': 'Alpine hiker'},
      );

      // Attempt 1
      await syncEngine.processPendingQueue('user_prof', isOnline: true);
      // Reset cooldown
      await localDb.updateSyncRecordStatus(
        opId,
        'pending',
        lastAttemptAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      // Attempt 2
      await syncEngine.processPendingQueue('user_prof', isOnline: true);

      expect(profileStore.length, equals(1));
      expect(profileStore['prof_200']?['full_name'], equals('Kenji Sato'));
      expect(attempts, equals(2));
    });

    test('Trip Preferences: Idempotent preference update produces single logical update', () async {
      final preferencesStore = <String, Map<String, dynamic>>{};
      final processedKeys = <String>{};
      int attempts = 0;

      syncEngine.registerHandler('trip_preferences', (record) async {
        attempts++;
        if (!processedKeys.contains(record.operationId)) {
          processedKeys.add(record.operationId);
          preferencesStore[record.entityId] = Map.from(record.payload);
        }
        if (attempts == 1) {
          throw const FormatException('SocketException: Connection reset by peer');
        }
      });

      const opId = 'op_pref_idem_003';
      await syncEngine.enqueue(
        userId: 'user_pref',
        entityType: 'trip_preferences',
        entityId: 'pref_300',
        action: 'update',
        operationId: opId,
        payload: {
          'activities': {'hiking': 'selected', 'museums': 'not_selected'},
        },
      );

      // Attempt 1: dropped
      await syncEngine.processPendingQueue('user_pref', isOnline: true);
      // Reset cooldown
      await localDb.updateSyncRecordStatus(
        opId,
        'pending',
        lastAttemptAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      // Attempt 2: retried
      await syncEngine.processPendingQueue('user_pref', isOnline: true);

      expect(preferencesStore.length, equals(1));
      expect(preferencesStore['pref_300']?['activities']['hiking'], equals('selected'));
    });

    test('Itinerary Mutation: Replayed stop update avoids creating duplicate stops', () async {
      final stopsList = <Map<String, dynamic>>[];
      final processedStops = <String>{};
      int attempts = 0;

      syncEngine.registerHandler('itinerary', (record) async {
        attempts++;
        final stopId = record.payload['stop_id'] as String;
        if (!processedStops.contains(record.operationId)) {
          processedStops.add(record.operationId);
          final existingIdx = stopsList.indexWhere((s) => s['stop_id'] == stopId);
          if (existingIdx >= 0) {
            stopsList[existingIdx] = Map.from(record.payload);
          } else {
            stopsList.add(Map.from(record.payload));
          }
        }
        if (attempts == 1) {
          throw const FormatException('TimeoutException: Dropped HTTP 200 response');
        }
      });

      const opId = 'op_itin_idem_004';
      await syncEngine.enqueue(
        userId: 'user_itin',
        entityType: 'itinerary',
        entityId: 'itin_400',
        action: 'update',
        operationId: opId,
        payload: {'stop_id': 'stop_401', 'title': 'Fushimi Inari Visit', 'order': 1},
      );

      // Attempt 1
      await syncEngine.processPendingQueue('user_itin', isOnline: true);
      // Reset cooldown
      await localDb.updateSyncRecordStatus(
        opId,
        'pending',
        lastAttemptAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      // Attempt 2
      await syncEngine.processPendingQueue('user_itin', isOnline: true);

      // Stops list must have exactly 1 item, no duplicates
      expect(stopsList.length, equals(1));
      expect(stopsList.first['title'], equals('Fushimi Inari Visit'));
    });

    test('Chat Message: Append-only chat deduplicates identical message_id on retry', () async {
      final messagesServerTable = <Map<String, dynamic>>[];
      final seenMessageIds = <String>{};
      int attempts = 0;

      syncEngine.registerHandler('chat', (record) async {
        attempts++;
        final messageId = record.payload['message_id'] as String;
        if (!seenMessageIds.contains(messageId)) {
          seenMessageIds.add(messageId);
          messagesServerTable.add(Map.from(record.payload));
        }
        if (attempts == 1) {
          throw const FormatException('ConnectionClosedException: Response lost');
        }
      });

      const opId = 'op_chat_idem_005';
      const msgId = 'msg_uuid_555';
      await syncEngine.enqueue(
        userId: 'user_chat',
        entityType: 'chat',
        entityId: 'conv_500',
        action: 'send_message',
        operationId: opId,
        payload: {
          'message_id': msgId,
          'conversation_id': 'conv_500',
          'text': 'Meeting at north gate at 10 AM',
        },
      );

      // Attempt 1: Server appends, network fails
      await syncEngine.processPendingQueue('user_chat', isOnline: true);
      expect(messagesServerTable.length, equals(1));

      // Reset cooldown
      await localDb.updateSyncRecordStatus(
        opId,
        'pending',
        lastAttemptAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      // Attempt 2: Client retries
      await syncEngine.processPendingQueue('user_chat', isOnline: true);

      // Invariant: Exactly ONE message stored in chat, zero duplicate chat messages
      expect(messagesServerTable.length, equals(1));
      expect(messagesServerTable.first['text'], equals('Meeting at north gate at 10 AM'));
      expect(attempts, equals(2));
    });

    test('SafeTrip Check-In: Replayed check-in produces exactly one check-in record', () async {
      final checkinLog = <String, Map<String, dynamic>>{};
      int attempts = 0;

      syncEngine.registerHandler('safetrip_checkin', (record) async {
        attempts++;
        final idempotencyKey = record.payload['idempotency_key'] as String;
        // Server idempotency via unique idempotency_key
        checkinLog.putIfAbsent(idempotencyKey, () => Map.from(record.payload));

        if (attempts == 1) {
          throw const FormatException('SSLHandshakeException: Dropped during SSL close');
        }
      });

      const opId = 'op_chk_idem_006';
      const idempotencyKey = 'idemp_key_chk_777';
      await syncEngine.enqueue(
        userId: 'user_chk',
        entityType: 'safetrip_checkin',
        entityId: idempotencyKey,
        action: 'record_checkin',
        operationId: opId,
        payload: {
          'journey_id': 'journey_700',
          'idempotency_key': idempotencyKey,
          'notes': 'Checkpoint Alpha reached',
        },
      );

      // Attempt 1
      await syncEngine.processPendingQueue('user_chk', isOnline: true);
      expect(checkinLog.length, equals(1));

      // Reset cooldown
      await localDb.updateSyncRecordStatus(
        opId,
        'pending',
        lastAttemptAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      // Attempt 2
      await syncEngine.processPendingQueue('user_chk', isOnline: true);

      expect(checkinLog.length, equals(1));
      expect(checkinLog[idempotencyKey]?['notes'], equals('Checkpoint Alpha reached'));
      expect(attempts, equals(2));
    });
  });
}
