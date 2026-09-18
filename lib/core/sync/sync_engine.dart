/// SafeMate Background Synchronization Engine.
/// Universal Engineering Rule #11: Server authority wins; deterministic conflict resolution.
/// Universal Engineering Rule #24: Explicit network recovery and bounded retry policies.
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/local_data_policy.dart';
import '../database/local_database_service.dart';
import '../network/connectivity_service.dart';
import 'sync_models.dart';

/// Current high-level operational status of the SyncEngine.
enum SyncEngineStatus {
  idle,
  syncing,
  offline,
  error,
  authRequired,
}

/// Handler signature for processing specific entity synchronizations with Supabase.
typedef SyncMutationHandler = Future<void> Function(SyncRecord record);

/// Core engine managing background synchronization, retry queues, and conflict mitigation.
class SyncEngine {
  final LocalDatabaseService localDb;
  final ConnectivityService? connectivity;
  final Map<String, SyncMutationHandler> _handlers = {};
  final StreamController<SyncEngineStatus> _statusController =
      StreamController<SyncEngineStatus>.broadcast();

  SyncEngineStatus _status = SyncEngineStatus.idle;
  bool _isSyncing = false;
  final _random = Random();
  final _uuid = const Uuid();
  StreamSubscription<ConnectivityStatus>? _connectivitySub;

  SyncEngine({
    required this.localDb,
    this.connectivity,
  }) {
    if (connectivity != null) {
      _connectivitySub = connectivity!.statusStream.listen((status) {
        if (status == ConnectivityStatus.offline) {
          _setStatus(SyncEngineStatus.offline);
          logSyncTelemetry(event: 'offline_mode_entered');
        } else if (status == ConnectivityStatus.online) {
          logSyncTelemetry(event: 'offline_mode_exited');
          if (_status == SyncEngineStatus.offline) {
            _setStatus(SyncEngineStatus.idle);
          }
        }
      });
    }
  }

  SyncEngineStatus get status => _status;
  Stream<SyncEngineStatus> get statusStream => _statusController.stream;
  bool get isSyncing => _isSyncing;

  /// Registers a remote mutation handler for an [entityType].
  void registerHandler(String entityType, SyncMutationHandler handler) {
    _handlers[entityType] = handler;
  }

  /// Generates an idempotent client operation identifier.
  String generateOperationId() => _uuid.v4();

