/// SafeMate Conflict Resolution Controller & UX Foundation.
/// Universal Engineering Rule #6: Sanitized presentation models without leaking PII/credentials.
/// Universal Engineering Rule #7: Server authorization bounds all user choices.
/// Universal Engineering Rule #11: Deterministic state machine transitions.
/// Universal Engineering Rule #18: Server is authoritative; no dangerous overrides.
library;

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/local_database_service.dart';
import '../database/database_models.dart';
import '../../features/trips/domain/models/trip.dart';
import '../../features/auth/domain/models/user_profile.dart';
import 'conflict_models.dart';
import 'conflict_resolution_policy.dart';

/// User-facing conflict resolution action choices.
enum UserResolutionAction {
  /// Accept and apply the authoritative server version.
  acceptServer,

  /// Keep the local client edits (only valid for non-authoritative user-editable fields).
  keepLocal,

  /// Inspect detailed differences before deciding.
  reviewDiff;

  String get label {
    switch (this) {
      case UserResolutionAction.acceptServer:
        return 'Use latest version';
      case UserResolutionAction.keepLocal:
        return 'Keep my changes';
      case UserResolutionAction.reviewDiff:
        return 'Review differences';
    }
  }
}

/// Thrown when attempting to resolve a conflict against a server version that has changed since UI review.
class StaleConflictVersionException implements Exception {
  final String message;
  final int uiVersion;
  final int serverVersion;

  const StaleConflictVersionException(
    this.message, {
    required this.uiVersion,
    required this.serverVersion,
  });

  @override
  String toString() => 'StaleConflictVersionException: $message (UI: $uiVersion, Server: $serverVersion)';
}

/// Authoritative snapshot of an entity fetched or supplied from the remote server.
class RemoteEntitySnapshot {
  final Map<String, dynamic>? data;
  final int version;
  final bool isDeleted;

  const RemoteEntitySnapshot({
    required this.data,
    required this.version,
    this.isDeleted = false,
  });
}

/// Interface for querying authoritative remote entity state during conflict resolution.
abstract class RemoteEntitySnapshotProvider {
  Future<RemoteEntitySnapshot?> fetchLatestSnapshot({
    required String entityType,
    required String entityId,
  });
}

/// Sanitized presentation model for conflict review dialogs and banners.
class ConflictPresentationModel {
  final String conflictId;
  final String entityType;
  final String entityId;
  final String userMessage;
  final String details;
  final List<UserResolutionAction> availableActions;
  final bool isInformationOnly;
  final List<String> conflictingFields;
  final SyncConflict? conflict;
  final Map<String, dynamic> localValues;
  final Map<String, dynamic> serverValues;
  final int? baseServerVersion;
  final int? serverVersion;
  final bool isServerDeleted;

  const ConflictPresentationModel({
    required this.conflictId,
    required this.entityType,
    required this.entityId,
    required this.userMessage,
    required this.details,
    required this.availableActions,
    required this.isInformationOnly,
    this.conflictingFields = const [],
    this.conflict,
    this.localValues = const {},
    this.serverValues = const {},
    this.baseServerVersion,
    this.serverVersion,
    this.isServerDeleted = false,
  });
}

/// Coordinates conflict resolution workflows between the UI and local persistence.
class ConflictResolutionController {
  final LocalDatabaseService localDb;
  final ConflictResolutionPolicyRegistry policyRegistry;
  final RemoteEntitySnapshotProvider? snapshotProvider;
  final Uuid _uuid;

  ConflictResolutionController({
    required this.localDb,
    ConflictResolutionPolicyRegistry? registry,
    this.snapshotProvider,
  })  : policyRegistry = registry ?? ConflictResolutionPolicyRegistry.instance,
        _uuid = const Uuid();

