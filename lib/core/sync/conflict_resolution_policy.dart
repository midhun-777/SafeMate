/// SafeMate Entity-Specific Conflict Resolution Policies & Central Registry.
/// Universal Engineering Rule #6: Strict schema validation and sanitized domain models.
/// Universal Engineering Rule #7: Client never overrides server authority.
/// Universal Engineering Rule #11: Deterministic conflict resolution; no generic LWW.
/// Universal Engineering Rule #18: Server is authoritative on conflict; no wall-clock LWW.
library;

import 'dart:convert';
import 'conflict_models.dart';
import 'deterministic_conflict_detector.dart';

/// Explicit outcomes produced by an entity-specific reconciliation policy.
enum ReconciliationOutcome {
  /// All differences were independent and non-conflicting; a merged state was generated.
  merged,

  /// At least one field or lifecycle state experienced a true collision requiring user decision.
  conflict,

  /// The authoritative server state prevailed (e.g. for safety, security, or permissions).
  serverWon,

  /// The local state prevailed (when explicitly permitted by policy for non-authoritative entities).
  localWon,

  /// The local mutation was rejected or discarded (e.g. attempting to update a deleted record).
  discarded,

  /// Reconciled cleanly without action (e.g. mutual deletion).
  reconciled;

  bool get isMerged => this == ReconciliationOutcome.merged;
  bool get isConflict => this == ReconciliationOutcome.conflict;
}

/// Strongly-typed output of an entity reconciliation execution.
class ReconciliationResult {
  final ReconciliationOutcome outcome;
  final Map<String, dynamic>? mergedPayload;
  final List<String> conflictingFields;
  final String reason;
  final bool requiresUserReview;
  final ConflictResolutionState resolutionState;

  const ReconciliationResult({
    required this.outcome,
    this.mergedPayload,
    this.conflictingFields = const [],
    required this.reason,
    this.requiresUserReview = false,
    required this.resolutionState,
  });

  factory ReconciliationResult.merged({
    required Map<String, dynamic> mergedPayload,
    String reason = 'Clean non-conflicting 3-way merge completed.',
  }) {
    return ReconciliationResult(
      outcome: ReconciliationOutcome.merged,
      mergedPayload: mergedPayload,
      reason: reason,
      resolutionState: ConflictResolutionState.merged,
    );
  }

  factory ReconciliationResult.conflict({
    required List<String> conflictingFields,
    required String reason,
    ConflictResolutionState resolutionState = ConflictResolutionState.awaitingResolution,
  }) {
    return ReconciliationResult(
      outcome: ReconciliationOutcome.conflict,
      conflictingFields: conflictingFields,
      reason: reason,
      requiresUserReview: true,
      resolutionState: resolutionState,
    );
  }

  factory ReconciliationResult.serverWon({
    required Map<String, dynamic>? serverPayload,
    required String reason,
  }) {
    return ReconciliationResult(
      outcome: ReconciliationOutcome.serverWon,
      mergedPayload: serverPayload,
      reason: reason,
      resolutionState: ConflictResolutionState.resolvedServer,
    );
  }

  factory ReconciliationResult.discarded({required String reason}) {
    return ReconciliationResult(
      outcome: ReconciliationOutcome.discarded,
      reason: reason,
      resolutionState: ConflictResolutionState.discarded,
    );
  }

  factory ReconciliationResult.reconciled({required String reason}) {
    return ReconciliationResult(
      outcome: ReconciliationOutcome.reconciled,
      reason: reason,
      resolutionState: ConflictResolutionState.resolvedServer,
    );
  }
}

/// Encapsulated execution context passed to an entity reconciliation policy.
class ReconciliationContext {
  final String entityType;
  final String entityId;
  final String userId;
  final int? baseVersion;
  final int? serverVersion;
  final Map<String, dynamic>? baseState;
  final Map<String, dynamic>? localState;
  final Map<String, dynamic>? serverState;
  final ThreeWayComparisonResult threeWay;
  final bool isServerDeleted;
  final bool isLocalDeleted;

  const ReconciliationContext({
    required this.entityType,
    required this.entityId,
    required this.userId,
    this.baseVersion,
    this.serverVersion,
    this.baseState,
    this.localState,
    this.serverState,
    required this.threeWay,
    this.isServerDeleted = false,
    this.isLocalDeleted = false,
  });
}

