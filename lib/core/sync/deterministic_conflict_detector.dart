/// SafeMate Deterministic Conflict Detection Engine.
/// Universal Engineering Rule #6: Strict schema validation and sanitized domain models.
/// Universal Engineering Rule #7: Client never overrides server authority.
/// Universal Engineering Rule #11: Deterministic state machines and zero-trust synchronization.
/// Universal Engineering Rule #18: Server is authoritative on conflict; no wall-clock LWW.
library;

import 'conflict_models.dart';

/// Classification of field-level differences in three-way comparison.
enum FieldChangeType {
  /// Unmodified on both local and server relative to base (B == L == S).
  unchanged,

  /// Modified exclusively on the local client (B != L, B == S).
  localOnly,

  /// Modified exclusively on the remote server (B == L, B != S).
  serverOnly,

  /// Modified identically on both local and server (B != L, B != S, L == S).
  bothSame,

  /// Modified differently on local and server (B != L, B != S, L != S). True collision.
  bothDifferent;

  bool get isConflict => this == FieldChangeType.bothDifferent;
}

/// Operation type being evaluated during synchronization.
enum EntityOperation {
  create,
  update,
  delete;

  static EntityOperation fromString(String val) {
    switch (val.toLowerCase()) {
      case 'create':
      case 'save_draft':
        return EntityOperation.create;
      case 'delete':
      case 'delete_draft':
        return EntityOperation.delete;
      case 'update':
      case 'transition_status':
      default:
        return EntityOperation.update;
    }
  }
}

/// Strongly-typed representation of a field-level difference.
class FieldDifference {
  final String fieldName;
  final dynamic baseValue;
  final dynamic localValue;
  final dynamic serverValue;
  final FieldChangeType changeType;

  const FieldDifference({
    required this.fieldName,
    required this.baseValue,
    required this.localValue,
    required this.serverValue,
    required this.changeType,
  });

  bool get isConflict => changeType.isConflict;
}

/// Result of a three-way field comparison across BASE, LOCAL, and SERVER states.
class ThreeWayComparisonResult {
  final Map<String, FieldDifference> differences;
  final List<String> conflictingFields;
  final List<String> localOnlyFields;
  final List<String> serverOnlyFields;
  final List<String> bothSameFields;
  final List<String> authoritativeViolations;

  const ThreeWayComparisonResult({
    required this.differences,
    required this.conflictingFields,
    required this.localOnlyFields,
    required this.serverOnlyFields,
    required this.bothSameFields,
    this.authoritativeViolations = const [],
  });

  bool get hasConflicts => conflictingFields.isNotEmpty;
  bool get hasAuthoritativeViolations => authoritativeViolations.isNotEmpty;

  factory ThreeWayComparisonResult.empty() {
    return const ThreeWayComparisonResult(
      differences: {},
      conflictingFields: [],
      localOnlyFields: [],
      serverOnlyFields: [],
      bothSameFields: [],
      authoritativeViolations: [],
    );
  }
}

/// Encapsulated input parameters for deterministic conflict evaluation.
/// Zero-dependency: does not access database, network, clock, or RNG.
class ConflictDetectionInput {
  final String userId;
  final String entityType;
  final String entityId;
  final EntityOperation operation;
  final int? localBaseVersion;
  final int? localRevision;
  final int? serverVersion;
  final Map<String, dynamic>? baseState;
  final Map<String, dynamic>? localState;
  final Map<String, dynamic>? serverState;
  final bool isServerDeleted;
  final bool isLocalDeleted;
  final bool userHasPermission;
  final bool sessionValid;
  final DateTime localTimestamp;
  final DateTime? serverTimestamp;
  final String? clientMessageId;
  final String operationId;

  ConflictDetectionInput({
    required this.userId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.localBaseVersion,
    this.localRevision,
    this.serverVersion,
    this.baseState,
    this.localState,
    this.serverState,
    this.isServerDeleted = false,
    this.isLocalDeleted = false,
    this.userHasPermission = true,
    this.sessionValid = true,
    required this.localTimestamp,
    this.serverTimestamp,
    this.clientMessageId,
    String? operationId,
  }) : operationId = operationId ?? '${entityType}_${entityId}_${localBaseVersion ?? 0}' {
    if (userId.trim().isEmpty) {
      throw ArgumentError('ConflictDetectionInput requires a valid, non-empty userId.');
    }
  }
}

