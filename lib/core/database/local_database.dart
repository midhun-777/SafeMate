/// SafeMate Local Database Foundation.
/// Universal Engineering Rule #6: Strict field validation — never store secrets in SQLite.
/// Universal Engineering Rule #10: Multi-user isolation, transaction safety, and logout purge.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sq;

import 'database_exceptions.dart';
import 'database_migrations.dart';
import 'database_models.dart';
import 'database_schema.dart';
import 'local_data_policy.dart';

/// Central SQLite Database Access Layer for SafeMate.
class LocalDatabase {
  sq.Database? _db;
  String? _currentUserId;
  bool _isPrivileged = false;
  final DatabaseMigrationRunner _migrationRunner;

  LocalDatabase({DatabaseMigrationRunner? migrationRunner})
      : _migrationRunner = migrationRunner ?? DatabaseMigrationRunner();

  /// Current session-bound authenticated user ID.
  String? get currentUserId => _currentUserId;

  /// Returns true if the database is open and initialized.
  bool get isOpen => _db != null && _db!.isOpen;

  /// Underlying database instance.
  sq.Database get database {
    final db = _db;
    if (db == null || !db.isOpen) {
      throw const DatabaseInitializationException(
        'Database has not been opened or has been closed. Call open() first.',
      );
    }
    return db;
  }

  /// Executes an operation in privileged system scope (e.g. fixtures or migrations).
  Future<T> runAsSystem<T>(Future<T> Function() action) async {
    final prev = _isPrivileged;
    _isPrivileged = true;
    try {
      return await action();
    } finally {
      _isPrivileged = prev;
    }
  }

