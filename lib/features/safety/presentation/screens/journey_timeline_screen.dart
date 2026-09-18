import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../controllers/safetrip_controller.dart';

/// Screen 07: SafeTrip Journey Timeline.
/// Displays chronological, privacy-safe events of an active or completed SafeTrip.
class JourneyTimelineScreen extends ConsumerWidget {
  final String journeyId;

  const JourneyTimelineScreen({super.key, required this.journeyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final state = ref.watch(safeTripControllerProvider);
    final events = state.events;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey Timeline'),
      ),
      body: events.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timeline_outlined,
                    size: 48,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                  const SizedBox(height: 12),
                  const Text('No timeline events recorded yet.'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final isLast = index == events.length - 1;
                final type = event['event_type'] as String? ?? 'unknown';
                final timeStr = event['created_at'] as String?;
                final timestamp =
                    timeStr != null ? DateTime.parse(timeStr).toLocal() : null;

                return _buildTimelineTile(
                  context: context,
                  type: type,
                  timestamp: timestamp,
                  isLast: isLast,
                );
              },
            ),
    );
  }

  Widget _buildTimelineTile({
    required BuildContext context,
    required String type,
    required DateTime? timestamp,
    required bool isLast,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final info = _getEventDisplayInfo(type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 50,
            child: Text(
              timestamp != null
                  ? timestamp.toString().substring(11, 16)
                  : '--:--',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Indicator Line and Dot
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: info.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: info.color, width: 2),
                ),
                child: Icon(info.icon, size: 12, color: info.color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Content column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    info.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _EventDisplay _getEventDisplayInfo(String type) {
    switch (type) {
      case 'journey_prepared':
        return const _EventDisplay(
          title: 'SafeTrip Prepared',
          description: 'Journey configured with safety preferences.',
          icon: Icons.checklist,
          color: AppColors.secondaryTeal,
        );
      case 'journey_activated':
        return const _EventDisplay(
          title: 'SafeTrip Activated',
          description: 'Journey in progress. Check-ins scheduled.',
          icon: Icons.play_arrow,
          color: AppColors.secondaryTeal,
        );
      case 'checkin_completed':
        return const _EventDisplay(
          title: 'Check-in Completed',
          description: 'Traveler reported "I\'m OK".',
          icon: Icons.check,
          color: Colors.green,
        );
      case 'checkin_missed':
        return const _EventDisplay(
          title: 'Check-in Missed',
          description: 'Scheduled check-in deadline passed.',
          icon: Icons.warning_amber_rounded,
          color: Colors.orange,
        );
      case 'location_sharing_started':
        return const _EventDisplay(
          title: 'Location Sharing Active',
          description: 'Approximate transit area shared with contact.',
          icon: Icons.location_on,
          color: AppColors.secondaryTeal,
        );
      case 'location_sharing_stopped':
        return const _EventDisplay(
          title: 'Location Sharing Stopped',
          description: 'Temporary location session terminated.',
          icon: Icons.location_off,
          color: Colors.grey,
        );
      case 'arrival_confirmed':
        return const _EventDisplay(
          title: 'Arrival Confirmed',
          description: 'Traveler reported safe arrival at destination.',
          icon: Icons.flag,
          color: Colors.green,
        );
      case 'journey_completed':
        return const _EventDisplay(
          title: 'Journey Completed',
          description: 'SafeTrip closed successfully.',
          icon: Icons.task_alt,
          color: Colors.green,
        );
      case 'journey_cancelled':
        return const _EventDisplay(
          title: 'Journey Cancelled',
          description: 'SafeTrip terminated by traveler.',
          icon: Icons.cancel_outlined,
          color: Colors.redAccent,
        );
      default:
        return const _EventDisplay(
          title: 'Journey Event',
          description: 'Status updated.',
          icon: Icons.circle,
          color: Colors.blueGrey,
        );
    }
  }
}

class _EventDisplay {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _EventDisplay({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
