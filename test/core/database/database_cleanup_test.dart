import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/database_models.dart';
import 'package:safemate/core/database/local_database.dart';

void main() {
  sqfliteFfiInit();

  group('Phase 12.1 Database Cleanup & Restart Persistence Tests', () {
    test('clearUserScopedData purges all user records on logout without touching other users', () async {
      final dbName = 'cleanup_test_${DateTime.now().microsecondsSinceEpoch}.db';
      final localDb = LocalDatabase();
      await localDb.open(
        databaseFactory: databaseFactoryFfi,
        dbName: dbName,
      );

      // 1. Populate records for Alice
      await localDb.saveProfile(
        LocalProfileRecord(
          id: 'user_alice',
          userId: 'user_alice',
          displayName: 'Alice',
          verificationLevel: 'verified',
          rawJson: '{"displayName":"Alice"}',
          updatedAt: DateTime.now(),
        ),
      );
      await localDb.saveTrip(
        LocalTripRecord(
          id: 'trip_alice_01',
          userId: 'user_alice',
          destination: 'Paris',
          origin: 'London',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 5),
          purpose: 'art',
          budget: 'moderate',
          status: 'published',
          rawJson: '{"destination":"Paris"}',
          updatedAt: DateTime.now(),
        ),
      );

      // 2. Populate records for Bob
      await localDb.saveProfile(
        LocalProfileRecord(
          id: 'user_bob',
          userId: 'user_bob',
          displayName: 'Bob',
          verificationLevel: 'verified',
          rawJson: '{"displayName":"Bob"}',
          updatedAt: DateTime.now(),
        ),
      );
      await localDb.saveTrip(
        LocalTripRecord(
          id: 'trip_bob_01',
          userId: 'user_bob',
          destination: 'Rome',
          origin: 'Berlin',
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 7),
          purpose: 'history',
          budget: 'budget',
          status: 'published',
          rawJson: '{"destination":"Rome"}',
          updatedAt: DateTime.now(),
        ),
      );

      // 3. Purge Alice (Logout)
      await localDb.clearUserScopedData('user_alice');

      // 4. Verify Alice data is completely gone
      expect(await localDb.getProfile('user_alice'), isNull);
      expect(await localDb.getUserTrips('user_alice'), isEmpty);
      expect(await localDb.getTrip('trip_alice_01'), isNull);

      // 5. Verify Bob data is 100% intact
      expect(await localDb.getProfile('user_bob'), isNotNull);
      expect(await localDb.getUserTrips('user_bob'), isNotEmpty);
      expect(await localDb.getTrip('trip_bob_01'), isNotNull);

      await localDb.close();
    });

    test('12.1.18 Restart Persistence: Data survives database close and reopen', () async {
      final dbName = 'restart_persistence_test_${DateTime.now().microsecondsSinceEpoch}.db';

      // Phase 1: Open and write
      var localDb = LocalDatabase();
      await localDb.open(
        databaseFactory: databaseFactoryFfi,
        dbName: dbName,
      );

      await localDb.saveTrip(
        LocalTripRecord(
          id: 'trip_persist_001',
          userId: 'user_persister',
          destination: 'Helsinki',
          origin: 'Stockholm',
          startDate: DateTime(2026, 11, 15),
          endDate: DateTime(2026, 11, 20),
          purpose: 'winter',
          budget: 'moderate',
          status: 'draft',
          rawJson: '{"destination":"Helsinki"}',
          updatedAt: DateTime.now(),
        ),
      );

      // Explicitly close DB to simulate app kill / restart
      await localDb.close();

      // Phase 2: Reopen the same database
      localDb = LocalDatabase();
      await localDb.open(
        databaseFactory: databaseFactoryFfi,
        dbName: dbName,
      );

      // Verify data survived
      final retrievedTrip = await localDb.getTrip('trip_persist_001');
      expect(retrievedTrip, isNotNull);
      expect(retrievedTrip?.destination, 'Helsinki');
      expect(retrievedTrip?.userId, 'user_persister');

      await localDb.close();
    });
  });
}