/// Result returned by [DeterministicConflictDetector].
class ConflictDetectionResult {
  final bool hasConflict;
  final ConflictType? conflictType;
  final SyncConflict? conflict;
  final ThreeWayComparisonResult? threeWayComparison;
  final String reason;
  final bool isReconciled;
  final bool isExcludedFromConflictResolution;

  const ConflictDetectionResult({
    required this.hasConflict,
    this.conflictType,
    this.conflict,
    this.threeWayComparison,
    required this.reason,
    this.isReconciled = false,
    this.isExcludedFromConflictResolution = false,
  });

  /// Factory for a clean, non-conflicting sync candidate.
  factory ConflictDetectionResult.noConflict({
    ThreeWayComparisonResult? threeWay,
    String reason = 'Versions match; no conflict detected.',
  }) {
    return ConflictDetectionResult(
      hasConflict: false,
      threeWayComparison: threeWay,
      reason: reason,
    );
  }

  /// Factory for reconciled state (e.g. mutual deletion).
  factory ConflictDetectionResult.reconciled({required String reason}) {
    return ConflictDetectionResult(
      hasConflict: false,
      reason: reason,
      isReconciled: true,
    );
  }

  /// Factory for entities excluded from normal 3-way conflict resolution (e.g. chat).
  factory ConflictDetectionResult.chatExclusion({required String clientMessageId}) {
    return ConflictDetectionResult(
      hasConflict: false,
      reason: 'Chat messages are idempotent append-only events (client_message_id: $clientMessageId).',
      isExcludedFromConflictResolution: true,
    );
  }

  /// Factory for SafeTrip state machine boundary exclusion.
  factory ConflictDetectionResult.safeTripExclusion({
    required String reason,
    SyncConflict? conflict,
  }) {
    return ConflictDetectionResult(
      hasConflict: conflict != null,
      conflictType: conflict?.conflictType ?? ConflictType.serverStateChanged,
      conflict: conflict,
      reason: reason,
      isExcludedFromConflictResolution: true,
    );
  }
}

/// Pure deterministic conflict detector.
///
/// Mathematical properties:
/// 1. Pure: No side effects, no I/O, no network calls.
/// 2. Deterministic: Equal inputs unconditionally produce equal outputs.
/// 3. Clock-skew invariant: Decisions are based on optimistic concurrency versions
///    and state values, never device wall-clock time (`updatedAt`).
class DeterministicConflictDetector {
  const DeterministicConflictDetector();

  // --------------------------------------------------------------------------
  // Server-Authoritative Fields Registry
  // Client is strictly forbidden from mutating or claiming local authority.
  // --------------------------------------------------------------------------
  static const Set<String> serverAuthoritativeProfileFields = {
    'trust_score',
    'is_verified',
    'verification_status',
    'reliability_rating',
    'trips_completed',
    'moderation_state',
    'is_suspended',
    'suspension_reason',
    'role',
    'user_id',
    'id',
  };

  static const Set<String> serverAuthoritativeTripFields = {
    'user_id',
    'owner_id',
    'id',
    'version',
  };

  static const Set<String> serverAuthoritativeSafeTripFields = {
    'status',
    'is_sos_active',
    'safety_authorization',
    'emergency_state',
    'owner_id',
    'trip_id',
    'id',
  };

