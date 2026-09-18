/// SafeMate Local SQLite DTO Models.
/// Universal Engineering Rule #6: Strict field validation — only approved fields persisted.
/// Universal Engineering Rule #10: User isolation via mandatory user_id.
library;

import 'dart:convert';
import '../../features/auth/domain/models/user_profile.dart';
import '../../features/trips/domain/models/trip.dart';
import '../../features/trips/domain/models/trip_preferences.dart';
import 'local_data_policy.dart';

/// Local record representing the active user session on the device.
class LocalUserScopeRecord {
  final String id;
  final String userId;
  final bool isActive;
  final DateTime lastSwitchedAt;

  const LocalUserScopeRecord({
    required this.id,
    required this.userId,
    this.isActive = true,
    required this.lastSwitchedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'is_active': isActive ? 1 : 0,
        'last_switched_at': lastSwitchedAt.toIso8601String(),
      };

  factory LocalUserScopeRecord.fromMap(Map<String, dynamic> map) =>
      LocalUserScopeRecord(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        isActive: (map['is_active'] as int) == 1,
        lastSwitchedAt: DateTime.parse(map['last_switched_at'] as String),
      );
}

/// Controlled local representation of a user profile.
class LocalProfileRecord {
  final String id;
  final String userId;
  final String displayName;
  final String? bio;
  final String verificationLevel;
  final int serverVersion;
  final int baseServerVersion;
  final int localRevision;
  final String rawJson;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;

  const LocalProfileRecord({
    required this.id,
    required this.userId,
    required this.displayName,
    this.bio,
    this.verificationLevel = 'unverified',
    this.serverVersion = 1,
    this.baseServerVersion = 1,
    this.localRevision = 0,
    required this.rawJson,
    required this.updatedAt,
    this.lastSyncedAt,
  });

  /// Maps domain UserProfile into privacy-safe local DTO.
  factory LocalProfileRecord.fromDomain(UserProfile profile, {int? baseServerVersion, int? localRevision}) {
    final verificationLevel = profile.isVerified ? 'verified' : 'unverified';
    final sanitizedJson = {
      'id': profile.id,
      'display_name': profile.displayName,
      'bio': profile.bio,
      'avatar_url': profile.avatarUrl,
      'languages': profile.languages,
      'travel_styles': profile.travelStyles,
      'is_verified': profile.isVerified,
      'verification_level': verificationLevel,
      'version': profile.version,
      'updated_at': profile.updatedAt.toIso8601String(),
    };
    LocalDataPolicy.assertSafeForLocalPersistence(sanitizedJson, entityName: 'UserProfile');

    return LocalProfileRecord(
      id: profile.id,
      userId: profile.id,
      displayName: profile.displayName,
      bio: profile.bio,
      verificationLevel: verificationLevel,
      serverVersion: profile.version,
      baseServerVersion: baseServerVersion ?? profile.version,
      localRevision: localRevision ?? 0,
      rawJson: jsonEncode(sanitizedJson),
      updatedAt: profile.updatedAt,
      lastSyncedAt: DateTime.now(),
    );
  }

  UserProfile toDomain() {
    final json = jsonDecode(rawJson) as Map<String, dynamic>;
    return UserProfile.fromJson(json);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'display_name': displayName,
        'bio': bio,
        'verification_level': verificationLevel,
        'server_version': serverVersion,
        'base_server_version': baseServerVersion,
        'local_revision': localRevision,
        'raw_json': rawJson,
        'updated_at': updatedAt.toIso8601String(),
        'last_synced_at': lastSyncedAt?.toIso8601String(),
      };

  factory LocalProfileRecord.fromMap(Map<String, dynamic> map) =>
      LocalProfileRecord(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        displayName: map['display_name'] as String,
        bio: map['bio'] as String?,
        verificationLevel: map['verification_level'] as String? ?? 'unverified',
        serverVersion: (map['server_version'] as int?) ?? 1,
        baseServerVersion: (map['base_server_version'] as int?) ?? 1,
        localRevision: (map['local_revision'] as int?) ?? 0,
        rawJson: map['raw_json'] as String,
        updatedAt: DateTime.parse(map['updated_at'] as String),
        lastSyncedAt: map['last_synced_at'] != null
            ? DateTime.parse(map['last_synced_at'] as String)
            : null,
      );
}

/// Controlled local representation of a Trip.
class LocalTripRecord {
  final String id;
  final String userId;
  final String destination;
  final String origin;
  final DateTime startDate;
  final DateTime endDate;
  final String purpose;
  final String budget;
  final String status;
  final int serverVersion;
  final int baseServerVersion;
  final int localRevision;
  final String rawJson;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;

