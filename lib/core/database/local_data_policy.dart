/// SafeMate Local Data Classification & Policy Enforcement.
/// Universal Engineering Rule #6: Never store secrets in plain text.
/// Universal Engineering Rule #10: Privacy and consent are first-class design constraints.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'database_exceptions.dart';

/// Explicit classification tiers for all SafeMate data.
enum DataClassificationCategory {
  /// Category A: Safe local cache. Non-sensitive operational data.
  categoryA,

  /// Category B: Controlled local cache. Authorized relationship / journey data.
  categoryB,

  /// Category C: Strictly prohibited from local disk cache. Must NEVER enter SQLite.
  categoryC;

  bool get isSafeLocalCache => this == categoryA;
  bool get isControlledCache => this == categoryB;
  bool get isNeverCache => this == categoryC;
}

/// Explicit retention policies for local records.
enum LocalRetentionPolicy {
  /// Retained until the user signs out or switches accounts.
  persistUntilLogout,

  /// Retained until successfully synchronized with the authoritative server.
  persistUntilSynced,

  /// Retained for a bounded duration (TTL).
  persistForDuration,

  /// Retained until the associated journey/trip is marked completed.
  persistUntilTripComplete,

  /// Must never be persisted to disk.
  neverPersist;
}

/// Single Source of Truth for table-level and field-level local storage policies.
class TablePolicy {
  final String tableName;
  final DataClassificationCategory category;
  final bool isUserScoped;
  final String? userIdColumn;
  final LocalRetentionPolicy retentionPolicy;
  final Set<String> allowedFields;

  const TablePolicy({
    required this.tableName,
    required this.category,
    this.isUserScoped = true,
    this.userIdColumn = 'user_id',
    required this.retentionPolicy,
    required this.allowedFields,
  });
}

/// Central Data Policy rules and runtime verification guards.
class LocalDataPolicy {
  const LocalDataPolicy._();

  // Category Constants
  static const String categoryASafe = 'CATEGORY_A_SAFE';
  static const String categoryBControlled = 'CATEGORY_B_CONTROLLED';
  static const String categoryCNeverCache = 'CATEGORY_C_NEVER_CACHE';

  /// Maximum allowed payload size for a single record or sync payload (64 KB).
  static const int maxPayloadSizeBytes = 65536;

