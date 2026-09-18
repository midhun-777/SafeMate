/// SafeMate Sync Error Taxonomy and User Message Formatter.
/// Universal Engineering Rule #6: Clear, actionable, privacy-safe traveler messages without leaking system internals.
/// Universal Engineering Rule #11: Offline state is never treated as confirmed server state.
library;

import 'sync_models.dart';

/// Formatter that maps internal sync and network failures into clear,
/// privacy-safe, traveler-friendly explanations.
class SyncErrorFormatter {
  const SyncErrorFormatter();

  /// Maps a [SyncErrorClassification] or error object into a traveler-facing explanation.
  static String formatUserMessage(
    Object error, {
    SyncErrorClassification? classification,
    String? entityName,
  }) {
    final resolvedClassification = classification ?? SyncErrorClassification.classify(error);
    final entityLabel = entityName != null && entityName.isNotEmpty ? entityName : 'item';

    switch (resolvedClassification) {
      case SyncErrorClassification.transient:
        return "You're offline. Your changes are saved and will sync when you're back online.";

      case SyncErrorClassification.authentication:
        return 'Please sign in again to continue syncing your changes.';

      case SyncErrorClassification.authorization:
        return 'You do not have permission to modify this $entityLabel. The server rejected the update.';

      case SyncErrorClassification.conflict:
        return 'This $entityLabel changed while you were offline. Please review and resolve the differences.';

      case SyncErrorClassification.notFound:
        return 'This $entityLabel was deleted or is no longer available on the server.';

      case SyncErrorClassification.validation:
        return 'The server could not process the update due to invalid information. Please review your details and try again.';

      case SyncErrorClassification.rateLimited:
        return 'Too many updates were submitted in a short period. Syncing will resume shortly.';

      case SyncErrorClassification.permanent:
        final errStr = error.toString().toLowerCase();
        if (errStr.contains('disk') || errStr.contains('enospc') || errStr.contains('storage')) {
          return 'Your device storage is almost full. SafeMate saved what it could, but please free up space.';
        }
        return "SafeMate couldn't reach the server. We'll try again.";
    }
  }

  /// Verifies whether a status message is safe to present as confirmed server delivery.
  /// Enforces: NEVER tell the user "Successfully synchronized" until server confirms success.
  static bool isServerConfirmedSuccess(SyncStatus status) {
    return status == SyncStatus.synced;
  }

  /// Returns traveler-friendly sync status banner copy.
  static String formatStatusBanner(SyncStatus status, {int pendingCount = 0}) {
    switch (status) {
      case SyncStatus.synced:
        return 'All changes synchronized with SafeMate cloud.';
      case SyncStatus.syncing:
        return 'Synchronizing changes with server...';
      case SyncStatus.pending:
        return pendingCount > 0
            ? '$pendingCount changes saved locally. Will sync when back online.'
            : 'Changes saved locally. Will sync when back online.';
      case SyncStatus.conflict:
        return 'Cloud conflict detected. Review needed to keep or merge changes.';
      case SyncStatus.failed:
        return "Sync paused. We'll try again automatically.";
      case SyncStatus.cancelled:
        return 'Sync operation cancelled.';
    }
  }
}
