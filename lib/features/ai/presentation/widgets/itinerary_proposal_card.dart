/// SafeMate Itinerary Proposal Card Widget.
/// Universal Engineering Rule #11: Review-before-apply pattern. AI never silently overwrites plans.
library;

import 'package:flutter/material.dart';
import 'package:safemate/core/constants/app_colors.dart';

class ItineraryProposalCard extends StatelessWidget {
  final Map<String, dynamic> proposal;
  final VoidCallback onApply;
  final VoidCallback onDismiss;

  const ItineraryProposalCard({
    super.key,
    required this.proposal,
    required this.onApply,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final title = proposal['title'] as String? ?? 'Suggested Itinerary';
    final items = proposal['items'] as List<dynamic>? ?? [];
    final disclaimer = proposal['disclaimer'] as String? ??
        'AI suggestion for planning guidance only. Please verify operating hours independently.';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.take(4).map((item) {
            if (item is! Map<String, dynamic>) return const SizedBox.shrink();
            final dayTitle = item['title'] as String? ?? 'Day Item';
            final morning = item['morning'] as String? ?? '';
            final afternoon = item['afternoon'] as String? ?? '';
            final evening = item['evening'] as String? ?? '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (morning.isNotEmpty)
                    Text('• Morning: $morning', style: const TextStyle(fontSize: 12)),
                  if (afternoon.isNotEmpty)
                    Text('• Afternoon: $afternoon', style: const TextStyle(fontSize: 12)),
                  if (evening.isNotEmpty)
                    Text('• Evening: $evening', style: const TextStyle(fontSize: 12)),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.amber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    disclaimer,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.amber[200] : Colors.amber[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Keep Current Plan', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onApply,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Apply Plan', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
