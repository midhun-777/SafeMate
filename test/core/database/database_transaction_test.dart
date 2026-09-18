import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/database_exceptions.dart';
import 'package:safemate/core/database/database_models.dart';
import 'package:safemate/core/database/local_database.dart';

void main() {
  sqfliteFfiInit();

  late LocalDatabase localDb;

  setUp(() async {
    localDb = LocalDatabase();
    await localDb.open(
      databaseFactory: databaseFactoryFfi,
      dbName: 'transaction_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
  });

  tearDown(() async {
    await localDb.close();
  });

  group('Phase 12.1 Database Transaction Safety Tests (12.1.14)', () {
    test('commits related records atomically when all operations succeed', () async {
      final trip = LocalTripRecord(
        id: 'trip_atomic_001',
        userId: 'user_alice',
        destination: 'Bergen',
        origin: 'Oslo',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 8),
        purpose: 'fjords',
        budget: 'moderate',
        status: 'published',
        rawJson: '{"destination":"Bergen"}',
        updatedAt: DateTime.now(),
      );

      final prefs = LocalTripPreferencesRecord(
        id: 'pref_atomic_001',
        tripId: 'trip_atomic_001',
        userId: 'user_alice',
        preferredGender: 'female_only',
        travelPace: 'flexible',
        budgetTier: 'moderate',
        rawJson: '{"preferredGender":"female_only"}',
        updatedAt: DateTime.now(),
      );

      await localDb.saveTripWithPreferences(trip: trip, preferences: prefs);

      // Verify both exist
      final savedTrip = await localDb.getTrip('trip_atomic_001');
      final savedPrefs = await localDb.getTripPreferences('trip_atomic_001');

      expect(savedTrip, isNotNull);
      expect(savedTrip?.destination, 'Bergen');
      expect(savedPrefs, isNotNull);
      expect(savedPrefs?.preferredGender, 'female_only');
    });

    test('rolls back all changes when an operation within transaction fails', () async {
      final trip = LocalTripRecord(
        id: 'trip_rollback_001',
        userId: 'user_alice',
        destination: 'Tromso',
        origin: 'Oslo',
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2026, 12, 8),
        purpose: 'aurora',
        budget: 'moderate',
        status: 'draft',
        rawJson: '{"destination":"Tromso"}',
        updatedAt: DateTime.now(),
      );

      // Attempt transaction where step 1 succeeds but step 2 throws an intentional error
      expect(
        () => localDb.transaction((txn) async {
          await txn.insert('local_trips', trip.toMap());
          // Intentionally trigger failure in step 2: invalid SQL table
          await txn.rawInsert('INSERT INTO non_existent_table VALUES ("fail")');
        }),
        throwsA(isA<DatabaseWriteException>()),
      );

      // Verify step 1 was rolled back completely — trip must NOT exist in database
      final savedTrip = await localDb.getTrip('trip_rollback_001');
      expect(savedTrip, isNull);
    });
  });
}
