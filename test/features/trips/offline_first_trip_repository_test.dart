import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/sync/sync_engine.dart';
import 'package:safemate/features/trips/data/repositories/offline_first_trip_repository.dart';
import 'package:safemate/features/trips/data/repositories/supabase_trip_repository.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late LocalDatabaseService dbService;
  late SyncEngine syncEngine;
  late OfflineFirstTripRepository offlineRepo;
  late SupabaseTripRepository remoteRepo;

  setUp(() async {
    dbService = LocalDatabaseService();
    await dbService.init(
      databaseFactory: databaseFactoryFfi,
      dbName: 'trip_offline_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    syncEngine = SyncEngine(localDb: dbService);
    remoteRepo = SupabaseTripRepository(); // In dev offline mode
    offlineRepo = OfflineFirstTripRepository(
      remoteRepo: remoteRepo,
      localDb: dbService,
      syncEngine: syncEngine,
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await dbService.close();
  });

  group('Phase 12.3 OfflineFirstTripRepository Tests', () {
    test('createTrip writes to SQLite immediately and updates with server id', () async {
      final trip = Trip(
        id: '',
        userId: 'user_alice',
        origin: 'Tokyo',
        destination: 'Reykjavik',
        startDate: DateTime.now().add(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 17)),
        status: TripStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final created = await offlineRepo.createTrip(trip);
      expect(created.id, isNotEmpty);
      expect(created.destination, 'Reykjavik');

      // Verify stored in local SQLite
      final local = await dbService.getTrip(created.id);
      expect(local, isNotNull);
      expect(local!.destination, 'Reykjavik');
    });

    test('getUserTrips returns local records when remote fails or is unreachable', () async {
      final trip = Trip(
        id: 'trip_cached_001',
        userId: 'user_alice',
        origin: 'Oslo',
        destination: 'Stockholm',
        startDate: DateTime.now().add(const Duration(days: 5)),
        endDate: DateTime.now().add(const Duration(days: 10)),
        status: TripStatus.published,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dbService.saveTrip(trip);

      // Query through offline-first repo
      final userTrips = await offlineRepo.getUserTrips('user_alice');
      expect(userTrips.any((t) => t.id == 'trip_cached_001'), isTrue);
    });

    test('transitionTripStatus updates local cache immediately', () async {
      final trip = Trip(
        id: 'trip_cached_002',
        userId: 'user_alice',
        origin: 'Copenhagen',
        destination: 'Helsinki',
        startDate: DateTime.now().add(const Duration(days: 5)),
        endDate: DateTime.now().add(const Duration(days: 10)),
        status: TripStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dbService.saveTrip(trip);

      final updated = await offlineRepo.transitionTripStatus(
        tripId: 'trip_cached_002',
        userId: 'user_alice',
        newStatus: TripStatus.published,
      );

      expect(updated.status, TripStatus.published);

      final fromDb = await dbService.getTrip('trip_cached_002');
      expect(fromDb?.status, TripStatus.published);
    });
  });
}
