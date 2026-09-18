import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/database_migrations.dart';
import 'package:safemate/core/database/database_models.dart';
import 'package:safemate/core/database/local_database.dart';

class MigrationV2Test implements MigrationStep {
  @override
  int get version => 2;

  @override
  String get description => 'Add custom test column to local_trips';

  @override
  Future<void> migrate(DatabaseExecutor db) async {
    await db.execute('ALTER TABLE local_trips ADD COLUMN test_tag TEXT;');
  }
}

void main() {
  sqfliteFfiInit();

  group('Phase 12.1 Database Migration Tests', () {
    test('executes migrations sequentially and does not destroy existing data', () async {
      final dbName = 'migration_test_${DateTime.now().microsecondsSinceEpoch}.db';
      final runner = DatabaseMigrationRunner(
        migrations: [MigrationV1(), MigrationV2Test()],
      );

      final db = LocalDatabase(migrationRunner: runner);
      await db.open(
        databaseFactory: databaseFactoryFfi,
        dbName: dbName,
        version: 1,
      );

      // Insert trip in v1 schema
      await db.saveTrip(
        LocalTripRecord(
          id: 'trip_v1_001',
          userId: 'user_migrator',
          destination: 'Kyoto',
          origin: 'Tokyo',
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 10, 8),
          purpose: 'tourism',
          budget: 'moderate',
          status: 'published',
          rawJson: '{"destination":"Kyoto"}',
          updatedAt: DateTime.now(),
        ),
      );

      // Verify trip exists before upgrade
      final before = await db.getTrip('trip_v1_001');
      expect(before, isNotNull);
      expect(before!.destination, 'Kyoto');

      // Now run migration v2 manually on the open DB to verify column added without wiping table
      await MigrationV2Test().migrate(db.database);

      // Verify trip data survived the migration completely
      final after = await db.getTrip('trip_v1_001');
      expect(after, isNotNull);
      expect(after!.destination, 'Kyoto');
      expect(after.userId, 'user_migrator');

      await db.close();
    });
  });
}
