/// SafeMate Conflict Domain Model & Concurrency Types.
/// Universal Engineering Rule #6: Strict schema validation and sanitized domain models.
/// Universal Engineering Rule #7: Client never overrides server authority.
/// Universal Engineering Rule #11: Deterministic conflict states and zero-trust synchronization.
/// Universal Engineering Rule #18: Server is authoritative on conflict.
library;

import '../database/local_data_policy.dart';

/// Explicit categories of synchronization conflicts.
enum ConflictType {
  /// Both local client and remote server modified the entity concurrently.
  concurrentUpdate,

  /// Local mutation was based on an outdated server version.
  staleBase,

  /// Remote entity was deleted while local client updated it.
  deleteVsUpdate,

  /// Local client deleted an entity while remote server updated it.
  updateVsDelete,

  /// User permissions or RLS membership changed, invalidating the mutation.
  permissionChanged,

  /// Server state machine progressed (e.g. cancelled/completed) preventing transition.
  serverStateChanged,

  /// Authentication expired or session was revoked during synchronization.
  authenticationConflict,

  /// Unclassified or legacy conflict type.
  unknown;

  static ConflictType fromString(String value) {
    for (final type in ConflictType.values) {
      if (type.name == value) return type;
    }
    return ConflictType.unknown;
  }
}

/// Lifecycle state of a detected conflict.
enum ConflictResolutionState {
  /// Conflict has been detected and recorded in local queue/conflict store.
  detected,

  /// Awaiting user review or manual resolution decision.
  awaitingResolution,

  /// Resolved by applying the local client version (user confirmed).
  resolvedLocal,

  /// Resolved by accepting the authoritative server version.
  resolvedServer,

  /// Resolved through a successful 3-way non-conflicting field merge.
  merged,

  /// Conflicted mutation was discarded.
  discarded,

  /// Queued for retry following conflict mitigation.
  retryPending;

  static ConflictResolutionState fromString(String value) {
    for (final state in ConflictResolutionState.values) {
      if (state.name == value) return state;
    }
    return ConflictResolutionState.detected;
  }
}

/// Server-version-aware synchronization metadata for offline entities.
/// Distinguishes base_server_version from local_revision.
/// Universal Engineering Rule #18: Server revision/version remains authoritative.
class EntityVersionMetadata {
  /// The server version upon which this local state was branched.
  final int baseServerVersion;

  /// Counter of uncommitted local mutations since last sync (client-only).
  final int localRevision;

  /// The latest confirmed server version known to the client.
  final int lastSyncedServerVersion;

  /// Timestamp when the entity was last successfully synchronized with Supabase.
  final DateTime? lastSyncedAt;

  const EntityVersionMetadata({
    this.baseServerVersion = 1,
    this.localRevision = 0,
    this.lastSyncedServerVersion = 1,
    this.lastSyncedAt,
  });

  /// Factory for a newly created un-synced entity.
  factory EntityVersionMetadata.initial() {
    return const EntityVersionMetadata(
      baseServerVersion: 0,
      localRevision: 1,
      lastSyncedServerVersion: 0,
    );
  }

  /// Factory for an entity freshly retrieved from the server.
  factory EntityVersionMetadata.fromServer(int serverVersion) {
    return EntityVersionMetadata(
      baseServerVersion: serverVersion,
      localRevision: 0,
      lastSyncedServerVersion: serverVersion,
      lastSyncedAt: DateTime.now(),
    );
  }

  EntityVersionMetadata copyWith({
    int? baseServerVersion,
    int? localRevision,
    int? lastSyncedServerVersion,
    DateTime? lastSyncedAt,
  }) {
    return EntityVersionMetadata(
      baseServerVersion: baseServerVersion ?? this.baseServerVersion,
      localRevision: localRevision ?? this.localRevision,
      lastSyncedServerVersion: lastSyncedServerVersion ?? this.lastSyncedServerVersion,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'base_server_version': baseServerVersion,
      'local_revision': localRevision,
      'server_version': lastSyncedServerVersion,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
    };
  }

  factory EntityVersionMetadata.fromMap(Map<String, dynamic> map) {
    return EntityVersionMetadata(
      baseServerVersion: (map['base_server_version'] as num?)?.toInt() ?? 1,
      localRevision: (map['local_revision'] as num?)?.toInt() ?? 0,
      lastSyncedServerVersion: (map['server_version'] as num?)?.toInt() ?? 1,
      lastSyncedAt: map['last_synced_at'] != null
          ? DateTime.tryParse(map['last_synced_at'] as String)
          : null,
    );
  }
}

/// Strongly-typed model representing a synchronization conflict.
/// Contains only sanitized metadata.
/// Universal Rule #6 & Rule #7: Never store Category C data, PII, or credentials in conflicts.
class SyncConflict {
  final String conflictId;
  final String operationId;
  final String userId;
  final String entityType;
  final String entityId;
  final ConflictType conflictType;
  final ConflictResolutionState resolutionState;
  final int? baseServerVersion;
  final int? localRevision;
  final int? serverVersion;
  final String localAction;
  final String? serverAction;
  final DateTime localTimestamp;
  final DateTime? serverTimestamp;
  final List<String> conflictingFields;
  final DateTime detectedAt;
  final DateTime? resolvedAt;
  final String? resolutionNotes;
  final Map<String, dynamic> sanitizedMetadata;