  /// Main entrypoint: Evaluates an incoming sync operation against server state.
  static ConflictDetectionResult detectConflict(ConflictDetectionInput input) {
    // 1. User Isolation Check: userId must be non-empty
    if (input.userId.trim().isEmpty) {
      throw ArgumentError('ConflictDetectionInput requires a valid, non-empty userId.');
    }

    // 2. Chat Exclusion Boundary:
    // Chat messages are append-only idempotent entities identified by client_message_id.
    if (input.entityType == 'chat_message' || input.entityType == 'chat') {
      final clientMsgId = input.clientMessageId ??
          input.localState?['client_message_id'] as String? ??
          input.entityId;
      return ConflictDetectionResult.chatExclusion(clientMessageId: clientMsgId);
    }

    // 3. SafeTrip Exclusion Boundary:
    // SafeTrip lifecycle states are strictly server-authoritative.
    if (input.entityType == 'safetrip' || input.entityType == 'safe_trip') {
      return _evaluateSafeTripBoundary(input);
    }

    // 4. Authentication & Permission Checks
    if (!input.sessionValid) {
      return _buildConflictResult(
        input: input,
        conflictType: ConflictType.authenticationConflict,
        reason: 'Client authentication session is invalid or revoked.',
      );
    }

    if (!input.userHasPermission) {
      return _buildConflictResult(
        input: input,
        conflictType: ConflictType.permissionChanged,
        reason: 'User permissions or role changed; mutation is unauthorized.',
      );
    }

    // 5. Delete Conflict Matrix
    // CASE C: Both server and local agree entity is deleted -> Reconciled
    final isLocalDeleting = input.operation == EntityOperation.delete || input.isLocalDeleted;
    if (isLocalDeleting && input.isServerDeleted) {
      return ConflictDetectionResult.reconciled(
        reason: 'Entity is deleted on both local client and remote server; reconciled without conflict.',
      );
    }

    // CASE A: Local update while server entity deleted -> updateVsDelete
    if (!isLocalDeleting && input.isServerDeleted) {
      return _buildConflictResult(
        input: input,
        conflictType: ConflictType.updateVsDelete,
        reason: 'Local mutation attempted on an entity that was deleted on the server.',
        serverAction: 'deleted',
      );
    }

    // CASE B: Local delete while server entity modified -> deleteVsUpdate
    if (isLocalDeleting && !input.isServerDeleted) {
      final sVersion = input.serverVersion ?? 1;
      final bVersion = input.localBaseVersion ?? 1;
      if (sVersion > bVersion) {
        return _buildConflictResult(
          input: input,
          conflictType: ConflictType.deleteVsUpdate,
          reason: 'Local delete attempted, but server entity was updated concurrently (version $sVersion > base $bVersion).',
          serverAction: 'updated',
        );
      }
      // If server version equals base version, the local delete can proceed without conflict
      return ConflictDetectionResult.noConflict(
        reason: 'Local delete matches server base version; safe to delete.',
      );
    }

    // 6. Server-Authoritative Field Tampering Check
    final authoritativeViolations = _findAuthoritativeViolations(
      entityType: input.entityType,
      localState: input.localState,
      serverState: input.serverState,
      baseState: input.baseState,
    );

    if (authoritativeViolations.isNotEmpty) {
      return _buildConflictResult(
        input: input,
        conflictType: ConflictType.permissionChanged,
        reason: 'Local state attempted to modify server-authoritative protected fields: ${authoritativeViolations.join(', ')}.',
        conflictingFields: authoritativeViolations,
      );
    }

    // 7. Core Version Rule: local.baseServerVersion == server.version
    // Optimistic Concurrency Comparison
    final localBase = input.localBaseVersion;
    final serverVer = input.serverVersion;

    // Both versions known
    if (localBase != null && serverVer != null) {
      if (localBase < serverVer) {
        // Stale base: The server has advanced past the version this client branched from
        final threeWay = _performThreeWayComparison(input);
        return _buildConflictResult(
          input: input,
          conflictType: ConflictType.staleBase,
          reason: 'Stale base version: client branched from server version $localBase, but server is at version $serverVer.',
          threeWay: threeWay,
          conflictingFields: threeWay.conflictingFields,
        );
      } else if (localBase > serverVer) {
        // Future/invalid base: client claims a base version higher than server
        return _buildConflictResult(
          input: input,
          conflictType: ConflictType.concurrentUpdate,
          reason: 'Invalid base version: client claims base version $localBase which exceeds current server version $serverVer.',
        );
      }
    }

    // 8. Three-Way Field Difference Evaluation (when base == server)
    final threeWay = _performThreeWayComparison(input);
    if (threeWay.hasConflicts) {
      return _buildConflictResult(
        input: input,
        conflictType: ConflictType.concurrentUpdate,
        reason: 'Field-level collision detected on user-editable fields: ${threeWay.conflictingFields.join(', ')}.',
        threeWay: threeWay,
        conflictingFields: threeWay.conflictingFields,
      );
    }

    // Clean match
    return ConflictDetectionResult.noConflict(
      threeWay: threeWay,
      reason: 'No conflict detected. Optimistic concurrency criteria satisfied.',
    );
  }

