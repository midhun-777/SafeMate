import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/sync/sync_engine.dart';
import 'package:safemate/features/trips/data/repositories/offline_first_trip_repository.dart';
import 'package:safemate/features/trips/data/repositories/supabase_trip_repository.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_purpose.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';

void main() {
  sqfliteFfiInit();

  late LocalDatabaseService localDb;
  late SyncEngine syncEngine;
  late SupabaseTripRepository remoteRepo;
  late OfflineFirstTripRepository offlineRepo;

  setUp(() async {
    localDb = LocalDatabaseService();
    await localDb.initialize(
      databaseFactory: databaseFactoryFfi,
      dbName: 'offline_trip_repo_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    syncEngine = SyncEngine(localDb: localDb);
    remoteRepo = SupabaseTripRepository();
    offlineRepo = OfflineFirstTripRepository(
      remoteRepo: remoteRepo,
      localDb: localDb,
      syncEngine: syncEngine,
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await localDb.close();
  });

  group('Phase 12.3 OfflineFirstTripRepository Tests (12.3.10 & 12.3.3)', () {
    test('saveDraft writes to SQLite immediately and syncs or enqueues', () async {
      final trip = Trip(
        id: 'draft_trip_001',
        userId: 'user_traveler',
        destination: 'Kyoto',
        origin: 'Tokyo',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 5),
        tripPurpose: TripPurpose.vacation,
        budgetTier: TripBudgetTier.moderate,
        status: TripStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final saved = await offlineRepo.saveDraft(trip);
      expect(saved.id, equals('draft_trip_001'));
      expect(saved.status, equals(TripStatus.draft));

      // Verify cached in local database
      final cached = await localDb.getTrip('draft_trip_001');
      expect(cached, isNotNull);
      expect(cached!.destination, equals('Kyoto'));
    });

    test('getTrip returns instantaneous local cached record', () async {
      final trip = Trip(
        id: 'cached_trip_002',
        userId: 'user_traveler',
        destination: 'Osaka',
        origin: 'Tokyo',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 5),
        tripPurpose: TripPurpose.exploration,
        budgetTier: TripBudgetTier.comfortable,
        status: TripStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await localDb.saveTrip(trip);

      final fetched = await offlineRepo.getTrip('cached_trip_002');
      expect(fetched, isNotNull);
      expect(fetched!.destination, equals('Osaka'));
    });

    test('deleteDraftTrip removes local record and handles remote delete intent', () async {
      final trip = Trip(
        id: 'delete_target_003',
        userId: 'user_traveler',
        destination: 'Nara',
        origin: 'Kyoto',
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2026, 12, 3),
        tripPurpose: TripPurpose.vacation,
        budgetTier: TripBudgetTier.budget,
        status: TripStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await offlineRepo.saveDraft(trip);

      await offlineRepo.deleteDraftTrip(
        tripId: 'delete_target_003',
        userId: 'user_traveler',
      );

      final checkLocal = await localDb.getTrip('delete_target_003');
      expect(checkLocal, isNull, reason: 'Deleted draft must be purged from local SQLite store');
    });
  });
}