/// Abstract contract for entity-specific conflict resolution policies.
abstract class EntityConflictPolicy {
  String get entityType;
  Set<String> get userEditableFields;
  Set<String> get serverAuthoritativeFields;

  /// Executes deterministic reconciliation on the provided 3-way context.
  ReconciliationResult reconcile(ReconciliationContext context);
}

// -----------------------------------------------------------------------------
// 1. Trip Conflict Policy
// -----------------------------------------------------------------------------
class TripConflictPolicy implements EntityConflictPolicy {
  const TripConflictPolicy();

  @override
  String get entityType => 'trip';

  @override
  Set<String> get userEditableFields => const {
        'title',
        'origin',
        'destination',
        'start_date',
        'end_date',
        'estimated_budget',
        'budget',
        'currency',
        'transport_mode',
        'trip_purpose',
        'visibility',
        'budget_tier',
        'max_companions',
      };

  @override
  Set<String> get serverAuthoritativeFields => const {
        'id',
        'user_id',
        'owner_id',
        'version',
        'status',
        'moderation_state',
      };

  @override
  ReconciliationResult reconcile(ReconciliationContext context) {
    // 1. Delete Conflicts
    if (context.isServerDeleted && context.isLocalDeleted) {
      return ReconciliationResult.reconciled(
        reason: 'Both local and server agree entity is deleted; reconciled.',
      );
    }

    if (context.isServerDeleted) {
      // Never resurrect deleted trips
      return ReconciliationResult.discarded(
        reason: 'Trip was deleted on the server; local mutation discarded.',
      );
    }

    if (context.isLocalDeleted) {
      if ((context.serverVersion ?? 1) > (context.baseVersion ?? 1)) {
        return ReconciliationResult.conflict(
          conflictingFields: const ['status'],
          reason: 'Trip was modified on the server while deleted locally.',
        );
      }
      return ReconciliationResult.reconciled(reason: 'Local trip delete acknowledged.');
    }

    // 2. Lifecycle Safety: Disallow overwriting terminal states
    final serverStatus = context.serverState?['status'] as String?;
    final localStatus = context.localState?['status'] as String?;
    if (serverStatus == 'cancelled' && localStatus != 'cancelled') {
      return ReconciliationResult.serverWon(
        serverPayload: context.serverState,
        reason: 'Trip was cancelled on the server. Local offline mutations cannot resurrect cancelled trips.',
      );
    }
    if (serverStatus == 'completed' && localStatus != 'completed') {
      return ReconciliationResult.serverWon(
        serverPayload: context.serverState,
        reason: 'Trip was completed on the server. Local offline state cannot alter a completed trip.',
      );
    }

    // 3. Three-Way Content Reconcile
    if (context.threeWay.hasConflicts) {
      return ReconciliationResult.conflict(
        conflictingFields: context.threeWay.conflictingFields,
        reason: 'Concurrent modifications on fields: ${context.threeWay.conflictingFields.join(', ')}.',
      );
    }

    // Apply safe independent field updates onto server state baseline
    final merged = Map<String, dynamic>.from(context.serverState ?? {});
    for (final field in context.threeWay.localOnlyFields) {
      if (userEditableFields.contains(field)) {
        merged[field] = context.localState?[field];
      }
    }

    // Ensure server-authoritative fields remain untouched
    for (final field in serverAuthoritativeFields) {
      if (context.serverState?.containsKey(field) == true) {
        merged[field] = context.serverState?[field];
      }
    }

    return ReconciliationResult.merged(
      mergedPayload: merged,
      reason: 'Trip successfully merged non-conflicting fields: ${context.threeWay.localOnlyFields.join(', ')}.',
    );
  }
}

// -----------------------------------------------------------------------------
// 2. Profile Conflict Policy
// -----------------------------------------------------------------------------
class ProfileConflictPolicy implements EntityConflictPolicy {
  const ProfileConflictPolicy();

  @override
  String get entityType => 'profile';

  @override
  Set<String> get userEditableFields => const {
        'display_name',
        'bio',
        'home_city',
        'travel_personality',
        'interests',
        'languages',
        'avatar_url',
        'profile_visibility',
      };

  @override
  Set<String> get serverAuthoritativeFields => const {
        'id',
        'user_id',
        'trust_score',
        'is_verified',
        'verification_status',
        'reliability_rating',
        'trips_completed',
        'moderation_state',
        'is_suspended',
        'role',
      };

