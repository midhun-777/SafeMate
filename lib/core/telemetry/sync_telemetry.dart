/// SafeMate Privacy-Preserving Sync & Offline Telemetry Service.
/// Universal Engineering Rule #6: Never expose PII, credentials, raw GPS, or secret tokens.
/// Universal Engineering Rule #24: Coarse, bounded, opaque production observability.
library;

import 'dart:collection';

/// Pre-approved privacy-safe telemetry event names.
enum SyncTelemetryEvent {
  syncStarted('sync_started'),
  syncCompleted('sync_completed'),
  syncFailed('sync_failed'),
  syncConflict('sync_conflict'),
  syncRetry('sync_retry'),
  authRequired('auth_required'),
  realtimeConnected('realtime_connected'),
  realtimeDisconnected('realtime_disconnected'),
  databaseError('database_error');

  final String eventName;
  const SyncTelemetryEvent(this.eventName);
}

/// Coarse bucket for queue depth.
String bucketQueueDepth(int count) {
  if (count <= 0) return '0';
  if (count <= 5) return '1-5';
  if (count <= 20) return '6-20';
  if (count <= 50) return '21-50';
  return '50+';
}

/// Coarse bucket for offline or execution duration.
String bucketDuration(Duration duration) {
  final ms = duration.inMilliseconds;
  if (ms < 1000) return '<1s';
  if (ms < 5000) return '1-5s';
  if (ms < 30000) return '5-30s';
  if (ms < 300000) return '30s-5m';
  return '5m+';
}

/// Structured, scrubbed telemetry record.
class TelemetryRecord {
  final String eventName;
  final DateTime timestamp;
  final Map<String, Object> attributes;

  const TelemetryRecord({
    required this.eventName,
    required this.timestamp,
    required this.attributes,
  });

  Map<String, dynamic> toJson() => {
        'event': eventName,
        'timestamp': timestamp.toIso8601String(),
        'attributes': attributes,
      };

  @override
  String toString() => 'TelemetryRecord($eventName, $attributes)';
}

/// Singleton/Injectable privacy-safe sync telemetry service.
class SyncTelemetryService {
  static final SyncTelemetryService instance = SyncTelemetryService._();
  SyncTelemetryService._();

  factory SyncTelemetryService() => instance;

  final List<TelemetryRecord> _records = [];
  UnmodifiableListView<TelemetryRecord> get records => UnmodifiableListView(_records);

  /// Denied key substrings (Category C / PII / Secrets).
  static const Set<String> _forbiddenKeys = {
    'password',
    'token',
    'auth',
    'bearer',
    'aadhaar',
    'national_id',
    'passport',
    'latitude',
    'longitude',
    'raw_gps',
    'gps',
    'chat',
    'message',
    'body',
    'content',
    'notes',
    'emergency_secrets',
  };

  /// Record a privacy-safe telemetry event.
  /// Any forbidden sensitive keys are strictly scrubbed before recording.
  void recordEvent(
    SyncTelemetryEvent event, {
    Map<String, Object>? attributes,
  }) {
    final sanitized = <String, Object>{};

    if (attributes != null) {
      for (final entry in attributes.entries) {
        final keyLower = entry.key.toLowerCase();
        final isForbidden = _forbiddenKeys.any((forbidden) => keyLower.contains(forbidden));

        if (!isForbidden) {
          sanitized[entry.key] = entry.value;
        }
      }
    }

    final record = TelemetryRecord(
      eventName: event.eventName,
      timestamp: DateTime.now().toUtc(),
      attributes: sanitized,
    );

    _records.add(record);
    if (_records.length > 500) {
      _records.removeAt(0);
    }
  }

  /// Convenience method to record sync completion with coarse duration and queue count.
  void recordSyncCompleted({
    required Duration duration,
    required int itemsProcessed,
    required String entityType,
  }) {
    recordEvent(
      SyncTelemetryEvent.syncCompleted,
      attributes: {
        'duration_bucket': bucketDuration(duration),
        'items_processed_bucket': bucketQueueDepth(itemsProcessed),
        'entity_type': entityType,
      },
    );
  }

  /// Convenience method to record a sync retry.
  void recordSyncRetry({
    required int attemptCount,
    required String errorCategory,
    required String entityType,
  }) {
    recordEvent(
      SyncTelemetryEvent.syncRetry,
      attributes: {
        'attempt_count': attemptCount,
        'error_category': errorCategory,
        'entity_type': entityType,
      },
    );
  }

  /// Clear in-memory records (useful for test isolation).
  void clear() {
    _records.clear();
  }
}
