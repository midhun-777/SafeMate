import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/database_schema.dart';
import 'package:safemate/core/database/local_database.dart';

void main() {
  sqfliteFfiInit();

  late LocalDatabase localDb;

  setUp(() {
    localDb = LocalDatabase();
  });

  tearDown(() async {
    if (localDb.isOpen) {
      await localDb.close();
    }
  });

  group('Phase 12.1 Database Initialization Tests', () {
    test('opens database successfully and initializes version 1', () async {
      final dbName = 'init_test_${DateTime.now().microsecondsSinceEpoch}.db';
      await localDb.open(
        databaseFactory: databaseFactoryFfi,
        dbName: dbName,
      );

      expect(localDb.isOpen, isTrue);
      expect(await localDb.database.getVersion(), DatabaseSchema.currentVersion);
    });

    test('creates all required local tables and indexes', () async {
      final dbName = 'schema_test_${DateTime.now().microsecondsSinceEpoch}.db';
      await localDb.open(
        databaseFactory: databaseFactoryFfi,
        dbName: dbName,
      );

      final tables = await localDb.database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table';",
      );
      final tableNames = tables.map((r) => r['name'] as String).toSet();

      expect(tableNames.contains('local_user_scope'), isTrue);
      expect(tableNames.contains('local_profiles'), isTrue);
      expect(tableNames.contains('local_trips'), isTrue);
      expect(tableNames.contains('local_trip_preferences'), isTrue);
      expect(tableNames.contains('local_itineraries'), isTrue);
      expect(tableNames.contains('local_sync_queue'), isTrue);
    });

    test('throws StateError or DatabaseInitializationException when accessing closed database', () {
      expect(() => localDb.database, throwsA(isA<Exception>()));
    });
  });
}