  @override
  ReconciliationResult reconcile(ReconciliationContext context) {
    if (context.isServerDeleted) {
      return ReconciliationResult.discarded(
        reason: 'Profile was deleted on server.',
      );
    }

    // Filter out any conflicting user-editable fields
    final userConflicts = context.threeWay.conflictingFields
        .where((f) => userEditableFields.contains(f))
        .toList();

    if (userConflicts.isNotEmpty) {
      return ReconciliationResult.conflict(
        conflictingFields: userConflicts,
        reason: 'Concurrent profile edits collided on: ${userConflicts.join(', ')}.',
      );
    }

    // Clean merge
    final merged = Map<String, dynamic>.from(context.serverState ?? {});
    for (final field in context.threeWay.localOnlyFields) {
      if (userEditableFields.contains(field)) {
        merged[field] = context.localState?[field];
      }
    }

    // Unconditionally force server values for authoritative scoring and security fields
    for (final field in serverAuthoritativeFields) {
      if (context.serverState?.containsKey(field) == true) {
        merged[field] = context.serverState?[field];
      }
    }

    return ReconciliationResult.merged(
      mergedPayload: merged,
      reason: 'Profile non-conflicting fields merged successfully.',
    );
  }
}

// -----------------------------------------------------------------------------
// 3. Trip Preferences Conflict Policy (3-State Model Aware)
// -----------------------------------------------------------------------------
class TripPreferencesConflictPolicy implements EntityConflictPolicy {
  const TripPreferencesConflictPolicy();

  @override
  String get entityType => 'trip_preferences';

  @override
  Set<String> get userEditableFields => const {
        'budget_tier',
        'preferred_gender',
        'travel_pace',
        'activities',
        'transport',
        'accommodation',
        'dietary',
      };

  @override
  Set<String> get serverAuthoritativeFields => const {
        'id',
        'trip_id',
        'user_id',
        'version',
      };

  @override
  ReconciliationResult reconcile(ReconciliationContext context) {
    if (context.isServerDeleted) {
      return ReconciliationResult.discarded(reason: 'Trip preferences deleted on server.');
    }

    // 3-State Evaluation for collections or scalar preferences
    final merged = Map<String, dynamic>.from(context.serverState ?? {});
    final collisions = <String>[];

    final b = context.baseState ?? {};
    final l = context.localState ?? {};
    final s = context.serverState ?? {};

    final allKeys = <String>{...b.keys, ...l.keys, ...s.keys}
        .where((k) => userEditableFields.contains(k));

    for (final key in allKeys) {
      final bVal = b[key];
      final lVal = l[key];
      final sVal = s[key];

      // Handle 3-state map representations (e.g. {'hiking': 'selected'})
      if (lVal is Map && sVal is Map) {
        final mergedSubMap = Map<String, dynamic>.from(sVal);
        final bSub = (bVal is Map) ? bVal : {};
        final subKeys = <String>{...bSub.keys.cast<String>(), ...lVal.keys.cast<String>(), ...sVal.keys.cast<String>()};

        for (final subKey in subKeys) {
          final bItem = bSub[subKey] ?? 'notSpecified';
          final lItem = lVal[subKey] ?? 'notSpecified';
          final sItem = sVal[subKey] ?? 'notSpecified';

          if (lItem != bItem && sItem == bItem) {
            // Local-only choice
            mergedSubMap[subKey] = lItem;
          } else if (lItem != bItem && sItem != bItem && lItem != sItem) {
            // Collision: e.g. local 'selected' vs server 'notSelected'
            collisions.add('$key.$subKey');
          }
        }
        merged[key] = mergedSubMap;
      } else {
        // Scalar preference
        if (lVal != bVal && sVal == bVal) {
          merged[key] = lVal;
        } else if (lVal != bVal && sVal != bVal && lVal != sVal) {
          collisions.add(key);
        }
      }
    }

    if (collisions.isNotEmpty) {
      return ReconciliationResult.conflict(
        conflictingFields: collisions,
        reason: 'Conflicting preferences on: ${collisions.join(', ')}.',
      );
    }

    return ReconciliationResult.merged(
      mergedPayload: merged,
      reason: 'Preferences 3-state merge completed.',
    );
  }
}

