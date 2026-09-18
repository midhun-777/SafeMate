import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/database_exceptions.dart';
import 'package:safemate/core/database/database_models.dart';
import 'package:safemate/core/database/local_data_policy.dart';
import 'package:safemate/core/database/local_database.dart';

void main() {
  sqfliteFfiInit();

  late LocalDatabase localDb;

  setUp(() async {
    localDb = LocalDatabase();
    await localDb.open(
      databaseFactory: databaseFactoryFfi,
      dbName: 'cross_account_regression_${DateTime.now().microsecondsSinceEpoch}.db',
    );
  });

  tearDown(() async {
    await localDb.close();
  });

  group('Phase 12.2 Cross-Account Isolation & SQLite Inspection Tests (12.2.6 & 12.2.11)', () {
    test('12.2.6 Cross-Account Testing: complete isolation across account switches', () async {
      // 1. Authenticate as User A and insert all record types
      await localDb.setUserScope('user_A');

      await localDb.saveProfile(
        LocalProfileRecord(
          id: 'user_A',
          userId: 'user_A',
          displayName: 'Alice',
          verificationLevel: 'verified',
          rawJson: '{"display_name":"Alice"}',
          updatedAt: DateTime.now(),
        ),
      );

      final tripA = LocalTripRecord(
        id: 'trip_A_001',
        userId: 'user_A',
        destination: 'Reykjavik',
        origin: 'London',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 5),
        purpose: 'nature',
        budget: 'moderate',
        status: 'published',
        rawJson: '{"destination":"Reykjavik"}',
        updatedAt: DateTime.now(),
      );

      final prefA = LocalTripPreferencesRecord(
        id: 'pref_A_001',
        tripId: 'trip_A_001',
        userId: 'user_A',
        preferredGender: 'female_only',
        travelPace: 'flexible',
        budgetTier: 'moderate',
        rawJson: '{"preferredGender":"female_only"}',
        updatedAt: DateTime.now(),
      );

      await localDb.saveTripWithPreferences(trip: tripA, preferences: prefA);

      await localDb.saveItinerary(
        LocalItineraryRecord(
          id: 'itin_A_001',
          tripId: 'trip_A_001',
          userId: 'user_A',
          title: 'Golden Circle Day 1',
          daysJson: '["Thingvellir", "Geysir", "Gullfoss"]',
          updatedAt: DateTime.now(),
        ),
      );

      await localDb.enqueueSyncOperation(
        LocalSyncQueueRecord(
          id: 'sync_A_001',
          userId: 'user_A',
          operationId: 'op_A_uuid_001',
          entityType: 'trip',
          entityId: 'trip_A_001',
          operationType: 'create',
          payload: '{"destination":"Reykjavik"}',
          createdAt: DateTime.now(),
          status: 'PENDING',
        ),
      );

      // 2. Switch to User B and populate records
      await localDb.setUserScope('user_B');

      await localDb.saveProfile(
        LocalProfileRecord(
          id: 'user_B',
          userId: 'user_B',
          displayName: 'Bob',
          verificationLevel: 'verified',
          rawJson: '{"display_name":"Bob"}',
          updatedAt: DateTime.now(),
        ),
      );

      final tripB = LocalTripRecord(
        id: 'trip_B_001',
        userId: 'user_B',
        destination: 'Munich',
        origin: 'Berlin',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 6),
        purpose: 'beer_culture',
        budget: 'budget',
        status: 'published',
        rawJson: '{"destination":"Munich"}',
        updatedAt: DateTime.now(),
      );

      final prefB = LocalTripPreferencesRecord(
        id: 'pref_B_001',
        tripId: 'trip_B_001',
        userId: 'user_B',
        preferredGender: 'any',
        travelPace: 'active',
        budgetTier: 'budget',
        rawJson: '{"preferredGender":"any"}',
        updatedAt: DateTime.now(),
      );

      await localDb.saveTripWithPreferences(trip: tripB, preferences: prefB);

      // 3. Verify while active as User B: User A's records CANNOT be accessed
      expect(
        () => localDb.getUserTrips('user_A'),
        throwsA(isA<DatabaseUserScopeException>()),
      );
      expect(
        () => localDb.getProfile('user_A'),
        throwsA(isA<DatabaseUserScopeException>()),
      );
      expect(
        () => localDb.deleteTrip('trip_A_001'),
        throwsA(isA<DatabaseUserScopeException>()),
      );
      expect(
        () => localDb.getPendingSyncOperations('user_A'),
        throwsA(isA<DatabaseUserScopeException>()),
      );

      // 4. Logout User B (purge User B cache)
      await localDb.clearUserScopedData('user_B');

      // 5. Switch back to User A
      await localDb.setUserScope('user_A');

      // Verify User A data is 100% intact
      final tripsForA = await localDb.getUserTrips('user_A');
      expect(tripsForA.length, 1);
      expect(tripsForA.first.destination, 'Reykjavik');

      final profileA = await localDb.getProfile('user_A');
      expect(profileA?.displayName, 'Alice');

      final itinA = await localDb.getItinerary('trip_A_001');
      expect(itinA?.title, 'Golden Circle Day 1');

      final pendingA = await localDb.getPendingSyncOperations('user_A');
      expect(pendingA.length, 1);
    });

    test('12.2.11 SQLite Inspection Test: database columns contain zero forbidden fields', () async {
      final inspectedTables = [
        'local_profiles',
        'local_trips',
        'local_trip_preferences',
        'local_itineraries',
        'local_sync_queue',
      ];

      for (final table in inspectedTables) {
        final tableInfo = await localDb.database.rawQuery('PRAGMA table_info($table);');
        final columnNames = tableInfo.map((row) => (row['name'] as String).toLowerCase()).toSet();

        for (final prohibitedField in LocalDataPolicy.prohibitedFields) {
          expect(
            columnNames.contains(prohibitedField),
            isFalse,
            reason: 'Table "$table" unexpectedly contains forbidden column "$prohibitedField"',
          );
        }

        // Specifically ensure phone, email, and password columns do not exist in local tables
        expect(columnNames.contains('phone'), isFalse);
        expect(columnNames.contains('email'), isFalse);
        expect(columnNames.contains('password'), isFalse);
        expect(columnNames.contains('auth_token'), isFalse);
      }
    });
  });
}
