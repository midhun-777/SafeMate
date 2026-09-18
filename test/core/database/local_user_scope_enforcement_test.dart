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
      dbName: 'user_scope_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
  });

  tearDown(() async {
    await localDb.close();
  });

  group('Phase 12.2 User Scope Enforcement Tests (12.2.3, 12.2.4, 12.2.5)', () {
    test('User A cannot write or save records for User B', () async {
      await localDb.setUserScope('user_A');

      final tripForB = LocalTripRecord(
        id: 'trip_B_001',
        userId: 'user_B',
        destination: 'Rome',
        origin: 'Milan',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 5),
        purpose: 'leisure',
        budget: 'moderate',
        status: 'published',
        rawJson: '{"destination":"Rome"}',
        updatedAt: DateTime.now(),
      );

      // Attempting to write a record for user_B while scoped as user_A must fail
      expect(
        () => localDb.saveTrip(tripForB),
        throwsA(isA<DatabaseUserScopeException>()),
      );

      final profileForB = LocalProfileRecord(
        id: 'user_B',
        userId: 'user_B',
        displayName: 'Bob',
        verificationLevel: 'verified',
        rawJson: '{"display_name":"Bob"}',
        updatedAt: DateTime.now(),
      );

      expect(
        () => localDb.saveProfile(profileForB),
        throwsA(isA<DatabaseUserScopeException>()),
      );
    });

    test('User A cannot query trips or profiles belonging to User B', () async {
      // Seed user_B record using privileged system scope
      await localDb.runAsSystem(() async {
        await localDb.saveTrip(
          LocalTripRecord(
            id: 'trip_B_secret',
            userId: 'user_B',
            destination: 'Venice',
            origin: 'Florence',
            startDate: DateTime(2026, 10, 10),
            endDate: DateTime(2026, 10, 15),
            purpose: 'sightseeing',
            budget: 'luxury',
            status: 'draft',
            rawJson: '{"destination":"Venice"}',
            updatedAt: DateTime.now(),
          ),
        );
      });

      // Now operate as user_A
      await localDb.setUserScope('user_A');

      expect(
        () => localDb.getUserTrips('user_B'),
        throwsA(isA<DatabaseUserScopeException>()),
      );

      expect(
        () => localDb.getProfile('user_B'),
        throwsA(isA<DatabaseUserScopeException>()),
      );

      // Querying without explicit userId filters strictly by user_A, returning null
      final trip = await localDb.getTrip('trip_B_secret');
      expect(trip, isNull);
    });

    test('User A cannot delete a trip belonging to User B', () async {
      // Seed user_B trip using privileged system scope
      await localDb.runAsSystem(() async {
        await localDb.saveTrip(
          LocalTripRecord(
            id: 'trip_B_protected',
            userId: 'user_B',
            destination: 'Naples',
            origin: 'Rome',
            startDate: DateTime(2026, 11, 1),
            endDate: DateTime(2026, 11, 5),
            purpose: 'food',
            budget: 'budget',
            status: 'published',
            rawJson: '{"destination":"Naples"}',
            updatedAt: DateTime.now(),
          ),
        );
      });

      // Now authenticate as user_A
      await localDb.setUserScope('user_A');

      await expectLater(
        localDb.deleteTrip('trip_B_protected'),
        throwsA(isA<DatabaseUserScopeException>()),
      );

      // Verify trip still exists for user_B
      await localDb.runAsSystem(() async {
        final check = await localDb.getTrip('trip_B_protected', userId: 'user_B');
        expect(check, isNotNull);
      });
    });
  });
}
