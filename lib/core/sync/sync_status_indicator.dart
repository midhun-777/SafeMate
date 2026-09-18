/// SafeMate Reusable Sync Status & Manual Sync Indicator.
/// Universal Engineering Rule #11: Clear communication of local vs. server-authoritative state.
library;

import 'package:flutter/material.dart';
import 'sync_engine.dart';

/// Presentation widget displaying sync lifecycle states, cache freshness, and manual trigger.
class SyncStatusIndicator extends StatelessWidget {
  final SyncEngineStatus status;
  final DateTime? lastSyncedAt;
  final VoidCallback? onSyncNow;
  final bool isCompact;

  const SyncStatusIndicator({
    super.key,
    required this.status,
    this.lastSyncedAt,
    this.onSyncNow,
    this.isCompact = false,
  });

  String _formatFreshness(DateTime? dt) {
    if (dt == null) return 'Not synced yet';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Synced just now';
    if (diff.inMinutes < 60) return 'Synced ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Synced ${diff.inHours}h ago';
    return 'Synced ${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    IconData icon;
    Color color;
    String label;

    switch (status) {
      case SyncEngineStatus.syncing:
        icon = Icons.sync;
        color = theme.colorScheme.primary;
        label = 'Syncing...';
        break;
      case SyncEngineStatus.offline:
        icon = Icons.cloud_off_outlined;
        color = Colors.amber.shade700;
        label = 'Offline — saved on device';
        break;
      case SyncEngineStatus.authRequired:
        icon = Icons.lock_outline;
        color = Colors.orange.shade700;
        label = 'Sign in to sync';
        break;
      case SyncEngineStatus.error:
        icon = Icons.error_outline;
        color = theme.colorScheme.error;
        label = 'Sync issue — tap to retry';
        break;
      case SyncEngineStatus.idle:
        icon = Icons.check_circle_outline;
        color = Colors.green.shade600;
        label = _formatFreshness(lastSyncedAt);
        break;
    }

    if (isCompact) {
      return Tooltip(
        message: label,
        child: InkWell(
          onTap: status == SyncEngineStatus.syncing ? null : onSyncNow,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: status == SyncEngineStatus.syncing
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                : Icon(icon, size: 18, color: color),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == SyncEngineStatus.syncing)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: Icon(icon, size: 16, color: color),
            ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onSyncNow != null && status != SyncEngineStatus.syncing) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onSyncNow,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'Sync now',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