  /// Retrieves and formats all unresolved conflicts for a specific user.
  Future<List<ConflictPresentationModel>> getPendingConflicts(String userId) async {
    final records = await localDb.getConflictSyncRecords(userId);
    return records.map((r) {
      final conflict = SyncConflict(
        conflictId: 'conf_${r.operationId}',
        operationId: r.operationId,
        userId: r.userId,
        entityType: r.entityType,
        entityId: r.entityId,
        conflictType: ConflictType.concurrentUpdate,
        localAction: r.action,
        localTimestamp: r.createdAt,
        detectedAt: r.lastAttemptAt ?? r.createdAt,
        baseServerVersion: r.baseServerVersion,
        localRevision: r.localRevision,
        conflictingFields: r.payload.keys.toList(),
      );
      return buildPresentationModel(
        conflict,
        localValues: r.payload,
        baseServerVersion: r.baseServerVersion,
        serverVersion: r.baseServerVersion != null ? r.baseServerVersion! + 1 : 1,
      );
    }).toList();
  }

  /// Builds a friendly, non-technical presentation model strictly bounded by policy permissions.
  ConflictPresentationModel buildPresentationModel(
    SyncConflict conflict, {
    Map<String, dynamic> localValues = const {},
    Map<String, dynamic> serverValues = const {},
    int? baseServerVersion,
    int? serverVersion,
    bool isServerDeleted = false,
  }) {
    final policy = policyRegistry.getPolicy(conflict.entityType);

    // 1. SafeTrip: Strictly informational; never expose "Keep Mine"
    if (conflict.entityType == 'safetrip' || conflict.entityType == 'safe_trip') {
      return ConflictPresentationModel(
        conflictId: conflict.conflictId,
        entityType: conflict.entityType,
        entityId: conflict.entityId,
        userMessage: 'This journey status was updated while you were offline. SafeMate kept the latest verified status.',
        details: conflict.resolutionNotes ?? 'Status machine managed under server authority.',
        availableActions: const [UserResolutionAction.acceptServer],
        isInformationOnly: true,
        conflictingFields: conflict.conflictingFields,
        conflict: conflict,
        localValues: localValues,
        serverValues: serverValues,
        baseServerVersion: baseServerVersion ?? conflict.baseServerVersion,
        serverVersion: serverVersion ?? conflict.serverVersion,
        isServerDeleted: isServerDeleted,
      );
    }

    // 2. Server Deleted: Entity removed remotely; strictly prohibited from resurrection
    if (conflict.conflictType == ConflictType.updateVsDelete || isServerDeleted) {
      return ConflictPresentationModel(
        conflictId: conflict.conflictId,
        entityType: conflict.entityType,
        entityId: conflict.entityId,
        userMessage: 'This item was removed on another device. Local changes cannot be applied.',
        details: 'To preserve system integrity, deleted items are not resurrected.',
        availableActions: const [UserResolutionAction.acceptServer],
        isInformationOnly: true,
        conflictingFields: conflict.conflictingFields,
        conflict: conflict,
        localValues: localValues,
        serverValues: serverValues,
        baseServerVersion: baseServerVersion ?? conflict.baseServerVersion,
        serverVersion: serverVersion ?? conflict.serverVersion,
        isServerDeleted: true,
      );
    }

    // 3. Authoritative Security / Trust / Verification Violations
    final hasAuthoritativeViolation = conflict.conflictingFields.any(
      (f) => policy.serverAuthoritativeFields.contains(f),
    );

    if (hasAuthoritativeViolation) {
      return ConflictPresentationModel(
        conflictId: conflict.conflictId,
        entityType: conflict.entityType,
        entityId: conflict.entityId,
        userMessage: 'This update involves server-verified information. Changes have been aligned with server authority.',
        details: 'Verification status and trust scores are server-authoritative and cannot be overwritten.',
        availableActions: const [
          UserResolutionAction.acceptServer,
          UserResolutionAction.reviewDiff,
        ],
        isInformationOnly: true,
        conflictingFields: conflict.conflictingFields,
        conflict: conflict,
        localValues: localValues,
        serverValues: serverValues,
        baseServerVersion: baseServerVersion ?? conflict.baseServerVersion,
        serverVersion: serverVersion ?? conflict.serverVersion,
        isServerDeleted: false,
      );
    }

    // 4. Standard User-Editable Entity Conflicts (Trips, Itineraries, Preferences)
    return ConflictPresentationModel(
      conflictId: conflict.conflictId,
      entityType: conflict.entityType,
      entityId: conflict.entityId,
      userMessage: 'This item changed while you were offline.',
      details: conflict.conflictingFields.isNotEmpty
          ? 'Differences detected in: ${conflict.conflictingFields.join(', ')}.'
          : 'Server version is newer than local base.',
      availableActions: const [
        UserResolutionAction.acceptServer,
        UserResolutionAction.keepLocal,
        UserResolutionAction.reviewDiff,
      ],
      isInformationOnly: false,
      conflictingFields: conflict.conflictingFields,
      conflict: conflict,
      localValues: localValues,
      serverValues: serverValues,
      baseServerVersion: baseServerVersion ?? conflict.baseServerVersion,
      serverVersion: serverVersion ?? conflict.serverVersion,
      isServerDeleted: false,
    );
  }