  /// Authoritative Single Source of Truth Table Policy Registry.
  static const Map<String, TablePolicy> tablePolicyRegistry = {
    'local_user_scope': TablePolicy(
      tableName: 'local_user_scope',
      category: DataClassificationCategory.categoryA,
      isUserScoped: true,
      userIdColumn: 'user_id',
      retentionPolicy: LocalRetentionPolicy.persistUntilLogout,
      allowedFields: {'id', 'user_id', 'is_active', 'last_switched_at'},
    ),
    'local_trips': TablePolicy(
      tableName: 'local_trips',
      category: DataClassificationCategory.categoryA,
      isUserScoped: true,
      userIdColumn: 'user_id',
      retentionPolicy: LocalRetentionPolicy.persistUntilLogout,
      allowedFields: {
        'id',
        'user_id',
        'destination',
        'origin',
        'start_date',
        'end_date',
        'purpose',
        'budget',
        'status',
        'server_version',
        'base_server_version',
        'local_revision',
        'raw_json',
        'updated_at',
        'last_synced_at',
      },
    ),
    'local_trip_preferences': TablePolicy(
      tableName: 'local_trip_preferences',
      category: DataClassificationCategory.categoryA,
      isUserScoped: true,
      userIdColumn: 'user_id',
      retentionPolicy: LocalRetentionPolicy.persistUntilLogout,
      allowedFields: {
        'id',
        'trip_id',
        'user_id',
        'preferred_gender',
        'travel_pace',
        'budget_tier',
        'server_version',
        'base_server_version',
        'local_revision',
        'raw_json',
        'updated_at',
      },
    ),
    'local_itineraries': TablePolicy(
      tableName: 'local_itineraries',
      category: DataClassificationCategory.categoryA,
      isUserScoped: true,
      userIdColumn: 'user_id',
      retentionPolicy: LocalRetentionPolicy.persistUntilLogout,
      allowedFields: {
        'id',
        'trip_id',
        'user_id',
        'title',
        'days_json',
        'server_version',
        'base_server_version',
        'local_revision',
        'updated_at',
      },
    ),
    'local_profiles': TablePolicy(
      tableName: 'local_profiles',
      category: DataClassificationCategory.categoryB,
      isUserScoped: true,
      userIdColumn: 'user_id',
      retentionPolicy: LocalRetentionPolicy.persistUntilLogout,
      allowedFields: {
        'id',
        'user_id',
        'display_name',
        'bio',
        'verification_level',
        'server_version',
        'base_server_version',
        'local_revision',
        'raw_json',
        'updated_at',
        'last_synced_at',
      },
    ),
    'local_sync_queue': TablePolicy(
      tableName: 'local_sync_queue',
      category: DataClassificationCategory.categoryB,
      isUserScoped: true,
      userIdColumn: 'user_id',
      retentionPolicy: LocalRetentionPolicy.persistUntilSynced,
      allowedFields: {
        'id',
        'user_id',
        'operation_id',
        'entity_type',
        'entity_id',
        'operation_type',
        'payload',
        'created_at',
        'attempt_count',
        'next_attempt_at',
        'status',
        'last_error',
        'base_server_version',
        'local_revision',
      },
    ),
    'sync_queue': TablePolicy(
      tableName: 'sync_queue',
      category: DataClassificationCategory.categoryB,
      isUserScoped: true,
      userIdColumn: 'user_id',
      retentionPolicy: LocalRetentionPolicy.persistUntilSynced,
      allowedFields: {
        'operation_id',
        'user_id',
        'entity_type',
        'entity_id',
        'action',
        'payload_json',
        'status',
        'retry_count',
        'last_attempt_at',
        'error_message',
        'created_at',
        'base_server_version',
        'local_revision',
        'id',
        'operation_type',
        'payload',
        'attempt_count',
        'next_attempt_at',
        'last_error',
      },
    ),
    'local_chat_messages': TablePolicy(
      tableName: 'local_chat_messages',
      category: DataClassificationCategory.categoryB,
      isUserScoped: true,
      userIdColumn: 'sender_id',
      retentionPolicy: LocalRetentionPolicy.persistUntilLogout,
      allowedFields: {
        'id',
        'room_id',
        'sender_id',
        'client_message_id',
        'content',
        'status',
        'created_at',
      },
    ),
    'local_safetrips': TablePolicy(
      tableName: 'local_safetrips',
      category: DataClassificationCategory.categoryB,
      isUserScoped: true,
      userIdColumn: 'owner_id',
      retentionPolicy: LocalRetentionPolicy.persistUntilTripComplete,
      allowedFields: {
        'id',
        'trip_id',
        'owner_id',
        'companion_id',
        'status',
        'raw_json',
        'updated_at',
      },
    ),
    'local_checkins': TablePolicy(
      tableName: 'local_checkins',
      category: DataClassificationCategory.categoryB,
      isUserScoped: true,
      userIdColumn: 'user_id',
      retentionPolicy: LocalRetentionPolicy.persistUntilSynced,
      allowedFields: {
        'id',
        'journey_id',
        'user_id',
        'status',
        'checkin_time',
        'sync_status',
        'raw_json',
      },
    ),
  };

  /// Explicit set of Category C fields that MUST NEVER be stored in SQLite.
  static const Set<String> prohibitedFields = {
    'aadhaar',
    'government_id',
    'id_number',
    'passport',
    'passport_number',
    'auth_token',
    'access_token',
    'refresh_token',
    'password',
    'pin',
    'secret_code',
    'payment_credentials',
    'card_number',
    'cvv',
    'raw_gps_trail',
    'continuous_gps',
    'exact_location_history',
    'exact_gps',
    'moderation_notes',
    'private_moderation',
    'admin_records',
    'fraud_risk_score',
    'internal_flags',
    'document_image_bytes',
    'raw_document_bytes',
  };

