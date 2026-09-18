import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/connections/domain/models/chat_models.dart';
import 'package:safemate/features/safety/domain/models/safetrip_models.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late LocalDatabaseService dbService;

  setUp(() async {
    dbService = LocalDatabaseService();
    await dbService.init(
      databaseFactory: databaseFactoryFfi,
      dbName: 'test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
  });

  tearDown(() async {
    await dbService.close();
  });

  group('Phase 12.1 LocalDatabaseService Tests', () {
    test('Initializes database and handles Trip CRUD', () async {
      final trip = Trip(
        id: 'trip_001',
        userId: 'user_alice',
        origin: 'Tokyo',
        destination: 'Kyoto',
        startDate: DateTime.now().add(const Duration(days: 7)),
        endDate: DateTime.now().add(const Duration(days: 14)),
        status: TripStatus.published,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 1. Save trip
      await dbService.saveTrip(trip);

      // 2. Read trip by ID
      final retrieved = await dbService.getTrip('trip_001');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'trip_001');
      expect(retrieved.destination, 'Kyoto');
      expect(retrieved.userId, 'user_alice');

      // 3. Query trips by user
      final userTrips = await dbService.getUserTrips('user_alice');
      expect(userTrips.length, 1);
      expect(userTrips.first.destination, 'Kyoto');

      // 4. Delete trip
      await dbService.deleteTrip('trip_001');
      final afterDelete = await dbService.getTrip('trip_001');
      expect(afterDelete, isNull);
    });

    test('Saves and retrieves UserProfile in SQLite', () async {
      final profile = UserProfile(
        id: 'user_alice',
        displayName: 'Alice Explorer',
        bio: 'Avid mountaineer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dbService.saveProfile(profile);

      final retrieved = await dbService.getProfile('user_alice');
      expect(retrieved, isNotNull);
      expect(retrieved!.displayName, 'Alice Explorer');
      expect(retrieved.bio, 'Avid mountaineer');
    });

    test('Saves and retrieves ChatMessage in local outbox', () async {
      final msg = ChatMessage(
        id: 'msg_001',
        roomId: 'room_abc',
        senderId: 'user_alice',
        content: 'Hello companion!',
        createdAt: DateTime.now(),
        clientMessageId: 'client_001',
      );

      await dbService.saveChatMessage(msg, status: 'pending');

      final messages = await dbService.getRoomMessages('room_abc');
      expect(messages.length, 1);
      expect(messages.first.content, 'Hello companion!');
      expect(messages.first.clientMessageId, 'client_001');
    });

    test('Saves and retrieves SafeTrip and JourneyCheckin', () async {
      final now = DateTime.now();
      final safeTrip = SafeTrip(
        id: 'safetrip_001',
        tripId: 'trip_001',
        ownerId: 'user_alice',
        status: SafeTripStatus.active,
        expectedStartTime: now,
        expectedArrivalTime: now.add(const Duration(hours: 4)),
        createdAt: now,
        updatedAt: now,
      );

      await dbService.saveSafeTrip(safeTrip);
      final retrieved = await dbService.getSafeTrip('safetrip_001');
      expect(retrieved, isNotNull);
      expect(retrieved!.status, SafeTripStatus.active);

      final checkin = JourneyCheckin(
        id: 'chk_001',
        journeyId: 'safetrip_001',
        userId: 'user_alice',
        checkinNumber: 1,
        status: CheckinStatus.completed,
        scheduledFor: now,
        completedAt: now,
        notes: 'Waiting for train',
      );

      await dbService.saveCheckin(checkin, syncStatus: 'pending');
      final checkins = await dbService.getJourneyCheckins('safetrip_001');
      expect(checkins.length, 1);
      expect(checkins.first.notes, 'Waiting for train');
    });

    test('Enqueue and manages SyncRecord lifecycle', () async {
      final record = SyncRecord(
        operationId: 'op_123',
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_001',
        action: 'create',
        payload: {'destination': 'Zurich'},
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await dbService.enqueueSyncRecord(record);
      final pending = await dbService.getPendingSyncRecords('user_alice');
      expect(pending.length, 1);
      expect(pending.first.operationId, 'op_123');

      // Update status
      await dbService.updateSyncRecordStatus('op_123', 'syncing', retryCount: 1);
      // Delete record
      await dbService.deleteSyncRecord('op_123');
      final afterDelete = await dbService.getPendingSyncRecords('user_alice');
      expect(afterDelete, isEmpty);
    });

    test('purgeUserData thoroughly clears user records on logout / switch', () async {
      final tripA = Trip(
        id: 'trip_a',
        userId: 'user_alice',
        origin: 'Milan',
        destination: 'Rome',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)),
        status: TripStatus.published,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final tripB = Trip(
        id: 'trip_b',
        userId: 'user_bob',
        origin: 'Lyon',
        destination: 'Paris',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 5)),
        status: TripStatus.published,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dbService.saveTrip(tripA);
      await dbService.saveTrip(tripB);

      // Purge Alice
      await dbService.purgeUserData('user_alice');

      expect(await dbService.getTrip('trip_a'), isNull);
      expect(await dbService.getUserTrips('user_alice'), isEmpty);

      // Bob remains untouched
      expect(await dbService.getTrip('trip_b'), isNotNull);
      expect((await dbService.getUserTrips('user_bob')).length, 1);
    });
  });
}
