/// SafeMate Local SQLite Database Service.
/// Universal Engineering Rule #6: Never store secrets in plain text.
/// Universal Engineering Rule #10: Multi-user isolation and strict logout purge.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sq;

import '../../features/auth/domain/models/user_profile.dart';
import '../../features/connections/domain/models/chat_models.dart';
import '../../features/safety/domain/models/safetrip_models.dart';
import '../../features/trips/domain/models/trip.dart';
import 'database_migrations.dart';
import 'database_models.dart';
import 'database_schema.dart';
import 'local_data_policy.dart';

/// Represents a mutation enqueued in SQLite awaiting server synchronization.
class SyncRecord {
  final String operationId;
  final String userId;
  final String entityType;
  final String entityId;
  final String action; // 'create', 'update', 'delete'
  final Map<String, dynamic> payload;
  final String status; // 'pending', 'syncing', 'synced', 'failed', 'conflict', 'cancelled'
  final int retryCount;
  final DateTime? lastAttemptAt;
  final String? errorMessage;
  final DateTime createdAt;
  final int? baseServerVersion;
  final int localRevision;

  const SyncRecord({
    required this.operationId,
    required this.userId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.payload,
    required this.status,
    this.retryCount = 0,
    this.lastAttemptAt,
    this.errorMessage,
    required this.createdAt,
    this.baseServerVersion,
    this.localRevision = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'operation_id': operationId,
      'user_id': userId,
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'payload_json': jsonEncode(payload),
      'status': status,
      'retry_count': retryCount,
      'last_attempt_at': lastAttemptAt?.toIso8601String(),
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'base_server_version': baseServerVersion,
      'local_revision': localRevision,
      // Compatibility fields
      'id': operationId,
      'operation_type': action,
      'payload': jsonEncode(payload),
      'attempt_count': retryCount,
      'last_error': errorMessage,
    };
  }

  factory SyncRecord.fromMap(Map<String, dynamic> map) {
    return SyncRecord(
      operationId: (map['operation_id'] ?? map['id']) as String,
      userId: map['user_id'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      action: (map['action'] ?? map['operation_type']) as String,
      payload: jsonDecode((map['payload_json'] ?? map['payload']) as String) as Map<String, dynamic>,
      status: map['status'] as String,
      retryCount: ((map['retry_count'] ?? map['attempt_count']) as num?)?.toInt() ?? 0,
      lastAttemptAt: map['last_attempt_at'] != null ? DateTime.tryParse(map['last_attempt_at'] as String) : null,
      errorMessage: (map['error_message'] ?? map['last_error']) as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      baseServerVersion: map['base_server_version'] as int?,
      localRevision: (map['local_revision'] as int?) ?? 1,
    );
  }

  SyncRecord copyWith({
    String? status,
    int? retryCount,
    DateTime? lastAttemptAt,
    String? errorMessage,
    int? baseServerVersion,
    int? localRevision,
  }) {
    return SyncRecord(
      operationId: operationId,
      userId: userId,
      entityType: entityType,
      entityId: entityId,
      action: action,
      payload: payload,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
      baseServerVersion: baseServerVersion ?? this.baseServerVersion,
      localRevision: localRevision ?? this.localRevision,
    );
  }
}

/// Core service managing local SQLite persistence and schema lifecycle.
class LocalDatabaseService {
  sq.Database? _database;

  sq.Database get database {
    final db = _database;
    if (db == null) {
      throw StateError('LocalDatabaseService has not been initialized. Call init() first.');
    }
    return db;
  }

  bool get isInitialized => _database != null;

  /// Initializes the SQLite database. Supports optional [customDatabase] or [databaseFactory] for testing.
  Future<void> init({
    sq.Database? customDatabase,
    sq.DatabaseFactory? databaseFactory,
    String dbName = 'safemate_local.db',
  }) async {
    if (_database != null) return;

    if (customDatabase != null) {
      _database = customDatabase;
      return;
    }

    final factory = databaseFactory ?? sq.databaseFactory;
    final databasesPath = await factory.getDatabasesPath();
    final path = p.join(databasesPath, dbName);

    _database = await factory.openDatabase(
      path,
      options: sq.OpenDatabaseOptions(
        version: DatabaseSchema.currentVersion,
        onCreate: _onCreate,
        onUpgrade: (db, oldVersion, newVersion) async {
          await DatabaseMigrationRunner().runMigrations(
            db,
            currentVersion: oldVersion,
            targetVersion: newVersion,
          );
        },
      ),
    );
  }

