/// SafeMate Offline-First Trip Repository.
/// Universal Engineering Rule #11: Immediate local response + background eventual consistency.
/// Universal Engineering Rule #18: Server is authoritative on conflict.
library;

import 'package:flutter/foundation.dart';
import '../../../../core/database/local_database_service.dart';
import '../../../../core/sync/conflict_resolution_policy.dart';
import '../../../../core/sync/deterministic_conflict_detector.dart';
import '../../../../core/sync/deterministic_reconciler.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_preferences.dart';
import '../../domain/models/trip_status.dart';
import '../../domain/repositories/trip_repository.dart';

class OfflineFirstTripRepository implements TripRepository {
  final TripRepository _remoteRepo;
  final LocalDatabaseService _localDb;
  final SyncEngine? _syncEngine;

  OfflineFirstTripRepository({
    required TripRepository remoteRepo,
    required LocalDatabaseService localDb,
    SyncEngine? syncEngine,
  })  : _remoteRepo = remoteRepo, // ignore: prefer_initializing_formals
        _localDb = localDb, // ignore: prefer_initializing_formals
        _syncEngine = syncEngine { // ignore: prefer_initializing_formals
    // Register trip mutation handler with SyncEngine
    _syncEngine?.registerHandler('trip', _handleSyncMutation);
  }

  /// Dispatches remote mutations queued by the SyncEngine.
  Future<void> _handleSyncMutation(SyncRecord record) async {
    switch (record.action) {
      case 'create':
        final trip = Trip.fromJson(record.payload);
        final confirmed = await _remoteRepo.createTrip(trip);
        if (trip.id != confirmed.id) {
          await _localDb.deleteTrip(trip.id);
        }
        await _localDb.saveTrip(confirmed);
        break;

      case 'save_draft':
        final draft = Trip.fromJson(record.payload);
        final confirmed = await _remoteRepo.saveDraft(draft);
        await _localDb.saveTrip(confirmed);
        break;

      case 'update':
        final trip = Trip.fromJson(record.payload);
        // Conflict detection: verify remote version and existence via pure detector
        final remoteExisting = await _remoteRepo.getTrip(trip.id);
        if (remoteExisting == null) {
          throw StateError(
            'Trip conflict (updateVsDelete): Server record for trip ${trip.id} was deleted remotely.',
          );
        }

        final existingLocal = await _localDb.getTrip(trip.id);
        final baseVersion = record.baseServerVersion ?? trip.version;
        final detectionResult = DeterministicConflictDetector.detectConflict(
          ConflictDetectionInput(
            userId: record.userId,
            entityType: 'trip',
            entityId: trip.id,
            operation: EntityOperation.update,
            localBaseVersion: baseVersion,
            localRevision: record.localRevision,
            serverVersion: remoteExisting.version,
            baseState: existingLocal?.toJson(),
            localState: trip.toJson(),
            serverState: remoteExisting.toJson(),
            localTimestamp: trip.updatedAt,
            serverTimestamp: remoteExisting.updatedAt,
            operationId: record.operationId,
          ),
        );

        if (detectionResult.hasConflict) {
          // Attempt deterministic 3-way reconciliation
          final reconciliation = DeterministicReconciler.instance.reconcile(
            entityType: 'trip',
            entityId: trip.id,
            userId: record.userId,
            baseVersion: baseVersion,
            serverVersion: remoteExisting.version,
            baseState: existingLocal?.toJson(),
            localState: trip.toJson(),
            serverState: remoteExisting.toJson(),
          );

          if (reconciliation.outcome == ReconciliationOutcome.merged &&
              reconciliation.mergedPayload != null) {
            final mergedTrip = Trip.fromJson(reconciliation.mergedPayload!);
            final confirmed = await _remoteRepo.updateTrip(mergedTrip);
            await _localDb.saveTrip(confirmed);
            break;
          }

          throw StateError(
            'Trip conflict (${detectionResult.conflictType?.name}): ${detectionResult.reason}',
          );
        }

        final confirmed = await _remoteRepo.updateTrip(trip);
        await _localDb.saveTrip(confirmed);
        break;

      case 'transition_status':
        final newStatus = TripStatus.fromString(record.payload['status'] as String);
        final reason = record.payload['reason'] as String?;
        final confirmed = await _remoteRepo.transitionTripStatus(
          tripId: record.entityId,
          userId: record.userId,
          newStatus: newStatus,
          reason: reason,
        );
        await _localDb.saveTrip(confirmed);
        break;

      case 'delete_draft':
        await _remoteRepo.deleteDraftTrip(
          tripId: record.entityId,
          userId: record.userId,
        );
        await _localDb.deleteTrip(record.entityId);
        break;

      default:
        debugPrint('[SafeMate OfflineTripRepo] Unrecognized trip sync action: ${record.action}');
    }
  }

