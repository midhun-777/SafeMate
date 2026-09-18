/// SafeMate Synchronization Domain Models & Classification Types.
/// Universal Engineering Rule #11: Deterministic sync models; Server authority wins.
/// Universal Engineering Rule #24: Bounded retry, error classification, and idempotency.
library;

/// High-level status of an individual sync queue operation.
enum SyncStatus {
  pending,
  syncing,
  synced,
  failed,
  conflict,
  cancelled,
}

/// Permitted mutation types for synchronization.
enum SyncOperationType {
  create,
  update,
  delete,
  saveDraft,
  deleteDraft,
  transitionStatus,
  sendMessage,
  recordCheckin;

  String get wireName {
    switch (this) {
      case SyncOperationType.create:
        return 'create';
      case SyncOperationType.update:
        return 'update';
      case SyncOperationType.delete:
        return 'delete';
      case SyncOperationType.saveDraft:
        return 'save_draft';
      case SyncOperationType.deleteDraft:
        return 'delete_draft';
      case SyncOperationType.transitionStatus:
        return 'transition_status';
      case SyncOperationType.sendMessage:
        return 'send_message';
      case SyncOperationType.recordCheckin:
        return 'record_checkin';
    }
  }

  static SyncOperationType fromString(String value) {
    switch (value) {
      case 'create':
        return SyncOperationType.create;
      case 'update':
        return SyncOperationType.update;
      case 'delete':
        return SyncOperationType.delete;
      case 'save_draft':
        return SyncOperationType.saveDraft;
      case 'delete_draft':
        return SyncOperationType.deleteDraft;
      case 'transition_status':
        return SyncOperationType.transitionStatus;
      case 'send_message':
        return SyncOperationType.sendMessage;
      case 'record_checkin':
        return SyncOperationType.recordCheckin;
      default:
        return SyncOperationType.update;
    }
  }
}

/// Approved entity types for synchronization.
enum SyncEntityType {
  trip,
  profile,
  tripPreferences,
  itinerary,
  chatMessage,
  safetripCheckin;

  String get wireName {
    switch (this) {
      case SyncEntityType.trip:
        return 'trip';
      case SyncEntityType.profile:
        return 'profile';
      case SyncEntityType.tripPreferences:
        return 'trip_preferences';
      case SyncEntityType.itinerary:
        return 'itinerary';
      case SyncEntityType.chatMessage:
        return 'chat';
      case SyncEntityType.safetripCheckin:
        return 'safetrip_checkin';
    }
  }

  static SyncEntityType fromString(String value) {
    switch (value) {
      case 'trip':
        return SyncEntityType.trip;
      case 'profile':
        return SyncEntityType.profile;
      case 'trip_preferences':
        return SyncEntityType.tripPreferences;
      case 'itinerary':
        return SyncEntityType.itinerary;
      case 'chat':
      case 'chat_message':
        return SyncEntityType.chatMessage;
      case 'safetrip_checkin':
        return SyncEntityType.safetripCheckin;
      default:
        return SyncEntityType.trip;
    }
  }
}

/// Classification of errors encountered during synchronization.
enum SyncErrorClassification {
  transient,
  permanent,
  authentication,
  authorization,
  validation,
  conflict,
  notFound,
  rateLimited;

  /// Helper to classify exceptions based on HTTP status code or message strings.
  static SyncErrorClassification classify(Object error) {
    final str = error.toString().toLowerCase();
    if (str.contains('401') || str.contains('unauthenticated') || str.contains('invalid session')) {
      return SyncErrorClassification.authentication;
    }
    if (str.contains('403') || str.contains('forbidden') || str.contains('row level security') || str.contains('rls')) {
      return SyncErrorClassification.authorization;
    }
    if (str.contains('409') || str.contains('conflict') || str.contains('version mismatch')) {
      return SyncErrorClassification.conflict;
    }
    if (str.contains('404') || str.contains('not found')) {
      return SyncErrorClassification.notFound;
    }
    if (str.contains('429') || str.contains('rate limit')) {
      return SyncErrorClassification.rateLimited;
    }
    if (str.contains('validation') || str.contains('invalid') || str.contains('malformed')) {
      return SyncErrorClassification.validation;
    }
    if (str.contains('socket') ||
        str.contains('network') ||
        str.contains('timeout') ||
        str.contains('connection refused') ||
        str.contains('handshake') ||
        str.contains('failed host lookup')) {
      return SyncErrorClassification.transient;
    }
    return SyncErrorClassification.permanent;
  }

  /// Whether an error of this classification is safe to retry automatically.
  bool get isRetryable {
    switch (this) {
      case SyncErrorClassification.transient:
      case SyncErrorClassification.rateLimited:
        return true;
      case SyncErrorClassification.permanent:
      case SyncErrorClassification.authentication:
      case SyncErrorClassification.authorization:
      case SyncErrorClassification.validation:
      case SyncErrorClassification.conflict:
      case SyncErrorClassification.notFound:
        return false;
    }
  }
}

/// Data freshness state for offline-first repositories.
enum DataFreshness {
  local,
  syncing,
  fresh,
  stale,
  offline,
  syncFailed,
}

/// Deterministic domain record representing a pending, in-flight, or failed sync mutation.
class SyncOperationRecord {
  final String operationId;
  final String userId;
  final String entityType;
  final String entityId;
  final String operationType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final int? baseVersion;
  final int? expectedVersion;
  final SyncStatus status;
  final String? lastError;
  final SyncErrorClassification? errorClassification;

  const SyncOperationRecord({
    required this.operationId,
    required this.userId,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.payload,
    required this.createdAt,
    this.attemptCount = 0,
    this.nextAttemptAt,
    this.baseVersion,
    this.expectedVersion,
    this.status = SyncStatus.pending,
    this.lastError,
    this.errorClassification,
  });

  SyncOperationRecord copyWith({
    String? operationId,
    String? userId,
    String? entityType,
    String? entityId,
    String? operationType,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    int? attemptCount,
    DateTime? nextAttemptAt,
    int? baseVersion,
    int? expectedVersion,
    SyncStatus? status,
    String? lastError,
    SyncErrorClassification? errorClassification,
  }) {
    return SyncOperationRecord(
      operationId: operationId ?? this.operationId,
      userId: userId ?? this.userId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operationType: operationType ?? this.operationType,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      baseVersion: baseVersion ?? this.baseVersion,
      expectedVersion: expectedVersion ?? this.expectedVersion,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
      errorClassification: errorClassification ?? this.errorClassification,
    );
  }
}
