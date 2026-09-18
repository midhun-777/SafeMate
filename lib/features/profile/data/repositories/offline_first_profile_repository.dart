/// SafeMate Offline-First Profile Repository.
/// Universal Engineering Rule #7: Client only accesses permitted rows.
/// Universal Engineering Rule #18: Verification and trust decisions are strictly server-authoritative.
library;

import 'package:flutter/foundation.dart';
import '../../../../core/database/local_database_service.dart';
import '../../../../core/sync/conflict_resolution_policy.dart';
import '../../../../core/sync/deterministic_conflict_detector.dart';
import '../../../../core/sync/deterministic_reconciler.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../auth/domain/models/user_profile.dart';
import '../../domain/models/travel_preferences.dart';
import '../../domain/repositories/profile_repository.dart';

class OfflineFirstProfileRepository implements ProfileRepository {
  final ProfileRepository _remoteRepo;
  final LocalDatabaseService _localDb;
  final SyncEngine? _syncEngine;

  OfflineFirstProfileRepository({
    required ProfileRepository remoteRepo,
    required LocalDatabaseService localDb,
    SyncEngine? syncEngine,
  })  : _remoteRepo = remoteRepo, // ignore: prefer_initializing_formals
        _localDb = localDb, // ignore: prefer_initializing_formals
        _syncEngine = syncEngine { // ignore: prefer_initializing_formals
    _syncEngine?.registerHandler('profile', _handleSyncMutation);
  }

  Future<void> _handleSyncMutation(SyncRecord record) async {
    if (record.action == 'update') {
      final json = record.payload;
      final profile = UserProfile.fromJson(json);

      final remoteExisting = await _remoteRepo.getProfile(profile.id);
      if (remoteExisting != null) {
        final existingLocal = await _localDb.getProfile(profile.id);
        final baseVersion = record.baseServerVersion ?? profile.version;

        final detectionResult = DeterministicConflictDetector.detectConflict(
          ConflictDetectionInput(
            userId: record.userId,
            entityType: 'profile',
            entityId: profile.id,
            operation: EntityOperation.update,
            localBaseVersion: baseVersion,
            localRevision: record.localRevision,
            serverVersion: remoteExisting.version,
            baseState: existingLocal != null
                ? {
                    'display_name': existingLocal.displayName,
                    'bio': existingLocal.bio,
                    'trust_score': existingLocal.trustScore,
                    'is_verified': existingLocal.isVerified,
                  }
                : null,
            localState: {
              'display_name': profile.displayName,
              'bio': profile.bio,
              'trust_score': profile.trustScore,
              'is_verified': profile.isVerified,
            },
            serverState: {
              'display_name': remoteExisting.displayName,
              'bio': remoteExisting.bio,
              'trust_score': remoteExisting.trustScore,
              'is_verified': remoteExisting.isVerified,
            },
            localTimestamp: profile.updatedAt,
            serverTimestamp: remoteExisting.updatedAt,
            operationId: record.operationId,
          ),
        );

        if (detectionResult.hasConflict) {
          // Attempt deterministic 3-way reconciliation
          final reconciliation = DeterministicReconciler.instance.reconcile(
            entityType: 'profile',
            entityId: profile.id,
            userId: record.userId,
            baseVersion: baseVersion,
            serverVersion: remoteExisting.version,
            baseState: existingLocal != null
                ? {
                    'display_name': existingLocal.displayName,
                    'bio': existingLocal.bio,
                    'trust_score': existingLocal.trustScore,
                    'is_verified': existingLocal.isVerified,
                  }
                : null,
            localState: {
              'display_name': profile.displayName,
              'bio': profile.bio,
              'trust_score': profile.trustScore,
              'is_verified': profile.isVerified,
            },
            serverState: {
              'display_name': remoteExisting.displayName,
              'bio': remoteExisting.bio,
              'trust_score': remoteExisting.trustScore,
              'is_verified': remoteExisting.isVerified,
            },
          );

          if (reconciliation.outcome == ReconciliationOutcome.merged &&
              reconciliation.mergedPayload != null) {
            final mergedProfile = profile.copyWith(
              displayName: reconciliation.mergedPayload!['display_name'] as String?,
              bio: reconciliation.mergedPayload!['bio'] as String?,
              // Unconditionally keep authoritative server values
              trustScore: remoteExisting.trustScore,
              isVerified: remoteExisting.isVerified,
            );
            final confirmed = await _remoteRepo.saveProfile(mergedProfile);
            await _localDb.saveProfile(confirmed);
            return;
          }

          throw StateError(
            'Profile conflict (${detectionResult.conflictType?.name}): ${detectionResult.reason}',
          );
        }
      }

      final confirmed = await _remoteRepo.saveProfile(profile);
      await _localDb.saveProfile(confirmed);
    }
  }

  @override
  Future<UserProfile?> getProfile(String userId) async {
    // 1. Instant local read
    final cached = await _localDb.getProfile(userId);

    // 2. Refresh from server if reachable
    try {
      final remote = await _remoteRepo.getProfile(userId);
      if (remote != null) {
        if (cached != null &&
            remote.displayName == 'Traveler' &&
            cached.displayName != 'Traveler') {
          return cached;
        }
        await _localDb.saveProfile(remote);
        return remote;
      }
    } catch (_) {
      // Offline fallback: return cached record
    }
    return cached;
  }

  @override
  Future<UserProfile> saveProfile(UserProfile profile) async {
    // Universal Rule #18: Server is strictly authoritative for verification flags
    final existingLocal = await _localDb.getProfile(profile.id);
    final sanitizedProfile = profile.copyWith(
      // Prevent local client from altering verified state
      isVerified: existingLocal?.isVerified ?? false,
      updatedAt: DateTime.now(),
    );

    // 1. Save locally for instantaneous UI feedback
    await _localDb.saveProfile(sanitizedProfile);

    // 2. Attempt remote save or enqueue
    try {
      final remote = await _remoteRepo.saveProfile(sanitizedProfile);
      await _localDb.saveProfile(remote);
      return remote;
    } catch (e) {
      debugPrint('[SafeMate OfflineProfileRepo] Remote profile save failed; enqueued: $e');
      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          userId: sanitizedProfile.id,
          entityType: 'profile',
          entityId: sanitizedProfile.id,
          action: 'update',
          payload: sanitizedProfile.toJson(),
        );
      }
      return sanitizedProfile;
    }
  }

  @override
  Future<TravelPreferences?> getTravelPreferences(String userId) async {
    // Travel preferences can be fetched from remote with fallback to defaults
    try {
      return await _remoteRepo.getTravelPreferences(userId);
    } catch (_) {
      return TravelPreferences.empty(userId);
    }
  }

  @override
  Future<TravelPreferences> saveTravelPreferences(TravelPreferences preferences) async {
    return _remoteRepo.saveTravelPreferences(preferences);
  }

  @override
  Future<String> uploadProfilePhoto({
    required String userId,
    required List<int> bytes,
    required String filename,
  }) async {
    // Photo binary uploads require live network connectivity (cannot store raw bytes in SQLite)
    return _remoteRepo.uploadProfilePhoto(
      userId: userId,
      bytes: bytes,
      filename: filename,
    );
  }

  @override
  Future<void> deleteProfilePhoto(String userId) async {
    return _remoteRepo.deleteProfilePhoto(userId);
  }
}
