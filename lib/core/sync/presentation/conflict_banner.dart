/// SafeMate Conflict Banner Widget.
/// Universal Engineering Rule #6: Clear communication of local vs. server-authoritative state.
/// Universal Engineering Rule #11: Non-technical traveler messaging for synchronization collisions.
library;

import 'package:flutter/material.dart';

/// Non-intrusive alert banner displayed when offline/remote conflicts require review.
class ConflictBanner extends StatelessWidget {
  final int conflictCount;
  final VoidCallback onReviewPressed;
  final bool isCompact;

  const ConflictBanner({
    super.key,
    required this.conflictCount,
    required this.onReviewPressed,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (conflictCount <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final warningColor = Colors.amber.shade800;

    if (isCompact) {
      return Semantics(
        button: true,
        label: '$conflictCount sync conflicts require review',
        child: InkWell(
          onTap: onReviewPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: warningColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: warningColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: warningColor),
                const SizedBox(width: 6),
                Text(
                  '$conflictCount conflict${conflictCount > 1 ? 's' : ''}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: warningColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: conflictCount == 1
          ? '1 synchronization update requires review. Changes made on another device conflict with your offline edits.'
          : '$conflictCount synchronization updates require review. Changes made on another device conflict with your offline edits.',
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: warningColor.withValues(alpha: 0.35)),
        ),
        color: warningColor.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: warningColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.sync_problem_rounded, color: warningColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conflictCount == 1
                          ? '1 update requires review'
                          : '$conflictCount updates require review',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Changes made on another device conflict with your offline edits.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Review sync conflicts',
                child: FilledButton.tonal(
                  onPressed: onReviewPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: warningColor.withValues(alpha: 0.18),
                    foregroundColor: warningColor,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: const Text('Review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