  /// Server-authoritative profile fields that clients must NEVER mutate or submit in updates.
  /// Enforces Phase 12.4 Audit Correction #3 (Trust Score & Authoritative Profile Security).
  static const Set<String> serverAuthoritativeProfileFields = {
    'trust_score',
    'trips_completed',
    'reliability_rating',
    'verification_status',
    'verification_level',
    'moderation_state',
    'suspension_state',
    'account_state',
    'is_admin',
  };

  /// Asserts that a client payload does not attempt to mutate server-authoritative fields.
  static void assertNoAuthoritativeProfileFieldMutation(Map<String, dynamic> payload) {
    for (final field in serverAuthoritativeProfileFields) {
      if (payload.containsKey(field)) {
        logPolicyViolation(
          violationType: 'AUTHORITATIVE_FIELD_TAMPERING',
          tableName: 'local_profiles',
          operation: 'update',
        );
        throw DatabasePolicyViolationException(
          'Security Violation: Client attempted to mutate server-authoritative profile field "$field".',
          null,
          'local_profiles',
          field,
        );
      }
    }
  }

  /// Permitted entity types for sync queue operations.
  static const Set<String> allowedSyncEntityTypes = {
    'trip',
    'profile',
    'trip_preferences',
    'itinerary',
    'chat',
    'safetrip_checkin',
  };

  /// Permitted actions for sync queue operations.
  static const Set<String> allowedSyncOperationTypes = {
    'create',
    'update',
    'delete',
    'save_draft',
    'delete_draft',
    'transition_status',
    'send_message',
    'record_checkin',
  };

  /// Validates a database write operation against the authoritative table policy.
  static void validateTableWrite(String tableName, Map<String, dynamic> data) {
    final policy = tablePolicyRegistry[tableName];
    if (policy == null) {
      logPolicyViolation(
        violationType: 'UNREGISTERED_TABLE',
        tableName: tableName,
        operation: 'write',
      );
      throw DatabasePolicyViolationException(
        'Table "$tableName" has no registered LocalDataPolicy.',
        null,
        tableName,
      );
    }

    // 1. Check size limit
    final encoded = jsonEncode(data);
    if (encoded.length > maxPayloadSizeBytes) {
      logPolicyViolation(
        violationType: 'PAYLOAD_OVERSIZED',
        tableName: tableName,
        operation: 'write',
      );
      throw DatabasePolicyViolationException(
        'Payload size for table "$tableName" exceeds the $maxPayloadSizeBytes bytes limit.',
        null,
        tableName,
      );
    }

    // 2. Field-level allowlist check
    for (final key in data.keys) {
      if (!policy.allowedFields.contains(key)) {
        logPolicyViolation(
          violationType: 'UNAPPROVED_FIELD',
          tableName: tableName,
          operation: 'write',
        );
        throw DatabasePolicyViolationException(
          'Field "$key" is not permitted in table "$tableName".',
          null,
          tableName,
          key,
        );
      }
    }

    // 3. Category C hard block check (recursive inspection)
    assertSafeForLocalPersistence(data, entityName: tableName);
  }

  /// Validates a sync queue payload before it is written to SQLite.
  static void validateSyncPayload(
    String entityType,
    String operationType,
    Map<String, dynamic> payload,
  ) {
    if (!allowedSyncEntityTypes.contains(entityType)) {
      logPolicyViolation(
        violationType: 'UNAPPROVED_SYNC_ENTITY',
        tableName: 'local_sync_queue',
        operation: 'enqueue',
      );
      throw DatabasePolicyViolationException(
        'Entity type "$entityType" is not approved for synchronization queueing.',
        null,
        'local_sync_queue',
      );
    }

    if (!allowedSyncOperationTypes.contains(operationType)) {
      logPolicyViolation(
        violationType: 'UNAPPROVED_SYNC_OPERATION',
        tableName: 'local_sync_queue',
        operation: 'enqueue',
      );
      throw DatabasePolicyViolationException(
        'Operation "$operationType" is not approved for synchronization queueing.',
        null,
        'local_sync_queue',
      );
    }

    final payloadStr = jsonEncode(payload);
    if (payloadStr.length > maxPayloadSizeBytes) {
      logPolicyViolation(
        violationType: 'SYNC_PAYLOAD_OVERSIZED',
        tableName: 'local_sync_queue',
        operation: 'enqueue',
      );
      throw DatabasePolicyViolationException(
        'Sync payload size exceeds maximum limit ($maxPayloadSizeBytes bytes).',
        null,
        'local_sync_queue',
      );
    }

    // Check for Category C fields
    assertSafeForLocalPersistence(payload, entityName: 'SyncPayload:$entityType');
  }