// -----------------------------------------------------------------------------
// 4. Itinerary Conflict Policy (Day & Item Aware)
// -----------------------------------------------------------------------------
class ItineraryConflictPolicy implements EntityConflictPolicy {
  const ItineraryConflictPolicy();

  @override
  String get entityType => 'itinerary';

  @override
  Set<String> get userEditableFields => const {
        'title',
        'days_json',
      };

  @override
  Set<String> get serverAuthoritativeFields => const {
        'id',
        'trip_id',
        'user_id',
        'version',
      };

  @override
  ReconciliationResult reconcile(ReconciliationContext context) {
    if (context.isServerDeleted) {
      return ReconciliationResult.discarded(reason: 'Itinerary was deleted on server.');
    }

    // Scalar title merge
    final bTitle = context.baseState?['title'];
    final lTitle = context.localState?['title'];
    final sTitle = context.serverState?['title'];

    String mergedTitle = sTitle as String? ?? 'Itinerary';
    if (lTitle != bTitle && sTitle == bTitle) {
      mergedTitle = lTitle as String;
    } else if (lTitle != bTitle && sTitle != bTitle && lTitle != sTitle) {
      return ReconciliationResult.conflict(
        conflictingFields: const ['title'],
        reason: 'Concurrent modification to itinerary title.',
      );
    }

    // Day & Item Aware Reconcile for days_json
    final daysResult = _reconcileDays(
      context.baseState?['days_json'],
      context.localState?['days_json'],
      context.serverState?['days_json'],
    );

    if (daysResult.isConflict) {
      return ReconciliationResult.conflict(
        conflictingFields: daysResult.conflictingItems,
        reason: daysResult.reason,
      );
    }

    final merged = Map<String, dynamic>.from(context.serverState ?? {});
    merged['title'] = mergedTitle;
    merged['days_json'] = daysResult.mergedDaysJson;

    return ReconciliationResult.merged(
      mergedPayload: merged,
      reason: 'Itinerary days and items merged without collision.',
    );
  }

  static _DaysMergeResult _reconcileDays(dynamic baseJson, dynamic localJson, dynamic serverJson) {
    final List<dynamic> baseDays = _parseDays(baseJson);
    final List<dynamic> localDays = _parseDays(localJson);
    final List<dynamic> serverDays = _parseDays(serverJson);

    // Map days by day number
    final baseByDay = {for (final d in baseDays) (d['day'] as num?)?.toInt() ?? 0: d};
    final localByDay = {for (final d in localDays) (d['day'] as num?)?.toInt() ?? 0: d};
    final serverByDay = {for (final d in serverDays) (d['day'] as num?)?.toInt() ?? 0: d};

    final allDayNumbers = <int>{...baseByDay.keys, ...localByDay.keys, ...serverByDay.keys}.toList()
      ..sort();

    final mergedDays = <Map<String, dynamic>>[];
    final collisions = <String>[];

    for (final dayNum in allDayNumbers) {
      final bDay = baseByDay[dayNum];
      final lDay = localByDay[dayNum];
      final sDay = serverByDay[dayNum];

      if (lDay != null && sDay == null && bDay == null) {
        // Independent new day added locally
        mergedDays.add(Map<String, dynamic>.from(lDay as Map));
      } else if (sDay != null && lDay == null && bDay == null) {
        // Independent new day added on server
        mergedDays.add(Map<String, dynamic>.from(sDay as Map));
      } else if (lDay != null && sDay != null && bDay == null) {
        // Both added the same day independently: check item collision
        final itemResult = _reconcileDayItems(null, lDay['items'], sDay['items'], dayNum);
        if (itemResult.isConflict) {
          collisions.addAll(itemResult.conflicts);
        } else {
          final mDay = Map<String, dynamic>.from(sDay as Map);
          mDay['items'] = itemResult.mergedItems;
          mergedDays.add(mDay);
        }
      } else if (lDay != null && sDay != null && bDay != null) {
        // Day exists in all three: reconcile items within day
        final itemResult = _reconcileDayItems(bDay['items'], lDay['items'], sDay['items'], dayNum);
        if (itemResult.isConflict) {
          collisions.addAll(itemResult.conflicts);
        } else {
          final mDay = Map<String, dynamic>.from(sDay as Map);
          mDay['items'] = itemResult.mergedItems;
          mergedDays.add(mDay);
        }
      } else if (sDay != null) {
        mergedDays.add(Map<String, dynamic>.from(sDay as Map));
      }
    }

    if (collisions.isNotEmpty) {
      return _DaysMergeResult.conflict(
        conflictingItems: collisions,
        reason: 'Collisions in itinerary items: ${collisions.join(', ')}.',
      );
    }

    return _DaysMergeResult.merged(jsonEncode(mergedDays));
  }

