/// Card displaying structured journey summary on user's trip list.
/// Universal Engineering Rule #13: Calm, clear visual hierarchy, accessible touch targets.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safemate/core/constants/app_colors.dart';
import 'package:safemate/features/profile/domain/models/travel_personality.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_status.dart';
import '../../domain/models/trip_visibility.dart';

class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onComplete;
  final VoidCallback? onDeleteDraft;

  const TripCard({
    super.key,
    required this.trip,
    this.onTap,
    this.onEdit,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onComplete,
    this.onDeleteDraft,
  });


  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.draft:
        return Colors.orange;
      case TripStatus.published:
        return AppColors.primary;
      case TripStatus.paused:
        return Colors.amber.shade700;
      case TripStatus.cancelled:
        return AppColors.error;
      case TripStatus.completed:
        return Colors.teal;
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _getStatusColor(trip.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap ?? () => context.go('/trips/${trip.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Status & Visibility & Action Menu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          trip.status.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (trip.visibility == TripVisibility.private)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),

                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 12,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Private',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    onSelected: (val) {
                      switch (val) {
                        case 'details':
                          context.go('/trips/${trip.id}');
                          break;
                        case 'edit':
                          context.go('/trips/${trip.id}/edit');
                          break;
                        case 'pause':
                          onPause?.call();
                          break;
                        case 'resume':
                          onResume?.call();
                          break;
                        case 'cancel':
                          onCancel?.call();
                          break;
                        case 'complete':
                          onComplete?.call();
                          break;
                        case 'delete':
                          onDeleteDraft?.call();
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: Text('View Details'),
                      ),
                      if (!trip.isCancelled && !trip.isCompleted)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit Journey'),
                        ),
                      if (trip.isPublished)
                        const PopupMenuItem(
                          value: 'pause',
                          child: Text('Pause Matching'),
                        ),
                      if (trip.isPaused)
                        const PopupMenuItem(
                          value: 'resume',
                          child: Text('Resume Matching'),
                        ),
                      if (trip.isPublished || trip.isPaused) ...[
                        const PopupMenuItem(
                          value: 'complete',
                          child: Text('Mark as Completed'),
                        ),
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Text('Cancel Journey', style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                      if (trip.isDraft)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete Draft', style: TextStyle(color: AppColors.error)),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Destination & Title
              Text(
                trip.title.isNotEmpty ? trip.title : 'Trip to ${trip.destination}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 4),

              // Route: Origin -> Destination
              Row(
                children: [
                  Icon(
                    Icons.route_outlined,
                    size: 15,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${trip.origin} → ${trip.destination}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Dates & Duration
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_formatDate(trip.startDate)} → ${_formatDate(trip.endDate)} • ${trip.durationLabel}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bottom Pills: Transport & Style tags
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      trip.transportMode.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      trip.tripPurpose.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                  ...trip.tripStyles.take(2).map((code) {
                    final vibe = TripVibe.fromCode(code);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        vibe?.label ?? code,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onPrimaryContainer,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