  /// Validates a record map before it is written to the local SQLite database.
  /// Throws [DatabasePolicyViolationException] if any prohibited Category C field is detected.
  static void assertSafeForLocalPersistence(Map<String, dynamic> data, {String? entityName}) {
    _assertNoProhibitedKeys(data, entityName: entityName);
  }

  static void _assertNoProhibitedKeys(dynamic value, {String? entityName}) {
    if (value is Map) {
      for (final entry in value.entries) {
        final keyStr = entry.key.toString().toLowerCase();
        if (prohibitedFields.contains(keyStr)) {
          logPolicyViolation(
            violationType: 'CATEGORY_C_PROHIBITED',
            tableName: entityName ?? 'unknown',
            operation: 'persist',
          );
          throw DatabasePolicyViolationException(
            'LocalDataPolicy Violation: Attempted to write prohibited Category C field "${entry.key}" '
            'into local database${entityName != null ? ' for entity "$entityName"' : ''}.',
            null,
            entityName,
            entry.key.toString(),
          );
        }
        _assertNoProhibitedKeys(entry.value, entityName: entityName);
      }
    } else if (value is List) {
      for (final item in value) {
        _assertNoProhibitedKeys(item, entityName: entityName);
      }
    }
  }

  /// Known Category A Safe entities permitted for local caching.
  static const Set<String> categoryAEntities = {
    'trip_summary',
    'packing_checklist',
    'itinerary',
    'destination_guide',
    'trip',
    'trip_preferences',
    'local_trips',
    'local_trip_preferences',
    'local_itineraries',
    'local_user_scope',
  };

  /// Known Category B Controlled entities with restricted local lifecycle.
  static const Set<String> categoryBEntities = {
    'chat_message',
    'safetrip_state',
    'checkin',
    'profile_cache',
    'profile',
    'user_profile',
    'sync_queue',
    'local_profiles',
    'local_sync_queue',
    'local_chat_messages',
    'local_safetrips',
    'local_checkins',
  };

  /// Categorizes an entity type into its designated safety tier.
  /// Defaults to [DataClassificationCategory.categoryC] for unknown entities (fail closed).
  static DataClassificationCategory classifyEntity(String entityType) {
    if (categoryAEntities.contains(entityType)) {
      return DataClassificationCategory.categoryA;
    }
    if (categoryBEntities.contains(entityType)) {
      return DataClassificationCategory.categoryB;
    }
    for (final policy in tablePolicyRegistry.values) {
      if (policy.tableName == entityType ||
          policy.tableName == 'local_$entityType' ||
          policy.tableName == 'local_${entityType}s') {
        return policy.category;
      }
    }
    return DataClassificationCategory.categoryC;
  }

  /// Returns the policy assigned to a specific table.
  static DataClassificationCategory getTablePolicy(String tableName) {
    return tablePolicyRegistry[tableName]?.category ?? DataClassificationCategory.categoryC;
  }

  /// Logs a policy violation safely without including sensitive values or PII.
  static void logPolicyViolation({
    required String violationType,
    required String tableName,
    required String operation,
  }) {
    debugPrint(
      '[SafeMate DataPolicy Audit] Violation: type=$violationType, '
      'table=$tableName, op=$operation, timestamp=${DateTime.now().toIso8601String()}',
    );
  }
}