  static _ItemsMergeResult _reconcileDayItems(dynamic bItems, dynamic lItems, dynamic sItems, int dayNum) {
    final List<dynamic> bList = (bItems is List) ? bItems : [];
    final List<dynamic> lList = (lItems is List) ? lItems : [];
    final List<dynamic> sList = (sItems is List) ? sItems : [];

    final bById = {for (final item in bList) (item is Map ? (item['id'] ?? item['title']) : null): item};
    final lById = {for (final item in lList) (item is Map ? (item['id'] ?? item['title']) : null): item};
    final sById = {for (final item in sList) (item is Map ? (item['id'] ?? item['title']) : null): item};

    final allItemIds = <dynamic>{...bById.keys, ...lById.keys, ...sById.keys}.where((id) => id != null).toList();

    final mergedItems = <Map<String, dynamic>>[];
    final conflicts = <String>[];

    for (final id in allItemIds) {
      final bItem = bById[id];
      final lItem = lById[id];
      final sItem = sById[id];

      if (lItem != null && sItem == null && bItem == null) {
        // Local only item addition
        mergedItems.add(Map<String, dynamic>.from(lItem as Map));
      } else if (sItem != null && lItem == null && bItem == null) {
        // Server only item addition
        mergedItems.add(Map<String, dynamic>.from(sItem as Map));
      } else if (lItem != null && sItem != null) {
        // Both modified or retained item
        final lStr = jsonEncode(lItem);
        final sStr = jsonEncode(sItem);
        final bStr = bItem != null ? jsonEncode(bItem) : null;

        if (lStr == sStr) {
          mergedItems.add(Map<String, dynamic>.from(sItem as Map));
        } else if (lStr != bStr && sStr == bStr) {
          mergedItems.add(Map<String, dynamic>.from(lItem as Map));
        } else if (sStr != bStr && lStr == bStr) {
          mergedItems.add(Map<String, dynamic>.from(sItem as Map));
        } else {
          conflicts.add('Day $dayNum, item $id');
        }
      }
    }

    if (conflicts.isNotEmpty) {
      return _ItemsMergeResult.conflict(conflicts);
    }
    return _ItemsMergeResult.merged(mergedItems);
  }

  static List<dynamic> _parseDays(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw;
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return [];
  }
}

class _DaysMergeResult {
  final bool isConflict;
  final String? mergedDaysJson;
  final List<String> conflictingItems;
  final String reason;

  const _DaysMergeResult._({
    required this.isConflict,
    this.mergedDaysJson,
    this.conflictingItems = const [],
    this.reason = '',
  });

  factory _DaysMergeResult.merged(String json) => _DaysMergeResult._(
        isConflict: false,
        mergedDaysJson: json,
      );

  factory _DaysMergeResult.conflict({required List<String> conflictingItems, required String reason}) =>
      _DaysMergeResult._(
        isConflict: true,
        conflictingItems: conflictingItems,
        reason: reason,
      );
}

class _ItemsMergeResult {
  final bool isConflict;
  final List<Map<String, dynamic>> mergedItems;
  final List<String> conflicts;

  const _ItemsMergeResult._({
    required this.isConflict,
    this.mergedItems = const [],
    this.conflicts = const [],
  });

  factory _ItemsMergeResult.merged(List<Map<String, dynamic>> items) => _ItemsMergeResult._(
        isConflict: false,
        mergedItems: items,
      );

  factory _ItemsMergeResult.conflict(List<String> conflicts) => _ItemsMergeResult._(
        isConflict: true,
        conflicts: conflicts,
      );
}

// -----------------------------------------------------------------------------
// 5. Chat Message Conflict Policy (Idempotent Append-Only)
// -----------------------------------------------------------------------------
class ChatMessageConflictPolicy implements EntityConflictPolicy {
  const ChatMessageConflictPolicy();

  @override
  String get entityType => 'chat_message';