  const LocalTripRecord({
    required this.id,
    required this.userId,
    required this.destination,
    required this.origin,
    required this.startDate,
    required this.endDate,
    required this.purpose,
    required this.budget,
    required this.status,
    this.serverVersion = 1,
    this.baseServerVersion = 1,
    this.localRevision = 0,
    required this.rawJson,
    required this.updatedAt,
    this.lastSyncedAt,
  });

  /// Maps domain Trip into privacy-safe local DTO.
  factory LocalTripRecord.fromDomain(Trip trip, {int? baseServerVersion, int? localRevision}) {
    final sanitizedJson = trip.toJson();
    LocalDataPolicy.assertSafeForLocalPersistence(sanitizedJson, entityName: 'Trip');

    return LocalTripRecord(
      id: trip.id,
      userId: trip.userId,
      destination: trip.destination,
      origin: trip.origin,
      startDate: trip.startDate,
      endDate: trip.endDate,
      purpose: trip.tripPurpose.name,
      budget: trip.budgetTier.name,
      status: trip.status.name,
      serverVersion: trip.version,
      baseServerVersion: baseServerVersion ?? trip.version,
      localRevision: localRevision ?? 0,
      rawJson: jsonEncode(sanitizedJson),
      updatedAt: trip.updatedAt,
      lastSyncedAt: DateTime.now(),
    );
  }

  Trip toDomain() {
    final json = jsonDecode(rawJson) as Map<String, dynamic>;
    return Trip.fromJson(json);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'destination': destination,
        'origin': origin,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'purpose': purpose,
        'budget': budget,
        'status': status,
        'server_version': serverVersion,
        'base_server_version': baseServerVersion,
        'local_revision': localRevision,
        'raw_json': rawJson,
        'updated_at': updatedAt.toIso8601String(),
        'last_synced_at': lastSyncedAt?.toIso8601String(),
      };

  factory LocalTripRecord.fromMap(Map<String, dynamic> map) => LocalTripRecord(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        destination: map['destination'] as String,
        origin: map['origin'] as String,
        startDate: DateTime.parse(map['start_date'] as String),
        endDate: DateTime.parse(map['end_date'] as String),
        purpose: map['purpose'] as String,
        budget: map['budget'] as String,
        status: map['status'] as String,
        serverVersion: (map['server_version'] as int?) ?? 1,
        baseServerVersion: (map['base_server_version'] as int?) ?? 1,
        localRevision: (map['local_revision'] as int?) ?? 0,
        rawJson: map['raw_json'] as String,
        updatedAt: DateTime.parse(map['updated_at'] as String),
        lastSyncedAt: map['last_synced_at'] != null
            ? DateTime.parse(map['last_synced_at'] as String)
            : null,
      );
}

/// Controlled local representation of Trip Preferences.
class LocalTripPreferencesRecord {
  final String id;
  final String tripId;
  final String userId;
  final String? preferredGender;
  final String? travelPace;
  final String? budgetTier;
  final int serverVersion;
  final int baseServerVersion;
  final int localRevision;
  final String rawJson;
  final DateTime updatedAt;

  const LocalTripPreferencesRecord({
    required this.id,
    required this.tripId,
    required this.userId,
    this.preferredGender,
    this.travelPace,
    this.budgetTier,
    this.serverVersion = 1,
    this.baseServerVersion = 1,
    this.localRevision = 0,
    required this.rawJson,
    required this.updatedAt,
  });

  factory LocalTripPreferencesRecord.fromDomain({
    required String tripId,
    required String userId,
    required TripPreferences preferences,
    int? baseServerVersion,
    int? localRevision,
  }) {
    final json = preferences.toJson();
    LocalDataPolicy.assertSafeForLocalPersistence(json, entityName: 'TripPreferences');

    return LocalTripPreferencesRecord(
      id: '${tripId}_pref',
      tripId: tripId,
      userId: userId,
      preferredGender: preferences.preferredGender,
      travelPace: preferences.travelPace.name,
      budgetTier: preferences.budgetTier.name,
      serverVersion: 1,
      baseServerVersion: baseServerVersion ?? 1,
      localRevision: localRevision ?? 0,
      rawJson: jsonEncode(json),
      updatedAt: DateTime.now(),
    );
  }

