/// Contextual empty state for companion discovery.
/// Universal Engineering Rule #14: Actionable empty states, zero fake production data.
library;

import 'package:flutter/material.dart';
import 'package:safemate/core/constants/app_colors.dart';

class MatchEmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback? onAdjustFilters;

  const MatchEmptyState({
    super.key,
    required this.onRefresh,
    this.onAdjustFilters,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.travel_explore_outlined,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No strong matches yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Your journey is published, but we haven\'t found compatible companions with overlapping dates and route yet.\n\nTry relaxing date flexibility or transport preferences.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
                if (onAdjustFilters != null) ...[
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                    onPressed: onAdjustFilters,
                    child: const Text('Reset Filters'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