  // --------------------------------------------------------------------------
  // SafeTrip Boundary Evaluation
  // --------------------------------------------------------------------------
  static ConflictDetectionResult _evaluateSafeTripBoundary(ConflictDetectionInput input) {
    final localStatus = input.localState?['status'] as String?;
    final serverStatus = input.serverState?['status'] as String?;

    if (serverStatus != null && localStatus != null && localStatus != serverStatus) {
      final conflict = SyncConflict(
        conflictId: 'conflict_${input.operationId}',
        operationId: input.operationId,
        userId: input.userId,
        entityType: input.entityType,
        entityId: input.entityId,
        conflictType: ConflictType.serverStateChanged,
        baseServerVersion: input.localBaseVersion,
        localRevision: input.localRevision,
        serverVersion: input.serverVersion,
        localAction: input.operation.name,
        serverAction: 'status_transition',
        localTimestamp: input.localTimestamp,
        serverTimestamp: input.serverTimestamp,
        conflictingFields: ['status'],
        detectedAt: input.localTimestamp,
        resolutionNotes: 'SafeTrip status is server-authoritative ($serverStatus). Local state ($localStatus) cannot override.',
      );

      return ConflictDetectionResult.safeTripExclusion(
        reason: 'SafeTrip state machine is strictly server-authoritative. Server status is "$serverStatus", local attempted "$localStatus".',
        conflict: conflict,
      );
    }

    return ConflictDetectionResult.safeTripExclusion(
      reason: 'SafeTrip state preserved under server authority.',
    );
  }

  // --------------------------------------------------------------------------
  // Authoritative Field Violation Detector
  // --------------------------------------------------------------------------
  static List<String> _findAuthoritativeViolations({
    required String entityType,
    required Map<String, dynamic>? localState,
    required Map<String, dynamic>? serverState,
    required Map<String, dynamic>? baseState,
  }) {
    if (localState == null) return const [];

    Set<String> protectedFields;
    switch (entityType.toLowerCase()) {
      case 'profile':
      case 'user_profile':
        protectedFields = serverAuthoritativeProfileFields;
        break;
      case 'trip':
        protectedFields = serverAuthoritativeTripFields;
        break;
      case 'safetrip':
      case 'safe_trip':
        protectedFields = serverAuthoritativeSafeTripFields;
        break;
      default:
        protectedFields = const {};
    }

    final violations = <String>[];

    for (final field in protectedFields) {
      if (!localState.containsKey(field)) continue;

      final localVal = localState[field];
      final baseVal = baseState?[field];
      final serverVal = serverState?[field];

      // If local value differs from base or server, flag unauthorized alteration
      if (baseVal != null && !_areValuesEqual(localVal, baseVal)) {
        violations.add(field);
      } else if (baseVal == null && serverVal != null && !_areValuesEqual(localVal, serverVal)) {
        violations.add(field);
      }
    }

    return violations;
  }

