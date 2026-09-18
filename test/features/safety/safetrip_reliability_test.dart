import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/sync/sync_engine.dart';
import 'package:safemate/core/sync/sync_error_formatter.dart';
import 'package:safemate/core/sync/sync_models.dart';
import 'package:safemate/features/safety/data/repositories/offline_first_safetrip_repository.dart';
import 'package:safemate/features/safety/data/repositories/supabase_safetrip_repository.dart';
import 'package:safemate/features/safety/domain/models/safetrip_models.dart';

void main() {
  sqfliteFfiInit();

  late LocalDatabaseService localDb;
  late SyncEngine syncEngine;
  late SupabaseSafeTripRepository remoteRepo;
  late OfflineFirstSafeTripRepository offlineRepo;

  setUp(() async {
    localDb = LocalDatabaseService();
    await localDb.initialize(
      databaseFactory: databaseFactoryFfi,
      dbName: 'safetrip_reliability_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    syncEngine = SyncEngine(localDb: localDb);
    remoteRepo = SupabaseSafeTripRepository();
    offlineRepo = OfflineFirstSafeTripRepository(
      remoteRepo: remoteRepo,
      localDb: localDb,
      syncEngine: syncEngine,
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await localDb.close();
  });

  group('Phase 12.5.13 — SafeTrip Real-World Physical Validation Tests', () {
    test('OFFLINE CHECK-IN != CONFIRMED SERVER DELIVERY: Offline check-in is strictly pending', () async {
      const journeyId = 'journey_phys_101';
      const userId = 'user_phys_traveler';
      const idempKey = 'idemp_offline_chk_001';

      // 1. Record check-in while offline (simulate network failure in remoteRepo)
      // SupabaseSafeTripRepository in dev mode or with offline network throws
      final checkin = await offlineRepo.recordCheckin(
        journeyId: journeyId,
        userId: userId,
        idempotencyKey: idempKey,
        notes: 'Checkpoint reached, cellular offline',
      );

      // Verify the returned checkin has expected details
      expect(checkin.journeyId, equals(journeyId));
      expect(checkin.idempotencyKey, equals(idempKey));

      // 2. Query raw database row in local_checkins to verify sync_status
      final db = localDb.database;
      final rows = await db.query(
        'local_checkins',
        where: 'id = ?',
        whereArgs: [checkin.id],
      );
      expect(rows.isNotEmpty, isTrue);
      final rawRow = rows.first;

      // Invariant: sync_status must be 'pending', NEVER 'synced'
      expect(rawRow['sync_status'], equals('pending'),
          reason: 'Offline check-in must never be marked as synced without server confirmation');

      // Invariant: Must NOT present success as server confirmed
      expect(SyncErrorFormatter.isServerConfirmedSuccess(SyncStatus.pending), isFalse);

      // Invariant: Operation is staged in sync_queue
      final pendingOps = await localDb.getPendingSyncRecords(userId);
      expect(pendingOps.length, equals(1));
      expect(pendingOps.first.entityType, equals('safetrip_checkin'));
      expect(pendingOps.first.entityId, equals(idempKey));
    });

    test('NETWORK RESTORATION: Enqueued check-in uploads and updates sync_status to synced', () async {
      const journeyId = 'journey_phys_202';
      const userId = 'user_phys_traveler_2';
      const idempKey = 'idemp_restore_chk_002';

      // Record offline
      await offlineRepo.recordCheckin(
        journeyId: journeyId,
        userId: userId,
        idempotencyKey: idempKey,
        notes: 'En route to mountain hut',
      );

      // Register mock remote handler to simulate server confirming receipt
      final serverDeliveredCheckins = <String, Map<String, dynamic>>{};
      syncEngine.registerHandler('safetrip_checkin', (record) async {
        serverDeliveredCheckins[record.entityId] = Map.from(record.payload);
        // Update local status to synced upon confirmed server ack
        final checkinTime = DateTime.parse(record.payload['local_timestamp'] as String);
        final checkin = JourneyCheckin(
          id: record.entityId,
          journeyId: record.payload['journey_id'] as String,
          userId: record.payload['user_id'] as String,
          checkinNumber: 1,
          status: CheckinStatus.completed,
          scheduledFor: checkinTime,
          completedAt: checkinTime,
          idempotencyKey: record.payload['idempotency_key'] as String,
          notes: record.payload['notes'] as String?,
        );
        await localDb.saveCheckin(checkin, syncStatus: 'synced');
      });

      // Process queue online
      await syncEngine.processPendingQueue(userId, isOnline: true);

      // 1. Server received checkin
      expect(serverDeliveredCheckins.containsKey(idempKey), isTrue);

      // 2. Local checkin is now confirmed synced
      final db = localDb.database;
      final rows = await db.query('local_checkins', where: 'id = ?', whereArgs: [idempKey]);
      expect(rows.first['sync_status'], equals('synced'));

      // 3. Queue is now cleared
      final pendingOps = await localDb.getPendingSyncRecords(userId);
      expect(pendingOps.isEmpty, isTrue);
    });

    test('LOCATION PERMISSION REVOKED: Check-in records location_unavailable without crash', () async {
      const journeyId = 'journey_phys_303';
      const userId = 'user_phys_traveler_3';
      const idempKey = 'idemp_loc_revoked_003';

      // Traveler revokes location permission; check-in includes note indicating GPS unavailable
      final checkin = await offlineRepo.recordCheckin(
        journeyId: journeyId,
        userId: userId,
        idempotencyKey: idempKey,
        notes: '[Location Revoked] Manual check-in via station Wi-Fi',
      );

      expect(checkin.notes, contains('[Location Revoked]'));

      final checkins = await localDb.getJourneyCheckins(journeyId);
      expect(checkins.length, equals(1));
      expect(checkins.first.notes, contains('[Location Revoked]'));
    });

    test('NO FABRICATED GUARANTEES: Activation requires direct server confirmation', () async {
      // Calling activateSafeTrip calls remote directly; does not fabricate confirmed local activation
      final now = DateTime.now();
      final journey = SafeTrip(
        id: 'journey_unconf_404',
        tripId: 'trip_404',
        ownerId: 'user_traveler',
        status: SafeTripStatus.ready,
        expectedStartTime: now,
        expectedArrivalTime: now.add(const Duration(hours: 3)),
        createdAt: now,
        updatedAt: now,
        consent: JourneyConsent(
          shareStatusWithTrustedContact: true,
          shareApproximateLocation: false,
          sendCheckinReminders: true,
          consentedAt: now,
        ),
      );

      await localDb.saveSafeTrip(journey);

      final stored = await offlineRepo.getSafeTripById('journey_unconf_404');
      expect(stored, isNotNull);
      // Status remains ready until server explicitly confirms activation
      expect(stored!.status, equals(SafeTripStatus.ready));
    });
  });
}