  /// Applies the user's resolution decision deterministically and idempotently.
  Future<void> applyResolution({
    required SyncConflict conflict,
    required UserResolutionAction action,
    required String userId,
    int? expectedServerVersion,
    RemoteEntitySnapshot? explicitServerSnapshot,
  }) async {
    // Assert user isolation
    if (conflict.userId != userId) {
      throw ArgumentError('Unauthorized: User $userId cannot resolve conflict for ${conflict.userId}.');
    }

    final policy = policyRegistry.getPolicy(conflict.entityType);

    // 1. Resolve authoritative server snapshot
    RemoteEntitySnapshot? serverSnapshot = explicitServerSnapshot;
    if (serverSnapshot == null && snapshotProvider != null) {
      serverSnapshot = await snapshotProvider!.fetchLatestSnapshot(
        entityType: conflict.entityType,
        entityId: conflict.entityId,
      );
    }

    // Fallback server version and data
    final serverVersion = serverSnapshot?.version ??
        conflict.serverVersion ??
        (conflict.baseServerVersion != null ? conflict.baseServerVersion! + 1 : 1);
    final isServerDeleted = serverSnapshot?.isDeleted ??
        (conflict.conflictType == ConflictType.updateVsDelete);
    final serverData = serverSnapshot?.data ??
        (conflict.sanitizedMetadata['server_state'] as Map<String, dynamic>? ?? const {});

    switch (action) {
      case UserResolutionAction.acceptServer:
        // ---------------------------------------------------------------------
        // ACCEPT SERVER FLOW (12.4.5.2)
        // ---------------------------------------------------------------------
        if (isServerDeleted) {
          // Server deleted entity: remove local entity safely without resurrection
          await _deleteLocalEntity(conflict.entityType, conflict.entityId);
        } else if (serverData.isNotEmpty) {
          // Replace only the conflicted local entity state with authoritative snapshot
          await _saveServerSnapshotLocally(
            entityType: conflict.entityType,
            entityId: conflict.entityId,
            userId: userId,
            serverVersion: serverVersion,
            serverData: serverData,
          );
        }

        // Clear obsolete local mutation from sync_queue (idempotent delete)
        await localDb.deleteSyncRecord(conflict.operationId);
        break;

      case UserResolutionAction.keepLocal:
        // ---------------------------------------------------------------------
        // KEEP MY CHANGES FLOW (12.4.5.3, 12.4.5.4, 12.4.5.7, 12.4.5.10)
        // ---------------------------------------------------------------------

        // 12.4.5.7 Stale UI Protection: revalidate current server version
        if (expectedServerVersion != null && serverVersion > expectedServerVersion) {
          throw StaleConflictVersionException(
            'Server version advanced from $expectedServerVersion to $serverVersion while reviewing conflict. Please refresh.',
            uiVersion: expectedServerVersion,
            serverVersion: serverVersion,
          );
        }

        // 12.4.5.10 Delete Safety: prevent resurrection of server-deleted entities
        if (isServerDeleted) {
          throw StateError(
            'Cannot keep local changes: Entity "${conflict.entityId}" was deleted on the server.',
          );
        }

        // 12.4.5.4 Keep-Mine Security Boundary: hard block on authoritative fields
        final hasAuthoritativeViolation = conflict.conflictingFields.any(
          (f) => policy.serverAuthoritativeFields.contains(f),
        );
        if (hasAuthoritativeViolation) {
          throw StateError(
            'Cannot apply local version: Contains server-authoritative protected fields.',
          );
        }

        // Fetch the existing queued mutation
        final oldRecord = await localDb.getSyncRecord(conflict.operationId);
        if (oldRecord == null) {
          // Idempotency check: mutation was already resolved or cleared
          return;
        }

        final localPayload = Map<String, dynamic>.from(oldRecord.payload);

        // Enforce server authority: strictly freeze server-authoritative fields to server state
        for (final authField in policy.serverAuthoritativeFields) {
          if (serverData.containsKey(authField)) {
            localPayload[authField] = serverData[authField];
          } else {
            localPayload.remove(authField);
          }
        }

        // Merge permitted local changes over server baseline
        final mergedPayload = Map<String, dynamic>.from(serverData);
        for (final entry in localPayload.entries) {
          if (!policy.serverAuthoritativeFields.contains(entry.key)) {
            mergedPayload[entry.key] = entry.value;
          }
        }

        // 12.4.5.3 Step 6 & 7: Assign NEW client_operation_id based on CURRENT server version
        final newOperationId = _uuid.v4();
        final newRecord = SyncRecord(
          operationId: newOperationId,
          userId: userId,
          entityType: conflict.entityType,
          entityId: conflict.entityId,
          action: conflict.localAction,
          payload: mergedPayload,
          status: 'pending',
          createdAt: DateTime.now(),
          baseServerVersion: serverVersion,
          localRevision: 1,
        );

        // 12.4.5.3 Step 9: Queue the new mutation
        await localDb.enqueueSyncRecord(newRecord);

        // Update local entity cache with new base version and merged edits
        await _saveLocalEntityMerged(
          entityType: conflict.entityType,
          entityId: conflict.entityId,
          userId: userId,
          baseServerVersion: serverVersion,
          mergedPayload: mergedPayload,
        );

        // 12.4.5.3 Step 10: Clear obsolete old conflicted mutation
        await localDb.deleteSyncRecord(conflict.operationId);
        break;

      case UserResolutionAction.reviewDiff:
        // Informational inspection only; no persistent mutation
        break;
    }
  }