  // --------------------------------------------------------------------------
  // Three-Way Field Difference Engine
  // Evaluates BASE, LOCAL, and SERVER for user-editable fields.
  // --------------------------------------------------------------------------
  static ThreeWayComparisonResult compareThreeWay(
    Map<String, dynamic>? base,
    Map<String, dynamic>? local,
    Map<String, dynamic>? server, {
    required String entityType,
  }) {
    if (local == null && server == null) {
      return ThreeWayComparisonResult.empty();
    }

    final b = base ?? const {};
    final l = local ?? const {};
    final s = server ?? const {};

    // Collect all candidate editable fields
    final candidateFields = <String>{...b.keys, ...l.keys, ...s.keys};

    final differences = <String, FieldDifference>{};
    final conflictingFields = <String>[];
    final localOnlyFields = <String>[];
    final serverOnlyFields = <String>[];
    final bothSameFields = <String>[];

    for (final field in candidateFields) {
      // Ignore technical metadata fields in field-level content diff
      if (field == 'version' ||
          field == 'base_server_version' ||
          field == 'local_revision' ||
          field == 'server_version' ||
          field == 'updated_at' ||
          field == 'created_at' ||
          field == 'last_synced_at') {
        continue;
      }

      final bVal = b[field];
      final lVal = l[field];
      final sVal = s[field];

      final localChanged = !_areValuesEqual(bVal, lVal);
      final serverChanged = !_areValuesEqual(bVal, sVal);

      FieldChangeType changeType;

      if (!localChanged && !serverChanged) {
        changeType = FieldChangeType.unchanged;
      } else if (localChanged && !serverChanged) {
        changeType = FieldChangeType.localOnly;
        localOnlyFields.add(field);
      } else if (!localChanged && serverChanged) {
        changeType = FieldChangeType.serverOnly;
        serverOnlyFields.add(field);
      } else {
        // Both changed relative to base
        if (_areValuesEqual(lVal, sVal)) {
          changeType = FieldChangeType.bothSame;
          bothSameFields.add(field);
        } else {
          changeType = FieldChangeType.bothDifferent;
          conflictingFields.add(field);
        }
      }

      differences[field] = FieldDifference(
        fieldName: field,
        baseValue: bVal,
        localValue: lVal,
        serverValue: sVal,
        changeType: changeType,
      );
    }

    return ThreeWayComparisonResult(
      differences: differences,
      conflictingFields: conflictingFields,
      localOnlyFields: localOnlyFields,
      serverOnlyFields: serverOnlyFields,
      bothSameFields: bothSameFields,
    );
  }

  static ThreeWayComparisonResult _performThreeWayComparison(ConflictDetectionInput input) {
    return compareThreeWay(
      input.baseState,
      input.localState,
      input.serverState,
      entityType: input.entityType,
    );
  }

  // --------------------------------------------------------------------------
  // Deep Equality Helper for Heterogeneous Map Values
  // --------------------------------------------------------------------------
  static bool _areValuesEqual(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;

    // Handle numeric type coercion (int vs double vs num)
    if (a is num && b is num) {
      return a == b;
    }

    // Handle string comparisons (trimmed)
    if (a is String && b is String) {
      return a.trim() == b.trim();
    }

    // Handle Lists
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_areValuesEqual(a[i], b[i])) return false;
      }
      return true;
    }

    // Handle Maps
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key)) return false;
        if (!_areValuesEqual(a[key], b[key])) return false;
      }
      return true;
    }

    return a == b;
  }

  // --------------------------------------------------------------------------
  // SyncConflict Model Builder
  // Enforces user isolation and sanitized metadata.
  // --------------------------------------------------------------------------
  static ConflictDetectionResult _buildConflictResult({
    required ConflictDetectionInput input,
    required ConflictType conflictType,
    required String reason,
    String? serverAction,
    List<String> conflictingFields = const [],
    ThreeWayComparisonResult? threeWay,
  }) {
    final conflict = SyncConflict(
      conflictId: 'conflict_${input.operationId}',
      operationId: input.operationId,
      userId: input.userId,
      entityType: input.entityType,
      entityId: input.entityId,
      conflictType: conflictType,
      baseServerVersion: input.localBaseVersion,
      localRevision: input.localRevision,
      serverVersion: input.serverVersion,
      localAction: input.operation.name,
      serverAction: serverAction ?? (input.isServerDeleted ? 'deleted' : 'updated'),
      localTimestamp: input.localTimestamp,
      serverTimestamp: input.serverTimestamp,
      conflictingFields: conflictingFields.isNotEmpty
          ? conflictingFields
          : (threeWay?.conflictingFields ?? const []),
      detectedAt: input.localTimestamp,
      resolutionNotes: reason,
      sanitizedMetadata: {
        'entity_type': input.entityType,
        'entity_id': input.entityId,
        'local_base_version': input.localBaseVersion,
        'server_version': input.serverVersion,
        'reason': reason,
      },
    );

    return ConflictDetectionResult(
      hasConflict: true,
      conflictType: conflictType,
      conflict: conflict,
      threeWayComparison: threeWay,
      reason: reason,
    );
  }
}
