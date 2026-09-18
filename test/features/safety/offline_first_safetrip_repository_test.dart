import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/sync/sync_engine.dart';
import 'package:safemate/features/safety/data/repositories/offline_first_safetrip_repository.dart';
import 'package:safemate/features/safety/data/repositories/supabase_safetrip_repository.dart';
import 'package:safemate/features/safety/domain/models/safetrip_models.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late LocalDatabaseService dbService;
  late SyncEngine syncEngine;
  late OfflineFirstSafeTripRepository offlineSafeTripRepo;
  late SupabaseSafeTripRepository remoteSafeTripRepo;

  setUp(() async {
    dbService = LocalDatabaseService();
    await dbService.init(
      databaseFactory: databaseFactoryFfi,
      dbName: 'safetrip_offline_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    syncEngine = SyncEngine(localDb: dbService);
    remoteSafeTripRepo = SupabaseSafeTripRepository(); // In dev offline mode
    offlineSafeTripRepo = OfflineFirstSafeTripRepository(
      remoteRepo: remoteSafeTripRepo,
      localDb: dbService,
      syncEngine: syncEngine,
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await dbService.close();
  });

  group('Phase 12.9 OfflineFirstSafeTripRepository Tests', () {
    test('prepareSafeTrip stores SafeTrip in SQLite and allows retrieval', () async {
      final now = DateTime.now();
      final safeTrip = SafeTrip(
        id: 'journey_100',
        tripId: 'trip_100',
        ownerId: 'user_alice',
        status: SafeTripStatus.preparing,
        expectedStartTime: now,
        expectedArrivalTime: now.add(const Duration(hours: 3)),
        createdAt: now,
        updatedAt: now,
      );

      await offlineSafeTripRepo.prepareSafeTrip(safeTrip);

      final retrieved = await offlineSafeTripRepo.getSafeTripByTripId('trip_100');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'journey_100');
      expect(retrieved.status, SafeTripStatus.preparing);
    });

    test('recordCheckin records local checkin and explicitly notes pending network confirmation', () async {
      final checkin = await offlineSafeTripRepo.recordCheckin(
        journeyId: 'journey_100',
        userId: 'user_alice',
        idempotencyKey: 'idemp_chk_001',
        notes: 'Reached scenic viewpoint',
      );

      expect(checkin.status, CheckinStatus.completed);
      expect(checkin.journeyId, 'journey_100');

      // Verify stored in SQLite
      final checkins = await dbService.getJourneyCheckins('journey_100');
      expect(checkins.length, 1);
      expect(checkins.first.userId, 'user_alice');
    });

    test('Zero false emergency dispatching claims in offline check-ins', () async {
      final checkin = await offlineSafeTripRepo.recordCheckin(
        journeyId: 'journey_101',
        userId: 'user_bob',
        idempotencyKey: 'idemp_chk_002',
      );

      // Verify that offline checkin does NOT claim emergency contact was notified
      expect(checkin.notes, isNot(contains('Emergency contacted')));
      expect(checkin.notes, isNot(contains('911 Dispatched')));
      expect(checkin.notes, contains('Check-in waiting for network confirmation.'));
    });
  });
}
