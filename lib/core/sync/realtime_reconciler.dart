/// SafeMate Realtime Concurrency Reconciler.
/// Universal Engineering Rule #7: Server authority bounds all client state.
/// Universal Engineering Rule #11: Deterministic state machine transitions.
/// Universal Engineering Rule #18: Server is authoritative; no device wall-clock LWW.
library;

import 'dart:convert';
import '../database/local_database_service.dart';
import '../database/database_models.dart';
import 'conflict_models.dart';
import 'deterministic_conflict_detector.dart';
import 'deterministic_reconciler.dart';

/// Action taken by the realtime ingestion pipeline based on server version comparisons.
enum RealtimeAction {
  /// Incoming version is strictly older than current local server version; drop event.
  ignore,

  /// Incoming version matches current local server version; deduplicate without write.
  deduplicate,

  /// Incoming version is strictly newer; reconcile cleanly with local state.
  reconcile,

  /// Incoming event indicates server-side deletion; drop local record without resurrection.
  delete;
}

/// Result of evaluating an incoming realtime event against local entity state.
class RealtimeIngestResult {
  final RealtimeAction action;
  final String reason;
  final int? localVersion;
  final int serverVersion;
  final Map<String, dynamic>? appliedState;
  final SyncConflict? conflict;

  const RealtimeIngestResult({
    required this.action,
    required this.reason,
    this.localVersion,
    required this.serverVersion,
    this.appliedState,
    this.conflict,
  });
}

/// Coordinates realtime event ingestion with deterministic version comparison and delete safety.
class RealtimeReconciler {
  final LocalDatabaseService localDb;
  final DeterministicReconciler reconciler;

  RealtimeReconciler({
    required this.localDb,
    DeterministicReconciler? reconciler,
  }) : reconciler = reconciler ?? DeterministicReconciler.instance;

  /// Ingests an incoming realtime change event for an entity.
  /// Enforces:
  /// - Older version: IGNORE
  /// - Same version: DEDUPLICATE
  /// - Newer version: RECONCILE (or DELETE if isDeleted == true)
  /// - Delete safety: Never resurrect deleted entities from stale updates
  Future<RealtimeIngestResult> ingestServerEvent({
    required String entityType,
    required String entityId,
    required String userId,
    required int serverVersion,
    Map<String, dynamic>? serverPayload,
    bool isDeleted = false,
  }) async {
    // 1. Fetch current local entity state and version
    final localData = await _fetchLocalEntity(entityType, entityId);
    final localVersion = localData != null ? (localData['server_version'] as int? ?? 1) : null;

    // 2. Handle Server Deletion Event
    if (isDeleted) {
      if (localData == null) {
        return RealtimeIngestResult(
          action: RealtimeAction.deduplicate,
          reason: 'Entity $entityId already absent locally; deletion deduplicated.',
          localVersion: null,
          serverVersion: serverVersion,
        );
      }

      if (localVersion != null && serverVersion < localVersion) {
        return RealtimeIngestResult(
          action: RealtimeAction.ignore,
          reason: 'Stale delete event ($serverVersion < local $localVersion) ignored.',
          localVersion: localVersion,
          serverVersion: serverVersion,
        );
      }

      // Authoritative delete
      await _deleteLocalEntity(entityType, entityId);
      return RealtimeIngestResult(
        action: RealtimeAction.delete,
        reason: 'Entity $entityId deleted by authoritative server event ($serverVersion).',
        localVersion: localVersion,
        serverVersion: serverVersion,
      );
    }

    // 3. Entity exists locally: compare server versions
    if (localData != null && localVersion != null) {
      if (serverVersion < localVersion) {
        // STALE EVENT: Ignore
        return RealtimeIngestResult(
          action: RealtimeAction.ignore,
          reason: 'Stale server event ($serverVersion < local $localVersion) ignored.',
          localVersion: localVersion,
          serverVersion: serverVersion,
        );
      }

      if (serverVersion == localVersion) {
        // DUPLICATE EVENT: Deduplicate
        return RealtimeIngestResult(
          action: RealtimeAction.deduplicate,
          reason: 'Duplicate server event ($serverVersion == local $localVersion) deduplicated.',
          localVersion: localVersion,
          serverVersion: serverVersion,
        );
      }
    }

    // 4. Server version is newer: Check for pending uncommitted local mutations
    final pendingRecords = await localDb.getPendingSyncRecords(userId);
    final entityPending = pendingRecords.where((r) => r.entityId == entityId).toList();

    if (entityPending.isEmpty) {
      // Clean fast-forward: update local entity to new server snapshot
      if (serverPayload != null) {
        await _applyServerSnapshotLocally(
          entityType: entityType,
          entityId: entityId,
          userId: userId,
          serverVersion: serverVersion,
          serverPayload: serverPayload,
        );
      }
      return RealtimeIngestResult(
        action: RealtimeAction.reconcile,
        reason: 'Clean fast-forward to server version $serverVersion.',
        localVersion: localVersion,
        serverVersion: serverVersion,
        appliedState: serverPayload,
      );
    }

    // 5. Concurrency Collision: Local edits exist on top of older base version
    final activeRecord = entityPending.first;
    final baseVersion = activeRecord.baseServerVersion ?? localVersion ?? (serverVersion - 1);

    final detection = DeterministicConflictDetector.detectConflict(
      ConflictDetectionInput(
        userId: userId,
        entityType: entityType,
        entityId: entityId,
        operation: EntityOperation.fromString(activeRecord.action),
        localBaseVersion: baseVersion,
        localRevision: activeRecord.localRevision,
        serverVersion: serverVersion,
        baseState: localData,
        localState: activeRecord.payload,
        serverState: serverPayload,
        operationId: activeRecord.operationId,
        localTimestamp: activeRecord.createdAt,
      ),
    );

    if (!detection.hasConflict) {
      // Auto-reconcile without collision
      if (serverPayload != null) {
        await _applyServerSnapshotLocally(
          entityType: entityType,
          entityId: entityId,
          userId: userId,
          serverVersion: serverVersion,
          serverPayload: serverPayload,
        );
      }
      return RealtimeIngestResult(
        action: RealtimeAction.reconcile,
        reason: 'No overlapping field conflicts; state auto-reconciled.',
        localVersion: localVersion,
        serverVersion: serverVersion,
        appliedState: serverPayload,
      );
    }

    // Conflicting: mark queue item as conflict
    await localDb.updateSyncRecordStatus(
      activeRecord.operationId,
      'conflict',
      errorMessage: 'Realtime conflict: server advanced to version $serverVersion.',
    );

    final conflictingFields = detection.threeWayComparison?.conflictingFields ?? const [];

    final conflict = SyncConflict(
      conflictId: 'conf_${activeRecord.operationId}',
      operationId: activeRecord.operationId,
      userId: userId,
      entityType: entityType,
      entityId: entityId,
      conflictType: detection.conflictType ?? ConflictType.concurrentUpdate,
      localAction: activeRecord.action,
      localTimestamp: activeRecord.createdAt,
      detectedAt: DateTime.now(),
      baseServerVersion: baseVersion,
      serverVersion: serverVersion,
      localRevision: activeRecord.localRevision,
      conflictingFields: conflictingFields,
    );

    return RealtimeIngestResult(
      action: RealtimeAction.reconcile,
      reason: 'Concurrent divergence detected; conflict flagged for user resolution.',
      localVersion: localVersion,
      serverVersion: serverVersion,
      conflict: conflict,
    );
  }