  SyncConflict({
    required this.conflictId,
    required this.operationId,
    required this.userId,
    required this.entityType,
    required this.entityId,
    required this.conflictType,
    this.resolutionState = ConflictResolutionState.detected,
    this.baseServerVersion,
    this.localRevision,
    this.serverVersion,
    required this.localAction,
    this.serverAction,
    required this.localTimestamp,
    this.serverTimestamp,
    this.conflictingFields = const [],
    required this.detectedAt,
    this.resolvedAt,
    this.resolutionNotes,
    Map<String, dynamic>? sanitizedMetadata,
  }) : sanitizedMetadata = _sanitizeMetadata(sanitizedMetadata ?? const {}) {
    // Assert user isolation
    if (userId.isEmpty) {
      throw ArgumentError('SyncConflict must belong to a valid user_id.');
    }
    // Verify no Category C / sensitive data leaked
    LocalDataPolicy.assertSafeForLocalPersistence(this.sanitizedMetadata, entityName: 'SyncConflict');
  }

  /// Filters out any sensitive keys from conflict metadata.
  static Map<String, dynamic> _sanitizeMetadata(Map<String, dynamic> raw) {
    final clean = <String, dynamic>{};
    for (final entry in raw.entries) {
      final k = entry.key.toLowerCase();
      // Block passwords, tokens, aadhaar, raw gps, emergency secrets, message plaintext, notes
      if (k.contains('token') ||
          k.contains('password') ||
          k.contains('secret') ||
          k.contains('aadhaar') ||
          k.contains('passport') ||
          k.contains('plaintext') ||
          k.contains('latitude') ||
          k.contains('longitude') ||
          k.contains('gps')) {
        continue;
      }
      clean[entry.key] = entry.value;
    }
    return clean;
  }

  SyncConflict copyWith({
    ConflictResolutionState? resolutionState,
    DateTime? resolvedAt,
    String? resolutionNotes,
    Map<String, dynamic>? sanitizedMetadata,
  }) {
    return SyncConflict(
      conflictId: conflictId,
      operationId: operationId,
      userId: userId,
      entityType: entityType,
      entityId: entityId,
      conflictType: conflictType,
      resolutionState: resolutionState ?? this.resolutionState,
      baseServerVersion: baseServerVersion,
      localRevision: localRevision,
      serverVersion: serverVersion,
      localAction: localAction,
      serverAction: serverAction,
      localTimestamp: localTimestamp,
      serverTimestamp: serverTimestamp,
      conflictingFields: conflictingFields,
      detectedAt: detectedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      sanitizedMetadata: sanitizedMetadata ?? this.sanitizedMetadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conflict_id': conflictId,
      'operation_id': operationId,
      'user_id': userId,
      'entity_type': entityType,
      'entity_id': entityId,
      'conflict_type': conflictType.name,
      'resolution_state': resolutionState.name,
      'base_server_version': baseServerVersion,
      'local_revision': localRevision,
      'server_version': serverVersion,
      'local_action': localAction,
      'server_action': serverAction,
      'local_timestamp': localTimestamp.toIso8601String(),
      'server_timestamp': serverTimestamp?.toIso8601String(),
      'conflicting_fields': conflictingFields.join(','),
      'detected_at': detectedAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'resolution_notes': resolutionNotes,
    };
  }

  factory SyncConflict.fromMap(Map<String, dynamic> map, {Map<String, dynamic>? metadata}) {
    return SyncConflict(
      conflictId: map['conflict_id'] as String,
      operationId: map['operation_id'] as String,
      userId: map['user_id'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      conflictType: ConflictType.fromString(map['conflict_type'] as String),
      resolutionState: ConflictResolutionState.fromString(map['resolution_state'] as String),
      baseServerVersion: (map['base_server_version'] as num?)?.toInt(),
      localRevision: (map['local_revision'] as num?)?.toInt(),
      serverVersion: (map['server_version'] as num?)?.toInt(),
      localAction: map['local_action'] as String? ?? 'update',
      serverAction: map['server_action'] as String?,
      localTimestamp: DateTime.parse(map['local_timestamp'] as String),
      serverTimestamp: map['server_timestamp'] != null
          ? DateTime.tryParse(map['server_timestamp'] as String)
          : null,
      conflictingFields: (map['conflicting_fields'] as String?)?.isNotEmpty == true
          ? (map['conflicting_fields'] as String).split(',')
          : const [],
      detectedAt: DateTime.parse(map['detected_at'] as String),
      resolvedAt: map['resolved_at'] != null ? DateTime.tryParse(map['resolved_at'] as String) : null,
      resolutionNotes: map['resolution_notes'] as String?,
      sanitizedMetadata: metadata ?? const {},
    );
  }
}