  /// Alias for [init] for testing and lifecycle consistency.
  Future<void> initialize({
    sq.Database? customDatabase,
    sq.DatabaseFactory? databaseFactory,
    String dbName = 'safemate_local.db',
  }) =>
      init(
        customDatabase: customDatabase,
        databaseFactory: databaseFactory,
        dbName: dbName,
      );

  Future<void> _onCreate(sq.Database db, int version) async {
    await DatabaseMigrationRunner().runMigrations(
      db,
      currentVersion: 0,
      targetVersion: version,
    );
  }

  // ---------------------------------------------------------------------------
  // TRIP OPERATIONS
  // ---------------------------------------------------------------------------

  Future<void> saveTrip(
    Trip trip, {
    int? baseServerVersion,
    int? localRevision,
  }) async {
    final json = trip.toJson();
    LocalDataPolicy.assertSafeForLocalPersistence(json, entityName: 'Trip');

    await database.insert(
      'local_trips',
      {
        'id': trip.id,
        'user_id': trip.userId,
        'destination': trip.destination,
        'origin': trip.origin,
        'start_date': trip.startDate.toIso8601String(),
        'end_date': trip.endDate.toIso8601String(),
        'purpose': trip.tripPurpose.name,
        'budget': trip.budgetTier.name,
        'status': trip.status.name,
        'server_version': trip.version,
        'base_server_version': baseServerVersion ?? trip.version,
        'local_revision': localRevision ?? 0,
        'raw_json': jsonEncode(json),
        'updated_at': trip.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: sq.ConflictAlgorithm.replace,
    );
  }

  Future<Trip?> getTrip(String id) async {
    final rows = await database.query(
      'local_trips',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final json = jsonDecode(rows.first['raw_json'] as String) as Map<String, dynamic>;
    return Trip.fromJson(json);
  }

  Future<List<Trip>> getUserTrips(String userId) async {
    final rows = await database.query(
      'local_trips',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'start_date ASC',
    );
    return rows.map((r) {
      final json = jsonDecode(r['raw_json'] as String) as Map<String, dynamic>;
      return Trip.fromJson(json);
    }).toList();
  }

  Future<void> deleteTrip(String id) async {
    await database.delete('local_trips', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // PROFILE OPERATIONS
  // ---------------------------------------------------------------------------

  Future<void> saveProfile(
    UserProfile profile, {
    int? baseServerVersion,
    int? localRevision,
  }) async {
    final json = profile.toJson();
    LocalDataPolicy.assertSafeForLocalPersistence(json, entityName: 'UserProfile');

    await database.insert(
      'local_profiles',
      {
        'id': profile.id,
        'user_id': profile.id,
        'display_name': profile.displayName,
        'server_version': profile.version,
        'base_server_version': baseServerVersion ?? profile.version,
        'local_revision': localRevision ?? 0,
        'raw_json': jsonEncode(json),
        'updated_at': profile.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: sq.ConflictAlgorithm.replace,
    );
  }

  Future<UserProfile?> getProfile(String userId) async {
    final rows = await database.query(
      'local_profiles',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final json = jsonDecode(rows.first['raw_json'] as String) as Map<String, dynamic>;
    return UserProfile.fromJson(json);
  }

  Future<void> deleteProfile(String userId) async {
    await database.delete('local_profiles', where: 'user_id = ?', whereArgs: [userId]);
  }

  // ---------------------------------------------------------------------------
  // ITINERARY OPERATIONS (Phase 12.4.1 Itinerary Versioning Foundation)
  // ---------------------------------------------------------------------------

  Future<void> saveItinerary(
    LocalItineraryRecord itinerary, {
    int? baseServerVersion,
    int? localRevision,
  }) async {
    await database.insert(
      DatabaseSchema.tableItineraries,
      {
        'id': itinerary.id,
        'trip_id': itinerary.tripId,
        'user_id': itinerary.userId,
        'title': itinerary.title,
        'days_json': itinerary.daysJson,
        'server_version': itinerary.serverVersion,
        'base_server_version': baseServerVersion ?? itinerary.baseServerVersion,
        'local_revision': localRevision ?? itinerary.localRevision,
        'updated_at': itinerary.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: sq.ConflictAlgorithm.replace,
    );
  }

  Future<LocalItineraryRecord?> getItinerary(String tripId) async {
    final rows = await database.query(
      DatabaseSchema.tableItineraries,
      where: 'trip_id = ?',
      whereArgs: [tripId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LocalItineraryRecord.fromMap(rows.first);
  }

  Future<List<LocalItineraryRecord>> getUserItineraries(String userId) async {
    final rows = await database.query(
      DatabaseSchema.tableItineraries,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at DESC',
    );
    return rows.map((r) => LocalItineraryRecord.fromMap(r)).toList();
  }

  Future<void> deleteItinerary(String id) async {
    await database.delete(
      DatabaseSchema.tableItineraries,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // CHAT OPERATIONS
  // ---------------------------------------------------------------------------

  Future<void> saveChatMessage(ChatMessage message, {String status = 'sent'}) async {
    await database.insert(
      'local_chat_messages',
      {
        'id': message.id,
        'room_id': message.roomId,
        'sender_id': message.senderId,
        'client_message_id': message.clientMessageId,
        'content': message.content,
        'status': status,
        'created_at': message.createdAt.toIso8601String(),
      },
      conflictAlgorithm: sq.ConflictAlgorithm.replace,
    );
  }

  Future<List<ChatMessage>> getRoomMessages(String roomId, {int limit = 50}) async {
    final rows = await database.query(
      'local_chat_messages',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map((r) {
      return ChatMessage(
        id: r['id'] as String,
        roomId: r['room_id'] as String,
        senderId: r['sender_id'] as String,
        content: r['content'] as String,
        createdAt: DateTime.parse(r['created_at'] as String),
        clientMessageId: r['client_message_id'] as String,
        deliveryStatus: MessageDeliveryStatus.fromString(r['status'] as String),
      );
    }).toList();
  }

  Future<void> deleteChatMessage(String id) async {
    await database.delete('local_chat_messages', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // SAFETRIP OPERATIONS
  // ---------------------------------------------------------------------------

  Future<void> saveSafeTrip(SafeTrip safeTrip) async {
    final json = safeTrip.toJson();
    LocalDataPolicy.assertSafeForLocalPersistence(json, entityName: 'SafeTrip');

    await database.insert(
      'local_safetrips',
      {
        'id': safeTrip.id,
        'trip_id': safeTrip.tripId,
        'owner_id': safeTrip.ownerId,
        'companion_id': safeTrip.companionUserId,
        'status': safeTrip.status.name,
        'raw_json': jsonEncode(json),
        'updated_at': safeTrip.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: sq.ConflictAlgorithm.replace,
    );
  }

  Future<SafeTrip?> getSafeTrip(String journeyId) async {
    final rows = await database.query(
      'local_safetrips',
      where: 'id = ?',
      whereArgs: [journeyId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final json = jsonDecode(rows.first['raw_json'] as String) as Map<String, dynamic>;
    return SafeTrip.fromJson(json);
  }

  Future<SafeTrip?> getSafeTripByTripId(String tripId) async {
    final rows = await database.query(
      'local_safetrips',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final json = jsonDecode(rows.first['raw_json'] as String) as Map<String, dynamic>;
    return SafeTrip.fromJson(json);
  }

  Future<void> saveCheckin(JourneyCheckin checkin, {String syncStatus = 'synced'}) async {
    final json = checkin.toJson();
    LocalDataPolicy.assertSafeForLocalPersistence(json, entityName: 'JourneyCheckin');

    await database.insert(
      'local_checkins',
      {
        'id': checkin.id,
        'journey_id': checkin.journeyId,
        'user_id': checkin.userId,
        'status': checkin.status.name,
        'checkin_time': (checkin.completedAt ?? checkin.scheduledFor).toIso8601String(),
        'sync_status': syncStatus,
        'raw_json': jsonEncode(json),
      },
      conflictAlgorithm: sq.ConflictAlgorithm.replace,
    );
  }

  Future<List<JourneyCheckin>> getJourneyCheckins(String journeyId) async {
    final rows = await database.query(
      'local_checkins',
      where: 'journey_id = ?',
      whereArgs: [journeyId],
      orderBy: 'checkin_time ASC',
    );
    return rows.map((r) {
      final json = jsonDecode(r['raw_json'] as String) as Map<String, dynamic>;
      return JourneyCheckin.fromJson(json);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // SYNC QUEUE OPERATIONS
  // ---------------------------------------------------------------------------

  Future<void> enqueueSyncRecord(SyncRecord record) async {
    LocalDataPolicy.assertSafeForLocalPersistence(record.payload, entityName: 'SyncRecord');
    await database.insert(
      'sync_queue',
      record.toMap(),
      conflictAlgorithm: sq.ConflictAlgorithm.replace,
    );
  }

  Future<List<SyncRecord>> getPendingSyncRecords(String userId) async {
    final rows = await database.query(
      'sync_queue',
      where: 'user_id = ? AND status IN (?, ?)',
      whereArgs: [userId, 'pending', 'failed'],
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => SyncRecord.fromMap(r)).toList();
  }

  Future<List<SyncRecord>> getAllSyncRecords(String userId) async {
    final rows = await database.query(
      'sync_queue',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => SyncRecord.fromMap(r)).toList();
  }

  Future<List<SyncRecord>> getConflictSyncRecords(String userId) async {
    final rows = await database.query(
      'sync_queue',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'conflict'],
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => SyncRecord.fromMap(r)).toList();
  }

  Future<SyncRecord?> getSyncRecord(String operationId) async {
    final rows = await database.query(
      'sync_queue',
      where: 'operation_id = ?',
      whereArgs: [operationId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SyncRecord.fromMap(rows.first);
  }

  Future<void> updateSyncRecordStatus(
    String operationId,
    String status, {
    int? retryCount,
    DateTime? lastAttemptAt,
    String? errorMessage,
  }) async {
    final values = <String, dynamic>{
      'status': status,
      if (retryCount != null) 'retry_count': retryCount, // ignore: use_null_aware_elements
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt.toIso8601String(), // ignore: use_null_aware_elements
      if (errorMessage != null) 'error_message': errorMessage, // ignore: use_null_aware_elements
    };

    await database.update(
      'sync_queue',
      values,
      where: 'operation_id = ?',
      whereArgs: [operationId],
    );
  }

  Future<void> deleteSyncRecord(String operationId) async {
    await database.delete(
      'sync_queue',
      where: 'operation_id = ?',
      whereArgs: [operationId],
    );
  }

  // ---------------------------------------------------------------------------
  // MULTI-USER ISOLATION & PURGE ON LOGOUT
  // ---------------------------------------------------------------------------

  /// Purges all local user-scoped records when a user logs out or switches accounts.
  /// Universal Engineering Rule #10: Zero cross-account data leakage on shared devices.
  Future<void> purgeUserData(String userId) async {
    final batch = database.batch();
    batch.delete('local_trips', where: 'user_id = ?', whereArgs: [userId]);
    batch.delete('local_trip_preferences', where: 'user_id = ?', whereArgs: [userId]);
    batch.delete('local_itineraries', where: 'user_id = ?', whereArgs: [userId]);
    batch.delete('local_profiles', where: 'user_id = ?', whereArgs: [userId]);
    batch.delete('local_safetrips', where: 'owner_id = ?', whereArgs: [userId]);
    batch.delete('local_checkins', where: 'user_id = ?', whereArgs: [userId]);
    batch.delete('local_chat_messages', where: 'sender_id = ?', whereArgs: [userId]);
    batch.delete('local_sync_queue', where: 'user_id = ?', whereArgs: [userId]);
    batch.delete('sync_queue', where: 'user_id = ?', whereArgs: [userId]);
    batch.delete('local_user_scope', where: 'user_id = ?', whereArgs: [userId]);
    await batch.commit(noResult: true);
    debugPrint('[SafeMate LocalDatabase] Successfully purged local SQLite cache for user: $userId');
  }

  /// Alias matching Phase 12.1 specification.
  Future<void> clearUserScopedData(String userId) => purgeUserData(userId);

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
