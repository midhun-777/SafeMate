import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/sync/sync_engine.dart';
import 'package:safemate/features/safety/data/repositories/offline_first_safetrip_repository.dart';
import 'package:safemate/features/safety/data/repositories/supabase_safetrip_repository.dart';
import 'package:safemate/features/safety/domain/models/safetrip_models.dart';

void main() {
  sqfliteFfiInit();

  late LocalDatabaseService localDb;
  late SyncEngine syncEngine;
  late SupabaseSafeTripRepository remoteRepo;
  late OfflineFirstSafeTripRepository offlineSafeTripRepo;

  setUp(() async {
    localDb = LocalDatabaseService();
    await localDb.initialize(
      databaseFactory: databaseFactoryFfi,
      dbName: 'offline_safetrip_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    syncEngine = SyncEngine(localDb: localDb);
    remoteRepo = SupabaseSafeTripRepository();
    offlineSafeTripRepo = OfflineFirstSafeTripRepository(
      remoteRepo: remoteRepo,
      localDb: localDb,
      syncEngine: syncEngine,
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await localDb.close();
  });

  group('Phase 12.3 SafeTrip Server Authority & Offline Boundary Tests (12.3.12)', () {
    test('recordCheckin persists check-in intent locally with pending sync status', () async {
      final checkin = await offlineSafeTripRepo.recordCheckin(
        journeyId: 'journey_safe_1',
        userId: 'user_traveler',
        idempotencyKey: 'idemp_checkin_001',
        notes: 'Passed checkpoint A',
      );

      expect(checkin.journeyId, equals('journey_safe_1'));
      expect(checkin.idempotencyKey, equals('idemp_checkin_001'));

      final checkins = await localDb.getJourneyCheckins('journey_safe_1');
      expect(checkins.length, equals(1));
      expect(checkins.first.idempotencyKey, equals('idemp_checkin_001'));
    });

    test('getSafeTripById returns local cached state immediately', () async {
      final now = DateTime.now();
      final trip = SafeTrip(
        id: 'journey_cached_99',
        tripId: 'trip_99',
        ownerId: 'user_traveler',
        status: SafeTripStatus.active,
        expectedStartTime: now,
        expectedArrivalTime: now.add(const Duration(hours: 4)),
        createdAt: now,
        updatedAt: now,
        consent: JourneyConsent(
          shareStatusWithTrustedContact: true,
          shareApproximateLocation: true,
          sendCheckinReminders: true,
          consentedAt: now,
        ),
      );

      await localDb.saveSafeTrip(trip);

      final fetched = await offlineSafeTripRepo.getSafeTripById('journey_cached_99');
      expect(fetched, isNotNull);
      expect(fetched!.status, equals(SafeTripStatus.active));
      expect(fetched.tripId, equals('trip_99'));
    });
  });
}