  Future<void> _deleteLocalEntity(String entityType, String entityId) async {
    switch (entityType) {
      case 'trip':
        await localDb.deleteTrip(entityId);
        break;
      case 'profile':
        await localDb.deleteProfile(entityId);
        break;
      case 'itinerary':
        await localDb.deleteItinerary(entityId);
        break;
    }
  }

  Future<void> _saveServerSnapshotLocally({
    required String entityType,
    required String entityId,
    required String userId,
    required int serverVersion,
    required Map<String, dynamic> serverData,
  }) async {
    switch (entityType) {
      case 'trip':
        final existing = await localDb.getTrip(entityId);
        final updatedTrip = existing != null
            ? existing.copyWith(
                destination: serverData['destination'] as String? ?? existing.destination,
                origin: serverData['origin'] as String? ?? existing.origin,
                version: serverVersion,
              )
            : Trip.fromJson({...serverData, 'id': entityId, 'user_id': userId, 'version': serverVersion});
        await localDb.saveTrip(updatedTrip, baseServerVersion: serverVersion, localRevision: 0);
        break;

      case 'profile':
        final existing = await localDb.getProfile(entityId);
        final updatedProfile = existing != null
            ? existing.copyWith(
                displayName: serverData['display_name'] as String? ?? existing.displayName,
                bio: serverData['bio'] as String? ?? existing.bio,
                version: serverVersion,
              )
            : UserProfile.fromJson({...serverData, 'id': entityId, 'version': serverVersion});
        await localDb.saveProfile(updatedProfile, baseServerVersion: serverVersion, localRevision: 0);
        break;

      case 'itinerary':
        final existing = await localDb.getItinerary(entityId);
        final days = serverData['days'] != null ? jsonEncode(serverData['days']) : (existing?.daysJson ?? '[]');
        final updatedIt = LocalItineraryRecord(
          id: entityId,
          tripId: (serverData['trip_id'] ?? existing?.tripId ?? '') as String,
          userId: userId,
          title: (serverData['title'] ?? existing?.title ?? 'Itinerary') as String,
          daysJson: days,
          serverVersion: serverVersion,
          baseServerVersion: serverVersion,
          localRevision: 0,
          updatedAt: DateTime.now(),
        );
        await localDb.saveItinerary(updatedIt, baseServerVersion: serverVersion, localRevision: 0);
        break;
    }
  }