  @override
  Future<Trip> createTrip(Trip trip, {TripPreferences? preferences}) async {
    // 1. Save to local SQLite cache first for instantaneous UX
    final localTrip = trip.id.isEmpty
        ? trip.copyWith(id: 'local_${DateTime.now().millisecondsSinceEpoch}')
        : trip;
    await _localDb.saveTrip(localTrip);

    // 2. Attempt remote sync or enqueue
    try {
      final remoteTrip = await _remoteRepo.createTrip(localTrip, preferences: preferences);
      // Replace local placeholder with authoritative server record
      if (localTrip.id != remoteTrip.id) {
        await _localDb.deleteTrip(localTrip.id);
      }
      await _localDb.saveTrip(remoteTrip);
      return remoteTrip;
    } catch (e) {
      debugPrint('[SafeMate OfflineTripRepo] Remote creation failed; enqueued for sync: $e');
      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          userId: localTrip.userId,
          entityType: 'trip',
          entityId: localTrip.id,
          action: 'create',
          payload: localTrip.toJson(),
        );
      }
      return localTrip;
    }
  }

  @override
  Future<Trip> saveDraft(Trip trip, {TripPreferences? preferences}) async {
    final draftTrip = trip.copyWith(status: TripStatus.draft, updatedAt: DateTime.now());
    await _localDb.saveTrip(draftTrip);

    try {
      final remoteDraft = await _remoteRepo.saveDraft(draftTrip, preferences: preferences);
      await _localDb.saveTrip(remoteDraft);
      return remoteDraft;
    } catch (e) {
      debugPrint('[SafeMate OfflineTripRepo] Remote draft save failed; saved locally: $e');
      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          userId: draftTrip.userId,
          entityType: 'trip',
          entityId: draftTrip.id,
          action: 'save_draft',
          payload: draftTrip.toJson(),
        );
      }
      return draftTrip;
    }
  }

  @override
  Future<Trip> updateTrip(Trip trip, {TripPreferences? preferences}) async {
    // Check local divergence before saving
    final existingLocal = await _localDb.getTrip(trip.id);
    if (existingLocal != null && existingLocal.updatedAt.isAfter(trip.updatedAt)) {
      debugPrint('[SafeMate OfflineTripRepo] Warning: Local trip has newer timestamp than update base.');
    }

    final updatedLocal = trip.copyWith(updatedAt: DateTime.now());
    await _localDb.saveTrip(updatedLocal);

    try {
      final remote = await _remoteRepo.updateTrip(updatedLocal, preferences: preferences);
      await _localDb.saveTrip(remote);
      return remote;
    } catch (e) {
      debugPrint('[SafeMate OfflineTripRepo] Remote update failed; enqueued for sync: $e');
      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          userId: updatedLocal.userId,
          entityType: 'trip',
          entityId: updatedLocal.id,
          action: 'update',
          payload: updatedLocal.toJson(),
        );
      }
      return updatedLocal;
    }
  }

  @override
  Future<Trip?> getTrip(String tripId) async {
    // 1. Check local cache first (instantaneous response)
    final cached = await _localDb.getTrip(tripId);

    // 2. Attempt remote fetch
    try {
      final remote = await _remoteRepo.getTrip(tripId);
      if (remote != null) {
        await _localDb.saveTrip(remote);
        return remote;
      }
    } catch (_) {
      // Return cached record on network error
    }
    return cached;
  }

  @override
  Future<List<Trip>> getUserTrips(String userId) async {
    // 1. Read local cached trips immediately
    final localTrips = await _localDb.getUserTrips(userId);

    // 2. Refresh from remote if reachable
    try {
      final remoteTrips = await _remoteRepo.getUserTrips(userId);
      for (final trip in remoteTrips) {
        await _localDb.saveTrip(trip);
      }
      final updatedLocal = await _localDb.getUserTrips(userId);
      return updatedLocal.isNotEmpty ? updatedLocal : remoteTrips;
    } catch (_) {
      // Offline fallback: return local records
      return localTrips;
    }
  }

  @override
  Future<Trip> transitionTripStatus({
    required String tripId,
    required String userId,
    required TripStatus newStatus,
    String? reason,
  }) async {
    final cached = await _localDb.getTrip(tripId);
    if (cached != null) {
      final updated = cached.copyWith(status: newStatus, updatedAt: DateTime.now());
      await _localDb.saveTrip(updated);
    }

    try {
      final remote = await _remoteRepo.transitionTripStatus(
        tripId: tripId,
        userId: userId,
        newStatus: newStatus,
        reason: reason,
      );
      await _localDb.saveTrip(remote);
      return remote;
    } catch (e) {
      debugPrint('[SafeMate OfflineTripRepo] Remote status transition failed; enqueued for sync: $e');
      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          userId: userId,
          entityType: 'trip',
          entityId: tripId,
          action: 'transition_status',
          payload: {'status': newStatus.name, 'reason': reason},
        );
      }
      if (cached != null) return cached.copyWith(status: newStatus);
      rethrow;
    }
  }

  @override
  Future<void> deleteDraftTrip({
    required String tripId,
    required String userId,
  }) async {
    // Safe delete intent: delete locally
    await _localDb.deleteTrip(tripId);
    try {
      await _remoteRepo.deleteDraftTrip(tripId: tripId, userId: userId);
    } catch (e) {
      debugPrint('[SafeMate OfflineTripRepo] Remote delete draft failed; enqueued delete intent: $e');
      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          userId: userId,
          entityType: 'trip',
          entityId: tripId,
          action: 'delete_draft',
          payload: {'id': tripId},
        );
      }
    }
  }
}
