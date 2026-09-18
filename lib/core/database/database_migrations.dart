/// SafeMate Database Migrations Framework.
/// Universal Engineering Rule #6: Never destroy user data across schema evolution.
library;

import 'package:sqflite/sqflite.dart' as sq;
import 'database_exceptions.dart';
import 'database_schema.dart';

/// Contract for a single database migration step.
abstract class MigrationStep {
  int get version;
  String get description;
  Future<void> migrate(sq.DatabaseExecutor db);
}

/// Migration Step 1: Initial Local SQLite Foundation Tables & Indexes.
class MigrationV1 implements MigrationStep {
  @override
  int get version => 1;

  @override
  String get description =>
      'Initial Local SQLite Foundation (UserScope, Profiles, Trips, TripPreferences, Itineraries, SyncQueue)';

  @override
  Future<void> migrate(sq.DatabaseExecutor db) async {
    // 1. Core local tables
    await db.execute(DatabaseSchema.createUserScopeTable);
    await db.execute(DatabaseSchema.createProfilesTable);
    await db.execute(DatabaseSchema.createTripsTable);
    await db.execute(DatabaseSchema.createTripPreferencesTable);
    await db.execute(DatabaseSchema.createItinerariesTable);
    await db.execute(DatabaseSchema.createSyncQueueTable);

    // 2. Compatibility tables for Phase 12 chat, safetrip & sync
    await db.execute(DatabaseSchema.createLocalSyncQueueTable);
    await db.execute(DatabaseSchema.createChatMessagesTable);
    await db.execute(DatabaseSchema.createSafeTripsTable);
    await db.execute(DatabaseSchema.createCheckinsTable);

    // 3. Performance & isolation indexes
    for (final indexSql in DatabaseSchema.createIndexes) {
      await db.execute(indexSql);
    }
  }
}

/// Migration Step 2: Optimistic concurrency locking & server versioning.
class MigrationV2 implements MigrationStep {
  @override
  int get version => 2;

  @override
  String get description =>
      'Add server versioning, optimistic locking, and harmonized sync queue schema';

  @override
  Future<void> migrate(sq.DatabaseExecutor db) async {
    // 1. Add versioning columns to local_trips
    await _safeAddColumn(db, 'local_trips', 'server_version INTEGER NOT NULL DEFAULT 1');
    await _safeAddColumn(db, 'local_trips', 'base_server_version INTEGER NOT NULL DEFAULT 1');
    await _safeAddColumn(db, 'local_trips', 'local_revision INTEGER NOT NULL DEFAULT 0');

    // 2. Add versioning columns to local_profiles
    await _safeAddColumn(db, 'local_profiles', 'server_version INTEGER NOT NULL DEFAULT 1');
    await _safeAddColumn(db, 'local_profiles', 'base_server_version INTEGER NOT NULL DEFAULT 1');
    await _safeAddColumn(db, 'local_profiles', 'local_revision INTEGER NOT NULL DEFAULT 0');

    // 3. Add versioning columns to local_trip_preferences
    await _safeAddColumn(db, 'local_trip_preferences', 'server_version INTEGER NOT NULL DEFAULT 1');
    await _safeAddColumn(db, 'local_trip_preferences', 'base_server_version INTEGER NOT NULL DEFAULT 1');
    await _safeAddColumn(db, 'local_trip_preferences', 'local_revision INTEGER NOT NULL DEFAULT 0');

    // 4. Add versioning columns to local_itineraries
    await _safeAddColumn(db, 'local_itineraries', 'server_version INTEGER NOT NULL DEFAULT 1');
    await _safeAddColumn(db, 'local_itineraries', 'base_server_version INTEGER NOT NULL DEFAULT 1');
    await _safeAddColumn(db, 'local_itineraries', 'local_revision INTEGER NOT NULL DEFAULT 0');

    // 5. Add versioning and harmonized columns to sync_queue
    await _safeAddColumn(db, 'sync_queue', 'base_server_version INTEGER');
    await _safeAddColumn(db, 'sync_queue', 'local_revision INTEGER DEFAULT 1');
    await _safeAddColumn(db, 'sync_queue', 'id TEXT');
    await _safeAddColumn(db, 'sync_queue', 'operation_type TEXT');
    await _safeAddColumn(db, 'sync_queue', 'payload TEXT');
    await _safeAddColumn(db, 'sync_queue', 'attempt_count INTEGER DEFAULT 0');
    await _safeAddColumn(db, 'sync_queue', 'next_attempt_at TEXT');
    await _safeAddColumn(db, 'sync_queue', 'last_error TEXT');

    // 6. Ensure local_sync_queue records are copied into sync_queue if local_sync_queue exists
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='local_sync_queue';",
    );
    if (tables.isNotEmpty) {
      await db.execute('''
        INSERT OR IGNORE INTO sync_queue (
          operation_id, user_id, entity_type, entity_id, action, payload_json,
          status, retry_count, error_message, created_at,
          id, operation_type, payload, attempt_count, next_attempt_at, last_error
        )
        SELECT 
          operation_id, user_id, entity_type, entity_id, operation_type, payload,
          status, attempt_count, last_error, created_at,
          id, operation_type, payload, attempt_count, next_attempt_at, last_error
        FROM local_sync_queue;
      ''');
    }
  }

  Future<void> _safeAddColumn(sq.DatabaseExecutor db, String table, String colDef) async {
    final colName = colDef.split(' ').first;
    final info = await db.rawQuery('PRAGMA table_info($table);');
    final exists = info.any((col) => col['name'] == colName);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $colDef;');
    }
  }
}

/// Runner that executes migrations in strict ascending sequence.
class DatabaseMigrationRunner {
  final List<MigrationStep> _registeredMigrations;

  DatabaseMigrationRunner({List<MigrationStep>? migrations})
      : _registeredMigrations = migrations ?? [MigrationV1(), MigrationV2()];

  /// List of registered migration steps sorted by version.
  List<MigrationStep> get migrations {
    final sorted = List<MigrationStep>.from(_registeredMigrations);
    sorted.sort((a, b) => a.version.compareTo(b.version));
    return List.unmodifiable(sorted);
  }

  /// Executes all pending migrations from [currentVersion] up to [targetVersion].
  Future<void> runMigrations(
    sq.DatabaseExecutor db, {
    required int currentVersion,
    required int targetVersion,
  }) async {
    if (currentVersion >= targetVersion) return;

    for (final step in migrations) {
      if (step.version > currentVersion && step.version <= targetVersion) {
        try {
          await step.migrate(db);
        } catch (e) {
          throw DatabaseMigrationException(
            'Failed migrating database from v$currentVersion to v${step.version}: ${e.toString()}',
            e,
            currentVersion,
            step.version,
          );
        }
      }
    }
  }
}