  /// Sets the active local user session scope.
  Future<void> setUserScope(String userId) async {
    _currentUserId = userId;
    final db = database;
    try {
      await db.insert(
        DatabaseSchema.tableUserScope,
        LocalUserScopeRecord(
          id: 'scope_$userId',
          userId: userId,
          isActive: true,
          lastSwitchedAt: DateTime.now(),
        ).toMap(),
        conflictAlgorithm: sq.ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw DatabaseWriteException('Failed to set user scope: ${e.toString()}', e);
    }
  }

  /// Clears the active session user scope.
  void clearUserScope() {
    _currentUserId = null;
  }

  /// Enforces active user scoping.
  void _assertUserScope(String targetUserId, {required String operation}) {
    if (_isPrivileged) return;
    if (_currentUserId != null && _currentUserId != targetUserId) {
      LocalDataPolicy.logPolicyViolation(
        violationType: 'CROSS_ACCOUNT_ACCESS_DENIED',
        tableName: 'user_scoped_operation',
        operation: operation,
      );
      throw DatabaseUserScopeException(
        'User-scope violation: active user "$_currentUserId" is not authorized to $operation data for "$targetUserId".',
        null,
        _currentUserId!,
        targetUserId,
      );
    }
  }

  /// Opens and initializes the SQLite database with migrations.
  Future<void> open({
    sq.DatabaseFactory? databaseFactory,
    String? dbName,
    int? version,
  }) async {
    if (isOpen) return;

    final name = dbName ?? 'safemate_local.db';
    final targetVer = version ?? DatabaseSchema.currentVersion;
    try {
      if (databaseFactory != null) {
        _db = await databaseFactory.openDatabase(
          name,
          options: sq.OpenDatabaseOptions(
            version: targetVer,
            onCreate: (db, ver) async {
              await _migrationRunner.runMigrations(
                db,
                currentVersion: 0,
                targetVersion: ver,
              );
            },
            onUpgrade: (db, oldVersion, newVersion) async {
              await _migrationRunner.runMigrations(
                db,
                currentVersion: oldVersion,
                targetVersion: newVersion,
              );
            },
          ),
        );
      } else {
        final databasesPath = await sq.getDatabasesPath();
        final dbPath = p.join(databasesPath, name);
        _db = await sq.openDatabase(
          dbPath,
          version: targetVer,
          onCreate: (db, ver) async {
            await _migrationRunner.runMigrations(
              db,
              currentVersion: 0,
              targetVersion: ver,
            );
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            await _migrationRunner.runMigrations(
              db,
              currentVersion: oldVersion,
              targetVersion: newVersion,
            );
          },
        );
      }
    } catch (e) {
      if (e is SafeMateDatabaseException) rethrow;
      throw DatabaseInitializationException(
        'Failed to initialize local SQLite database: ${e.toString()}',
        e,
      );
    }
  }

  /// Closes database connection cleanly.
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
      _currentUserId = null;
    }
  }

  /// Executes multiple database operations inside a single ACID transaction.
  Future<T> transaction<T>(Future<T> Function(sq.Transaction txn) action) async {
    final db = database;
    try {
      return await db.transaction<T>(action);
    } catch (e) {
      if (e is SafeMateDatabaseException) rethrow;
      throw DatabaseWriteException('Transaction failed and was rolled back: ${e.toString()}', e);
    }
  }

  /// Creates a batch runner for bulk writes.
  sq.Batch batch() => database.batch();

  // ---------------------------------------------------------------------------
  // PROFILE OPERATIONS (User Scoped)
  // ---------------------------------------------------------------------------

  Future<void> saveProfile(LocalProfileRecord profile) async {
    _assertUserScope(profile.userId, operation: 'saveProfile');
    final map = profile.toMap();
    LocalDataPolicy.validateTableWrite(DatabaseSchema.tableProfiles, map);

    final db = database;
    try {
      await db.insert(
        DatabaseSchema.tableProfiles,
        map,
        conflictAlgorithm: sq.ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (e is SafeMateDatabaseException) rethrow;
      throw DatabaseWriteException('Failed to save profile for ${profile.userId}', e);
    }
  }

  Future<LocalProfileRecord?> getProfile(String userId) async {
    _assertUserScope(userId, operation: 'getProfile');
    final db = database;
    try {
      final rows = await db.query(
        DatabaseSchema.tableProfiles,
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return LocalProfileRecord.fromMap(rows.first);
    } catch (e) {
      if (e is SafeMateDatabaseException) rethrow;
      throw DatabaseReadException('Failed to read profile for $userId', e);
    }
  }

  // ---------------------------------------------------------------------------
  // TRIP OPERATIONS (User Scoped & Transaction Safe)
  // ---------------------------------------------------------------------------

  Future<void> saveTrip(LocalTripRecord trip) async {
    _assertUserScope(trip.userId, operation: 'saveTrip');
    final map = trip.toMap();
    LocalDataPolicy.validateTableWrite(DatabaseSchema.tableTrips, map);

    final db = database;
    try {
      await db.insert(
        DatabaseSchema.tableTrips,
        map,
        conflictAlgorithm: sq.ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (e is SafeMateDatabaseException) rethrow;
      throw DatabaseWriteException('Failed to save trip ${trip.id}', e);
    }
  }

  Future<void> saveTripWithPreferences({
    required LocalTripRecord trip,
    required LocalTripPreferencesRecord preferences,
  }) async {
    _assertUserScope(trip.userId, operation: 'saveTripWithPreferences');
    _assertUserScope(preferences.userId, operation: 'saveTripWithPreferences');

    final tripMap = trip.toMap();
    final prefMap = preferences.toMap();
    LocalDataPolicy.validateTableWrite(DatabaseSchema.tableTrips, tripMap);
    LocalDataPolicy.validateTableWrite(DatabaseSchema.tableTripPreferences, prefMap);

    await transaction((txn) async {
      await txn.insert(
        DatabaseSchema.tableTrips,
        tripMap,
        conflictAlgorithm: sq.ConflictAlgorithm.replace,
      );
      await txn.insert(
        DatabaseSchema.tableTripPreferences,
        prefMap,
        conflictAlgorithm: sq.ConflictAlgorithm.replace,
      );
    });
  }

  Future<LocalTripRecord?> getTrip(String tripId, {String? userId}) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (userId != null) {
      _assertUserScope(userId, operation: 'getTrip');
    }

    final db = database;
    try {
      final whereClause = effectiveUserId != null && !_isPrivileged
          ? 'id = ? AND user_id = ?'
          : 'id = ?';
      final whereArgs = effectiveUserId != null && !_isPrivileged
          ? [tripId, effectiveUserId]
          : [tripId];

      final rows = await db.query(
        DatabaseSchema.tableTrips,
        where: whereClause,
        whereArgs: whereArgs,
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return LocalTripRecord.fromMap(rows.first);
    } catch (e) {
      if (e is SafeMateDatabaseException) rethrow;
      throw DatabaseReadException('Failed to query trip $tripId', e);
    }
  }

  Future<List<LocalTripRecord>> getUserTrips(String userId) async {
    _assertUserScope(userId, operation: 'getUserTrips');
    final db = database;
    try {
      final rows = await db.query(
        DatabaseSchema.tableTrips,
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'start_date ASC',
      );
      return rows.map((r) => LocalTripRecord.fromMap(r)).toList();
    } catch (e) {
      if (e is SafeMateDatabaseException) rethrow;
      throw DatabaseReadException('Failed to query trips for user $userId', e);
    }
  }

  Future<LocalTripPreferencesRecord?> getTripPreferences(String tripId) async {
    final db = database;
    try {
      final rows = await db.query(
        DatabaseSchema.tableTripPreferences,
        where: 'trip_id = ?',
        whereArgs: [tripId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final pref = LocalTripPreferencesRecord.fromMap(rows.first);
      if (_currentUserId != null && !_isPrivileged && pref.userId != _currentUserId) {
        throw DatabaseUserScopeException(
          'Cannot read preferences belonging to another user',
          null,
          _currentUserId!,
          pref.userId,
        );
      }
      return pref;
    } catch (e) {
      if (e is SafeMateDatabaseException) rethrow;
      throw DatabaseReadException('Failed to read trip preferences for trip $tripId', e);
    }
  }

  Future<void> deleteTrip(String tripId, {String? userId}) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (userId != null) {
      _assertUserScope(userId, operation: 'deleteTrip');
    }

    try {
      await transaction((txn) async {
        // Verify ownership if active user scope exists
        if (effectiveUserId != null && !_isPrivileged) {
          final existing = await txn.query(
            DatabaseSchema.tableTrips,
            where: 'id = ?',
            whereArgs: [tripId],
            limit: 1,
          );
          if (existing.isNotEmpty && existing.first['user_id'] != effectiveUserId) {
            LocalDataPolicy.logPolicyViolation(
              violationType: 'CROSS_ACCOUNT_ACCESS_DENIED',
              tableName: 'user_scoped_operation',
              operation: 'deleteTrip',
            );
            throw DatabaseUserScopeException(
              'Cannot delete trip belonging to user "${existing.first['user_id']}" while authenticated as "$effectiveUserId".',
              null,
              effectiveUserId,
              existing.first['user_id'] as String,
            );
          }
        }

        final whereClause = effectiveUserId != null ? 'id = ? AND user_id = ?' : 'id = ?';
        final whereArgs = effectiveUserId != null ? [tripId, effectiveUserId] : [tripId];

        await txn.delete(DatabaseSchema.tableTrips, where: whereClause, whereArgs: whereArgs);
        await txn.delete(DatabaseSchema.tableTripPreferences, where: 'trip_id = ?', whereArgs: [tripId]);
        await txn.delete(DatabaseSchema.tableItineraries, where: 'trip_id = ?', whereArgs: [tripId]);
      });
    } catch (e) {
      if (e is SafeMateDatabaseException) rethrow;
      throw DatabaseWriteException('Failed to delete trip $tripId', e);
    }
  }

  // ---------------------------------------------------------------------------
  // ITINERARY OPERATIONS
  // ---------------------------------------------------------------------------

  Future<void> saveItinerary(LocalItineraryRecord itinerary) async {
    _assertUserScope(itinerary.userId, operation: 'saveItinerary');
    final map = itinerary.toMap();
    LocalDataPolicy.validateTableWrite(DatabaseSchema.tableItineraries, map);

    final db = database;
    try {
      await db.insert(
        DatabaseSchema.tableItineraries,
        map,
        conflictAlgorithm: sq.ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (e is SafeMateDatabaseException) rethrow;
      throw DatabaseWriteException('Failed to save itinerary for ${itinerary.tripId}', e);
    }
  }

  Future<LocalItineraryRecord?> getItinerary(String tripId) async {
    final db = database;
    try {
      final rows = await db.query(
        DatabaseSchema.tableItineraries,
        where: 'trip_id = ?',
        whereArgs: [tripId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final itin = LocalItineraryRecord.fromMap(rows.first);
      if (_currentUserId != null && !_isPrivileged && itin.userId != _currentUserId) {
        throw DatabaseUserScopeException(
          'Cannot read itinerary belonging to another user',
          null,
          _currentUserId!,
          itin.userId,
        );
      }
      return itin;
    } catch (e) {
      if (e is SafeMateDatabaseException) rethrow;
      throw DatabaseReadException('Failed to read itinerary for trip $tripId', e);
    }
  }

  // ---------------------------------------------------------------------------
  // SYNC QUEUE OPERATIONS (Phase 12.1 Foundation Only)
  // ---------------------------------------------------------------------------

  Future<void> enqueueSyncOperation(LocalSyncQueueRecord record) async {
    _assertUserScope(record.userId, operation: 'enqueueSyncOperation');
    final map = record.toMap();
    LocalDataPolicy.validateTableWrite(DatabaseSchema.tableSyncQueue, map);

    try {
      final payloadMap = jsonDecode(record.payload) as Map<String, dynamic>;
      LocalDataPolicy.validateSyncPayload(record.entityType, record.operationType, payloadMap);
    } catch (e) {
      if (e is SafeMateDatabaseException) rethrow;
      // If payload is not valid JSON or violates policy, reject
      throw DatabasePolicyViolationException(
        'Malformed sync payload for operation ${record.operationId}: ${e.toString()}',
        e,
        'local_sync_queue',
      );
    }

    final db = database;
    try {
      await db.insert(
        DatabaseSchema.tableSyncQueue,
        map,
        conflictAlgorithm: sq.ConflictAlgorithm.abort, // Strictly reject duplicate operation_id
      );
    } catch (e) {
      if (e is SafeMateDatabaseException) rethrow;
      if (e.toString().contains('UNIQUE') || e.toString().contains('constraint')) {
        throw DatabaseConstraintException(
          'Duplicate sync operation: operation_id ${record.operationId} already exists.',
          e,
          'idx_sync_queue_op_id',
        );
      }
      throw DatabaseWriteException('Failed to enqueue sync operation ${record.operationId}', e);
    }
  }

  Future<List<LocalSyncQueueRecord>> getPendingSyncOperations(String userId) async {
    _assertUserScope(userId, operation: 'getPendingSyncOperations');
    final db = database;
    try {
      final rows = await db.query(
        DatabaseSchema.tableSyncQueue,
        where: 'user_id = ? AND status = ?',
        whereArgs: [userId, 'PENDING'],
        orderBy: 'created_at ASC',
      );
      return rows.map((r) => LocalSyncQueueRecord.fromMap(r)).toList();
    } catch (e) {
      if (e is SafeMateDatabaseException) rethrow;
      throw DatabaseReadException('Failed to read pending sync operations for user $userId', e);
    }
  }

  Future<void> updateSyncOperationStatus(
    String operationId,
    String status, {
    String? lastError,
  }) async {
    final db = database;
    try {
      await db.update(
        DatabaseSchema.tableSyncQueue,
        {
          'status': status,
          'last_error': lastError,
        },
        where: 'operation_id = ?',
        whereArgs: [operationId],
      );
    } catch (e) {
      if (e is SafeMateDatabaseException) rethrow;
      throw DatabaseWriteException('Failed to update sync operation $operationId', e);
    }
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT SWITCH & LOGOUT PURGE (Registry Driven)
  // ---------------------------------------------------------------------------

  /// Clears all Category A and Category B cached records for [userId].
  /// Dynamically derived from the central TablePolicy registry (Section 12.2.7).
  Future<void> clearUserScopedData(String userId) async {
    final db = database;
    try {
      // 1. Inspect physical SQLite tables to ensure no unregistered user table exists (fail-fast rule)
      final masterTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%';",
      );
      final actualTableNames = masterTables.map((r) => r['name'] as String).toSet();

      for (final tableName in actualTableNames) {
        if (!LocalDataPolicy.tablePolicyRegistry.containsKey(tableName)) {
          throw DatabasePolicyViolationException(
            'Fail-Fast: Database contains unregistered table "$tableName" not defined in LocalDataPolicy.',
            null,
            tableName,
          );
        }
      }

      // 2. Perform purge on all registered user-scoped tables
      await transaction((txn) async {
        final userScopedPolicies = LocalDataPolicy.tablePolicyRegistry.values
            .where((policy) => policy.isUserScoped);

        for (final policy in userScopedPolicies) {
          if (actualTableNames.contains(policy.tableName)) {
            final userCol = policy.userIdColumn ?? 'user_id';
            await txn.delete(
              policy.tableName,
              where: '$userCol = ?',
              whereArgs: [userId],
            );
          }
        }
      });

      if (_currentUserId == userId) {
        _currentUserId = null;
      }
      debugPrint('[SafeMate LocalDatabase] Successfully cleared user-scoped cache for: $userId');
    } catch (e) {
      if (e is SafeMateDatabaseException) rethrow;
      throw DatabaseWriteException('Failed to purge user-scoped data for user $userId', e);
    }
  }
}
