import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/database_exceptions.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/sync/sync_error_formatter.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';

void main() {
  sqfliteFfiInit();

  late String dbPath;
  late LocalDatabaseService localDb;

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
    final tempDir = Directory.systemTemp.createTempSync('safemate_sqliterecovery_');
    dbPath = '${tempDir.path}/recovery_test.db';
    localDb = LocalDatabaseService();
    await localDb.initialize(
      databaseFactory: databaseFactoryFfi,
      dbName: dbPath,
    );
  });

  tearDown(() async {
    await localDb.close();
  });

  group('Phase 12.5.7 & 12.5.8 — SQLite Recovery & Low Storage Tests', () {
    test('Open -> Close -> Reopen cycle retains full database integrity', () async {
      final trip = makeTestTrip(
        id: 'trip_persist_1',
        userId: 'user_rec',
        destination: 'Nagano',
      );
      await localDb.saveTrip(trip);

      // Verify trip exists
      expect((await localDb.getTrip('trip_persist_1')), isNotNull);

      // Close connection
      await localDb.close();

      // Reopen connection
      final reopenedDb = LocalDatabaseService();
      await reopenedDb.initialize(
        databaseFactory: databaseFactoryFfi,
        dbName: dbPath,
      );

      try {
        final retrieved = await reopenedDb.getTrip('trip_persist_1');
        expect(retrieved, isNotNull);
        expect(retrieved!.destination, equals('Nagano'));
      } finally {
        await reopenedDb.close();
      }
    });

    test('TRANSACTION ATOMICITY: Failed transaction rolls back with NO PARTIAL USER STATE', () async {
      final db = localDb.database;

      // Execute atomic transaction that fails halfway
      bool threwExpectedException = false;
      try {
        await db.transaction((txn) async {
          // 1. Insert trip
          await txn.insert('local_trips', {
            'id': 'trip_atomic_fail',
            'user_id': 'user_atomic',
            'destination': 'Sendai',
            'origin': 'Tokyo',
            'start_date': '2026-11-01',
            'end_date': '2026-11-05',
            'purpose': 'soloLeisure',
            'budget': 'flexible',
            'status': 'draft',
            'server_version': 1,
            'base_server_version': 1,
            'local_revision': 1,
            'raw_json': '{}',
            'updated_at': DateTime.now().toIso8601String(),
          });

          // 2. Deliberately trigger failure before transaction commits
          throw const DatabaseWriteException('Simulated crash / disk fault mid-transaction');
        });
      } on DatabaseWriteException {
        threwExpectedException = true;
      }

      expect(threwExpectedException, isTrue);

      // INVARIANT: Failed transaction left NO partial state in database
      final rows = await db.query('local_trips', where: 'id = ?', whereArgs: ['trip_atomic_fail']);
      expect(rows.isEmpty, isTrue,
          reason: 'Failed transaction must roll back cleanly; no orphaned records allowed');
    });

    test('LOW STORAGE: DatabaseLowStorageException produces traveler-safe warning without crash loop', () {
      const lowStorageErr = DatabaseLowStorageException(
        'SQLITE_FULL: database or disk is full',
        null,
        1048576, // 1 MB free
      );

      final userMessage = SyncErrorFormatter.formatUserMessage(lowStorageErr);

      // User must receive clear, actionable explanation to free up space
      expect(userMessage, contains('storage is almost full'));
      expect(userMessage, contains('free up space'));
      expect(userMessage, isNot(contains('SQLITE_FULL')));
      expect(userMessage, isNot(contains('ENOSPC')));
    });

    test('ACCOUNT PURGE: Clearing user data purges scoped records without corrupting schema', () async {
      const userA = 'user_purge_A';
      const userB = 'user_purge_B';

      final tripA = makeTestTrip(id: 'trip_a1', userId: userA, destination: 'Kobe');
      final tripB = makeTestTrip(id: 'trip_b1', userId: userB, destination: 'Hiroshima');

      await localDb.saveTrip(tripA);
      await localDb.saveTrip(tripB);

      // Verify both exist
      expect(await localDb.getTrip('trip_a1'), isNotNull);
      expect(await localDb.getTrip('trip_b1'), isNotNull);

      // Execute user A purge
      await localDb.purgeUserData(userA);

      // User A's data is wiped; User B's data is untouched
      expect(await localDb.getTrip('trip_a1'), isNull);
      expect(await localDb.getTrip('trip_b1'), isNotNull);

      // Schema remains intact for subsequent writes
      final tripA2 = makeTestTrip(id: 'trip_a2', userId: userA, destination: 'Nagasaki');
      await localDb.saveTrip(tripA2);
      expect(await localDb.getTrip('trip_a2'), isNotNull);
    });
  });
}