  TripPreferences toDomain() {
    final json = jsonDecode(rawJson) as Map<String, dynamic>;
    return TripPreferences.fromJson(json);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'trip_id': tripId,
        'user_id': userId,
        'preferred_gender': preferredGender,
        'travel_pace': travelPace,
        'budget_tier': budgetTier,
        'server_version': serverVersion,
        'base_server_version': baseServerVersion,
        'local_revision': localRevision,
        'raw_json': rawJson,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory LocalTripPreferencesRecord.fromMap(Map<String, dynamic> map) =>
      LocalTripPreferencesRecord(
        id: map['id'] as String,
        tripId: map['trip_id'] as String,
        userId: map['user_id'] as String,
        preferredGender: map['preferred_gender'] as String?,
        travelPace: map['travel_pace'] as String?,
        budgetTier: map['budget_tier'] as String?,
        serverVersion: (map['server_version'] as int?) ?? 1,
        baseServerVersion: (map['base_server_version'] as int?) ?? 1,
        localRevision: (map['local_revision'] as int?) ?? 0,
        rawJson: map['raw_json'] as String,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

/// Controlled local representation of Itinerary Plans.
class LocalItineraryRecord {
  final String id;
  final String tripId;
  final String userId;
  final String title;
  final String daysJson;
  final int serverVersion;
  final int baseServerVersion;
  final int localRevision;
  final DateTime updatedAt;

  const LocalItineraryRecord({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.title,
    required this.daysJson,
    this.serverVersion = 1,
    this.baseServerVersion = 1,
    this.localRevision = 0,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'trip_id': tripId,
        'user_id': userId,
        'title': title,
        'days_json': daysJson,
        'server_version': serverVersion,
        'base_server_version': baseServerVersion,
        'local_revision': localRevision,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory LocalItineraryRecord.fromMap(Map<String, dynamic> map) =>
      LocalItineraryRecord(
        id: map['id'] as String,
        tripId: map['trip_id'] as String,
        userId: map['user_id'] as String,
        title: map['title'] as String,
        daysJson: map['days_json'] as String,
        serverVersion: (map['server_version'] as int?) ?? 1,
        baseServerVersion: (map['base_server_version'] as int?) ?? 1,
        localRevision: (map['local_revision'] as int?) ?? 0,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

/// Controlled local representation of Sync Queue Operation.
class LocalSyncQueueRecord {
  final String id;
  final String userId;
  final String operationId;
  final String entityType;
  final String entityId;
  final String operationType;
  final String payload;
  final DateTime createdAt;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final String status;
  final String? lastError;
  final int? baseServerVersion;
  final int localRevision;

  const LocalSyncQueueRecord({
    required this.id,
    required this.userId,
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.payload,
    required this.createdAt,
    this.attemptCount = 0,
    this.nextAttemptAt,
    required this.status,
    this.lastError,
    this.baseServerVersion,
    this.localRevision = 1,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'operation_id': operationId,
        'entity_type': entityType,
        'entity_id': entityId,
        'operation_type': operationType,
        'action': operationType,
        'payload': payload,
        'payload_json': payload,
        'created_at': createdAt.toIso8601String(),
        'attempt_count': attemptCount,
        'retry_count': attemptCount,
        'next_attempt_at': nextAttemptAt?.toIso8601String(),
        'status': status,
        'last_error': lastError,
        'error_message': lastError,
        'base_server_version': baseServerVersion,
        'local_revision': localRevision,
      };

  factory LocalSyncQueueRecord.fromMap(Map<String, dynamic> map) =>
      LocalSyncQueueRecord(
        id: (map['id'] ?? map['operation_id']) as String,
        userId: map['user_id'] as String,
        operationId: (map['operation_id'] ?? map['id']) as String,
        entityType: map['entity_type'] as String,
        entityId: map['entity_id'] as String,
        operationType: (map['operation_type'] ?? map['action']) as String,
        payload: (map['payload'] ?? map['payload_json']) as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        attemptCount: (map['attempt_count'] ?? map['retry_count'] as int?) ?? 0,
        nextAttemptAt: map['next_attempt_at'] != null
            ? DateTime.parse(map['next_attempt_at'] as String)
            : null,
        status: map['status'] as String,
        lastError: (map['last_error'] ?? map['error_message']) as String?,
        baseServerVersion: map['base_server_version'] as int?,
        localRevision: (map['local_revision'] as int?) ?? 1,
      );
}