  @override
  Set<String> get userEditableFields => const {}; // Chat messages are append-only

  @override
  Set<String> get serverAuthoritativeFields => const {
        'id',
        'room_id',
        'sender_id',
        'created_at',
        'delivery_status',
      };

  @override
  ReconciliationResult reconcile(ReconciliationContext context) {
    // Chat messages are append-only. Idempotency guarantees convergence onto client_message_id.
    return ReconciliationResult.reconciled(
      reason: 'Chat message converged cleanly via client_message_id idempotency.',
    );
  }
}

// -----------------------------------------------------------------------------
// 6. SafeTrip Conflict Policy (Strict Server Authority)
// -----------------------------------------------------------------------------
class SafeTripConflictPolicy implements EntityConflictPolicy {
  const SafeTripConflictPolicy();

  @override
  String get entityType => 'safetrip';

  @override
  Set<String> get userEditableFields => const {}; // Safety state machine is server-authoritative

  @override
  Set<String> get serverAuthoritativeFields => const {
        'status',
        'is_sos_active',
        'safety_authorization',
        'emergency_state',
        'owner_id',
        'trip_id',
        'id',
      };

  @override
  ReconciliationResult reconcile(ReconciliationContext context) {
    // Server authority unconditionally wins on SafeTrip lifecycle
    final serverStatus = context.serverState?['status'] as String?;
    final localStatus = context.localState?['status'] as String?;

    if (serverStatus != null && localStatus != null && localStatus != serverStatus) {
      return ReconciliationResult.serverWon(
        serverPayload: context.serverState,
        reason: 'SafeTrip status is strictly server-authoritative ($serverStatus). Local state ($localStatus) cannot override.',
      );
    }

    return ReconciliationResult.serverWon(
      serverPayload: context.serverState,
      reason: 'SafeTrip state machine preserved under server authority.',
    );
  }
}

// -----------------------------------------------------------------------------
// 7. Check-in Conflict Policy (Append-Only Idempotent)
// -----------------------------------------------------------------------------
class CheckinConflictPolicy implements EntityConflictPolicy {
  const CheckinConflictPolicy();

  @override
  String get entityType => 'safetrip_checkin';

  @override
  Set<String> get userEditableFields => const {};

  @override
  Set<String> get serverAuthoritativeFields => const {
        'id',
        'journey_id',
        'user_id',
        'idempotency_key',
        'checkin_time',
      };

  @override
  ReconciliationResult reconcile(ReconciliationContext context) {
    return ReconciliationResult.reconciled(
      reason: 'Check-in reconciled via idempotency key.',
    );
  }
}

// -----------------------------------------------------------------------------
// Centralized Deterministic Policy Registry
// -----------------------------------------------------------------------------
class ConflictResolutionPolicyRegistry {
  ConflictResolutionPolicyRegistry._() {
    _registerDefaults();
  }

  static final ConflictResolutionPolicyRegistry instance = ConflictResolutionPolicyRegistry._();

  final Map<String, EntityConflictPolicy> _policies = {};

  void _registerDefaults() {
    registerPolicy(const TripConflictPolicy());
    registerPolicy(const ProfileConflictPolicy());
    registerPolicy(const TripPreferencesConflictPolicy());
    registerPolicy(const ItineraryConflictPolicy());
    registerPolicy(const ChatMessageConflictPolicy());
    registerPolicy(const SafeTripConflictPolicy());
    registerPolicy(const CheckinConflictPolicy());
  }

  /// Registers a custom or overridden policy for an entity type.
  void registerPolicy(EntityConflictPolicy policy) {
    _policies[policy.entityType.toLowerCase()] = policy;
  }

  /// Returns the registered policy, falling back to SafeTrip server-authoritative policy.
  EntityConflictPolicy getPolicy(String entityType) {
    final key = entityType.toLowerCase();
    // Normalize aliases
    if (key == 'chat' || key == 'chat_message') {
      return _policies['chat_message'] ?? const ChatMessageConflictPolicy();
    }
    if (key == 'safetrip' || key == 'safe_trip') {
      return _policies['safetrip'] ?? const SafeTripConflictPolicy();
    }
    if (key == 'checkin' || key == 'safetrip_checkin') {
      return _policies['safetrip_checkin'] ?? const CheckinConflictPolicy();
    }
    return _policies[key] ?? const SafeTripConflictPolicy();
  }
}