  Future<void> _saveLocalEntityMerged({
    required String entityType,
    required String entityId,
    required String userId,
    required int baseServerVersion,
    required Map<String, dynamic> mergedPayload,
  }) async {
    switch (entityType) {
      case 'trip':
        final existing = await localDb.getTrip(entityId);
        if (existing != null) {
          final updated = existing.copyWith(
            destination: mergedPayload['destination'] as String? ?? existing.destination,
            origin: mergedPayload['origin'] as String? ?? existing.origin,
            version: baseServerVersion,
          );
          await localDb.saveTrip(updated, baseServerVersion: baseServerVersion, localRevision: 1);
        }
        break;

      case 'profile':
        final existing = await localDb.getProfile(entityId);
        if (existing != null) {
          final updated = existing.copyWith(
            displayName: mergedPayload['display_name'] as String? ?? existing.displayName,
            bio: mergedPayload['bio'] as String? ?? existing.bio,
            version: baseServerVersion,
          );
          await localDb.saveProfile(updated, baseServerVersion: baseServerVersion, localRevision: 1);
        }
        break;

      case 'itinerary':
        final existing = await localDb.getItinerary(entityId);
        if (existing != null) {
          final days = mergedPayload['days'] != null
              ? jsonEncode(mergedPayload['days'])
              : existing.daysJson;
          final updatedIt = LocalItineraryRecord(
            id: existing.id,
            tripId: existing.tripId,
            userId: userId,
            title: mergedPayload['title'] as String? ?? existing.title,
            daysJson: days,
            serverVersion: baseServerVersion,
            baseServerVersion: baseServerVersion,
            localRevision: 1,
            updatedAt: DateTime.now(),
          );
          await localDb.saveItinerary(updatedIt, baseServerVersion: baseServerVersion, localRevision: 1);
        }
        break;
    }
  }
}

/// Riverpod Provider for the singleton LocalDatabaseService in sync contexts.
final localDatabaseServiceProvider = Provider<LocalDatabaseService>((ref) {
  return LocalDatabaseService();
});

/// Riverpod Provider for ConflictResolutionController.
final conflictResolutionControllerProvider = Provider<ConflictResolutionController>((ref) {
  final localDb = ref.watch(localDatabaseServiceProvider);
  return ConflictResolutionController(localDb: localDb);
});

/// Riverpod FutureProvider querying all unresolved conflicts for a specific traveler.
final pendingConflictsProvider = FutureProvider.family<List<ConflictPresentationModel>, String>((ref, userId) async {
  final controller = ref.watch(conflictResolutionControllerProvider);
  return controller.getPendingConflicts(userId);
});