  /// Sets current engine status and emits to stream.
  void _setStatus(SyncEngineStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
    }
  }

  /// Enqueues a local mutation to be synchronized upon connectivity.
  /// Validates payload against [LocalDataPolicy] before writing to SQLite.
  Future<String> enqueue({
    required String userId,
    required String entityType,
    required String entityId,
    required String action,
    required Map<String, dynamic> payload,
    String? operationId,
    int? baseServerVersion,
    int localRevision = 1,
  }) async {
    // Phase 12.2 Policy Enforcement: validate entity, operation, size & prohibited fields
    LocalDataPolicy.validateSyncPayload(entityType, action, payload);

    final opId = operationId ?? generateOperationId();
    final record = SyncRecord(
      operationId: opId,
      userId: userId,
      entityType: entityType,
      entityId: entityId,
      action: action,
      payload: payload,
      status: 'pending',
      createdAt: DateTime.now(),
      baseServerVersion: baseServerVersion,
      localRevision: localRevision,
    );

    await localDb.enqueueSyncRecord(record);
    logSyncTelemetry(
      event: 'operation_enqueued',
      operationId: opId,
      entityType: entityType,
    );
    return opId;
  }

  /// Processes all pending sync operations for [userId].
  /// Enforces single-flight locking, user session boundary, bounded exponential backoff,
  /// and error classification.
  Future<int> processPendingQueue(String userId, {bool? isOnline}) async {
    final online = isOnline ?? (connectivity?.isOnline ?? true);
    if (!online) {
      _setStatus(SyncEngineStatus.offline);
      return 0;
    }

    // 1. Single-Flight Lock: Prevent concurrent workers from processing the same queue
    if (_isSyncing) {
      debugPrint('[SafeMate SyncEngine] Sync worker already active. Skipping duplicate run.');
      return 0;
    }
    _isSyncing = true;
    _setStatus(SyncEngineStatus.syncing);
    logSyncTelemetry(event: 'sync_started');

    int processedCount = 0;

    try {
      final pendingRecords = await localDb.getPendingSyncRecords(userId);

      for (final record in pendingRecords) {
        // 2. User Isolation Boundary: Never process User A's queue for User B
        if (record.userId != userId) {
          logSyncTelemetry(
            event: 'cross_account_skip',
            operationId: record.operationId,
          );
          continue;
        }

        // 3. Max Retry Bound (5 attempts)
        if (record.retryCount >= 5) {
          await localDb.updateSyncRecordStatus(
            record.operationId,
            'failed',
            errorMessage: 'Exceeded maximum retry limit (5). Manual review required.',
          );
          logSyncTelemetry(
            event: 'sync_max_retries_exceeded',
            operationId: record.operationId,
          );
          continue;
        }

        // 4. Bounded Exponential Backoff with Jitter
        if (record.lastAttemptAt != null) {
          final backoffSeconds = min(pow(2, record.retryCount).toInt(), 60);
          final jitter = _random.nextInt(3);
          final cooldown = Duration(seconds: backoffSeconds + jitter);
          if (DateTime.now().difference(record.lastAttemptAt!) < cooldown) {
            // Still in cooldown period, skip for now
            continue;
          }
        }

        // 5. Lookup registered remote mutation handler
        final handler = _handlers[record.entityType];
        if (handler == null) {
          await localDb.updateSyncRecordStatus(
            record.operationId,
            'failed',
            errorMessage: 'No registered sync handler for entity "${record.entityType}".',
          );
          logSyncTelemetry(
            event: 'sync_handler_missing',
            operationId: record.operationId,
            entityType: record.entityType,
          );
          continue;
        }

        // 6. Transition to in-flight state
        await localDb.updateSyncRecordStatus(
          record.operationId,
          'syncing',
          lastAttemptAt: DateTime.now(),
        );

        try {
          // Execute mutation with server authority
          await handler(record);

          // Success: delete completed mutation from queue
          await localDb.deleteSyncRecord(record.operationId);
          processedCount++;
          logSyncTelemetry(
            event: 'operation_synced',
            operationId: record.operationId,
            entityType: record.entityType,
          );
        } catch (e) {
          final classification = SyncErrorClassification.classify(e);
          logSyncTelemetry(
            event: 'operation_error',
            operationId: record.operationId,
            entityType: record.entityType,
            errorClassification: classification.name,
          );

          switch (classification) {
            case SyncErrorClassification.conflict:
              await localDb.updateSyncRecordStatus(
                record.operationId,
                'conflict',
                errorMessage: 'State conflict: ${e.toString()}',
              );
              logSyncTelemetry(
                event: 'sync_conflict',
                operationId: record.operationId,
              );
              break;

            case SyncErrorClassification.authentication:
              await localDb.updateSyncRecordStatus(
                record.operationId,
                'failed',
                errorMessage: 'Authentication expired. Re-authentication required.',
              );
              _setStatus(SyncEngineStatus.authRequired);
              logSyncTelemetry(event: 'sync_auth_required');
              return processedCount; // Stop queue processing on auth failure

            case SyncErrorClassification.authorization:
            case SyncErrorClassification.validation:
            case SyncErrorClassification.notFound:
            case SyncErrorClassification.permanent:
              // Permanent/non-retryable errors are marked failed without retry loop
              await localDb.updateSyncRecordStatus(
                record.operationId,
                'failed',
                errorMessage: e.toString(),
              );
              logSyncTelemetry(
                event: 'sync_permanent_failure',
                operationId: record.operationId,
              );
              break;

            case SyncErrorClassification.transient:
            case SyncErrorClassification.rateLimited:
              // Retryable: increment retry count and back off
              final nextCount = record.retryCount + 1;
              await localDb.updateSyncRecordStatus(
                record.operationId,
                'failed',
                retryCount: nextCount,
                errorMessage: e.toString(),
              );
              logSyncTelemetry(
                event: 'sync_retry_scheduled',
                operationId: record.operationId,
              );
              break;
          }
        }
      }

      _setStatus(SyncEngineStatus.idle);
      logSyncTelemetry(event: 'sync_completed');
    } catch (e) {
      debugPrint('[SafeMate SyncEngine] Unexpected queue loop failure: $e');
      _setStatus(SyncEngineStatus.error);
      logSyncTelemetry(event: 'sync_failed');
    } finally {
      _isSyncing = false;
    }

    return processedCount;
  }

  /// Handles account switching cleanly per Universal Engineering Rule #10:
  /// Aborts in-flight operations, purges old state, and re-initializes engine for new session.
  Future<void> onAccountSwitched({
    required String oldUserId,
    required String newUserId,
  }) async {
    _isSyncing = false;
    _setStatus(SyncEngineStatus.idle);
    await localDb.clearUserScopedData(oldUserId);
    logSyncTelemetry(
      event: 'account_switch_purged',
      oldUserId: oldUserId,
      newUserId: newUserId,
    );
  }

  /// Privacy-safe telemetry logging: Omits PII, credentials, payloads, and raw coordinates.
  static void logSyncTelemetry({
    required String event,
    String? operationId,
    String? entityType,
    String? errorClassification,
    String? oldUserId,
    String? newUserId,
  }) {
    debugPrint(
      '[SafeMate SyncTelemetry] event=$event'
      '${operationId != null ? ', opId=$operationId' : ''}'
      '${entityType != null ? ', entity=$entityType' : ''}'
      '${errorClassification != null ? ', errorType=$errorClassification' : ''}'
      '${oldUserId != null ? ', oldUser=$oldUserId' : ''}'
      '${newUserId != null ? ', newUser=$newUserId' : ''}'
      ', timestamp=${DateTime.now().toIso8601String()}',
    );
  }

  /// Cleanly disposes engine streams and subscriptions.
  void dispose() {
    _connectivitySub?.cancel();
    _statusController.close();
  }
}