  Future<Map<String, dynamic>?> _fetchLocalEntity(String entityType, String entityId) async {
    switch (entityType) {
      case 'trip':
        final trip = await localDb.getTrip(entityId);
        if (trip == null) return null;
        final json = trip.toJson();
        json['server_version'] = trip.version;
        return json;

      case 'profile':
        final profile = await localDb.getProfile(entityId);
        if (profile == null) return null;
        final json = profile.toJson();
        json['server_version'] = profile.version;
        return json;

      case 'itinerary':
        final it = await localDb.getItinerary(entityId);
        if (it == null) return null;
        return {
          'id': it.id,
          'trip_id': it.tripId,
          'title': it.title,
          'days': jsonDecode(it.daysJson),
          'server_version': it.serverVersion,
        };

      default:
        return null;
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

  Future<void> _applyServerSnapshotLocally({
    required String entityType,
    required String entityId,
    required String userId,
    required int serverVersion,
    required Map<String, dynamic> serverPayload,
  }) async {
    final payloadWithVersion = Map<String, dynamic>.from(serverPayload);
    payloadWithVersion['version'] = serverVersion;

    switch (entityType) {
      case 'trip':
        final trip = await localDb.getTrip(entityId);
        if (trip != null) {
          final updated = trip.copyWith(
            destination: serverPayload['destination'] as String? ?? trip.destination,
            origin: serverPayload['origin'] as String? ?? trip.origin,
            version: serverVersion,
          );
          await localDb.saveTrip(updated, baseServerVersion: serverVersion, localRevision: 0);
        }
        break;

      case 'profile':
        final profile = await localDb.getProfile(userId);
        if (profile != null) {
          final updated = profile.copyWith(
            displayName: serverPayload['display_name'] as String? ?? profile.displayName,
            bio: serverPayload['bio'] as String? ?? profile.bio,
            version: serverVersion,
          );
          await localDb.saveProfile(updated, baseServerVersion: serverVersion, localRevision: 0);
        }
        break;

      case 'itinerary':
        final it = await localDb.getItinerary(entityId);
        if (it != null) {
          final updated = LocalItineraryRecord(
            id: it.id,
            tripId: it.tripId,
            userId: it.userId,
            title: serverPayload['title'] as String? ?? it.title,
            daysJson: serverPayload['days'] != null ? jsonEncode(serverPayload['days']) : it.daysJson,
            serverVersion: serverVersion,
            baseServerVersion: serverVersion,
            localRevision: 0,
            updatedAt: DateTime.now(),
          );
          await localDb.saveItinerary(updated, baseServerVersion: serverVersion, localRevision: 0);
        }
        break;
    }
  }
}
