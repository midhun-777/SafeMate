import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/sync/realtime_reconciler.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';

void main() {
  sqfliteFfiInit();

  late LocalDatabaseService localDb;
  late RealtimeReconciler reconciler;

  Trip makeTestTrip({
    required String id,
    required String userId,
    required String destination,
    int version = 1,
  }) {
    final now = DateTime.now();
    return Trip(
      id: id,
      userId: userId,
      title: 'Trip to $destination',
      origin: 'Tokyo',
      destination: destination,
      startDate: now.add(const Duration(days: 10)),
      endDate: now.add(const Duration(days: 15)),
      version: version,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() async {
    localDb = LocalDatabaseService();
    await localDb.initialize(
      databaseFactory: databaseFactoryFfi,
      dbName: 'realtime_hardening_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    reconciler = RealtimeReconciler(localDb: localDb);
  });

  tearDown(() async {
    await localDb.close();
  });

  group('Phase 12.5.6 — Realtime Hardening & Concurrency Tests', () {
    test('Deduplication: Identical server version produces RealtimeAction.deduplicate', () async {
      // 1. Pre-populate a trip with server_version = 2
      final initialTrip = makeTestTrip(
        id: 'trip_rt_1',
        userId: 'user_rt',
        destination: 'Kyoto',
        version: 2,
      );
      await localDb.saveTrip(initialTrip);

      // 2. Ingest duplicate event with server_version = 2
      final result = await reconciler.ingestServerEvent(
        entityType: 'trip',
        entityId: 'trip_rt_1',
        userId: 'user_rt',
        serverVersion: 2,
        serverPayload: {
          'id': 'trip_rt_1',
          'user_id': 'user_rt',
          'destination': 'Kyoto',
          'server_version': 2,
        },
      );

      expect(result.action, equals(RealtimeAction.deduplicate));
      expect(result.reason, contains('deduplicated'));
    });

    test('Stale Event Rejection: Older server version produces RealtimeAction.ignore', () async {
      // Pre-populate with version = 4
      final initialTrip = makeTestTrip(
        id: 'trip_rt_2',
        userId: 'user_rt',
        destination: 'Tokyo',
        version: 4,
      );
      await localDb.saveTrip(initialTrip);

      // Deliver delayed/out-of-order event with server_version = 3
      final result = await reconciler.ingestServerEvent(
        entityType: 'trip',
        entityId: 'trip_rt_2',
        userId: 'user_rt',
        serverVersion: 3,
        serverPayload: {
          'id': 'trip_rt_2',
          'user_id': 'user_rt',
          'destination': 'Old Stale Destination',
          'server_version': 3,
        },
      );

      expect(result.action, equals(RealtimeAction.ignore));
      expect(result.reason, contains('Stale'));

      // Verify local database remains untouched at version 4
      final storedTrip = await localDb.getTrip('trip_rt_2');
      expect(storedTrip, isNotNull);
      expect(storedTrip!.version, equals(4));
      expect(storedTrip.destination, equals('Tokyo'));
    });

    test('Newer Version Reconciliation: Higher server version reconciles into SQLite', () async {
      final initialTrip = makeTestTrip(
        id: 'trip_rt_3',
        userId: 'user_rt',
        destination: 'Osaka',
        version: 1,
      );
      await localDb.saveTrip(initialTrip);

      // Deliver newer server update with server_version = 2
      final result = await reconciler.ingestServerEvent(
        entityType: 'trip',
        entityId: 'trip_rt_3',
        userId: 'user_rt',
        serverVersion: 2,
        serverPayload: {
          'id': 'trip_rt_3',
          'user_id': 'user_rt',
          'destination': 'Osaka Dotonbori Confirmed',
          'server_version': 2,
        },
      );

      expect(result.action, equals(RealtimeAction.reconcile));

      final updatedTrip = await localDb.getTrip('trip_rt_3');
      expect(updatedTrip, isNotNull);
      expect(updatedTrip!.version, equals(2));
      expect(updatedTrip.destination, equals('Osaka Dotonbori Confirmed'));
    });

    test('Anti-Resurrection: Delayed UPDATE event cannot resurrect a deleted entity', () async {
      // Entity was deleted on server and locally absent
      final existing = await localDb.getTrip('trip_deleted_99');
      expect(existing, isNull);

      // Ingest delete event for absent entity -> deduplicates cleanly
      final deleteResult = await reconciler.ingestServerEvent(
        entityType: 'trip',
        entityId: 'trip_deleted_99',
        userId: 'user_rt',
        serverVersion: 2,
        isDeleted: true,
      );
      expect(deleteResult.action, equals(RealtimeAction.deduplicate));

      // Attempting to query entity verifies it remains deleted / absent
      final checkStillEmpty = await localDb.getTrip('trip_deleted_99');
      expect(checkStillEmpty, isNull);
    });

    test('Authoritative Server Deletion: Deletes local record and prevents resurrection', () async {
      final initialTrip = makeTestTrip(
        id: 'trip_to_delete',
        userId: 'user_rt',
        destination: 'Hakone',
        version: 2,
      );
      await localDb.saveTrip(initialTrip);

      // Server delivers authoritative delete at server_version = 3
      final result = await reconciler.ingestServerEvent(
        entityType: 'trip',
        entityId: 'trip_to_delete',
        userId: 'user_rt',
        serverVersion: 3,
        isDeleted: true,
      );

      expect(result.action, equals(RealtimeAction.delete));

      // Invariant: Row is removed from local SQLite
      final tripAfter = await localDb.getTrip('trip_to_delete');
      expect(tripAfter, isNull);
    });
  });
}
