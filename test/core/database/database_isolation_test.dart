import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/database_models.dart';
import 'package:safemate/core/database/local_database.dart';

void main() {
  sqfliteFfiInit();

  late LocalDatabase localDb;

  setUp(() async {
    localDb = LocalDatabase();
    await localDb.open(
      databaseFactory: databaseFactoryFfi,
      dbName: 'isolation_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
  });

  tearDown(() async {
    await localDb.close();
  });

  group('Phase 12.1 Database User Isolation Tests (12.1.17)', () {
    test('User A cannot query User B records and User B cannot query User A records', () async {
      // 1. Setup User A records
      await localDb.saveProfile(
        LocalProfileRecord(
          id: 'user_A',
          userId: 'user_A',
          displayName: 'Alice Traveler',
          bio: 'Solo backpacker',
          verificationLevel: 'verified',
          rawJson: '{"displayName":"Alice Traveler"}',
          updatedAt: DateTime.now(),
        ),
      );

      await localDb.saveTrip(
        LocalTripRecord(
          id: 'trip_A',
          userId: 'user_A',
          destination: 'Reykjavik',
          origin: 'London',
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 7),
          purpose: 'adventure',
          budget: 'moderate',
          status: 'published',
          rawJson: '{"destination":"Reykjavik"}',
          updatedAt: DateTime.now(),
        ),
      );

      // 2. Setup User B records
      await localDb.saveProfile(
        LocalProfileRecord(
          id: 'user_B',
          userId: 'user_B',
          displayName: 'Bob Explorer',
          bio: 'Mountain hiker',
          verificationLevel: 'verified',
          rawJson: '{"displayName":"Bob Explorer"}',
          updatedAt: DateTime.now(),
        ),
      );

      await localDb.saveTrip(
        LocalTripRecord(
          id: 'trip_B',
          userId: 'user_B',
          destination: 'Zermatt',
          origin: 'Geneva',
          startDate: DateTime(2026, 12, 1),
          endDate: DateTime(2026, 12, 10),
          purpose: 'hiking',
          budget: 'luxury',
          status: 'published',
          rawJson: '{"destination":"Zermatt"}',
          updatedAt: DateTime.now(),
        ),
      );

      // 3. Query as User A
      final tripsForA = await localDb.getUserTrips('user_A');
      final profileForA = await localDb.getProfile('user_A');

      expect(tripsForA.map((t) => t.id), contains('trip_A'));
      expect(tripsForA.map((t) => t.id), isNot(contains('trip_B')));
      expect(profileForA?.displayName, 'Alice Traveler');

      // Scoped trip query
      final tripAforA = await localDb.getTrip('trip_A', userId: 'user_A');
      expect(tripAforA, isNotNull);
      final tripBforA = await localDb.getTrip('trip_B', userId: 'user_A');
      expect(tripBforA, isNull);

      // 4. Query as User B
      final tripsForB = await localDb.getUserTrips('user_B');
      final profileForB = await localDb.getProfile('user_B');

      expect(tripsForB.map((t) => t.id), contains('trip_B'));
      expect(tripsForB.map((t) => t.id), isNot(contains('trip_A')));
      expect(profileForB?.displayName, 'Bob Explorer');

      // Scoped trip query
      final tripBforB = await localDb.getTrip('trip_B', userId: 'user_B');
      expect(tripBforB, isNotNull);
      final tripAforB = await localDb.getTrip('trip_A', userId: 'user_B');
      expect(tripAforB, isNull);
    });
  });
}
