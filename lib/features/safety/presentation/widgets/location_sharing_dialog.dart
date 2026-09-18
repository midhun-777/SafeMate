import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/safetrip_models.dart';

/// Transparent Location Sharing Dialog with explicit duration and immediate revocation.
/// Universal Engineering Rule #11 & Rule #15: Every location permission has a clear purpose & clear expiry.
class LocationSharingDialog extends StatefulWidget {
  final LocationShareSession? currentSession;
  final Function(LocationSharingMode mode, Duration duration) onStart;
  final VoidCallback onStop;

  const LocationSharingDialog({
    super.key,
    this.currentSession,
    required this.onStart,
    required this.onStop,
  });

  @override
  State<LocationSharingDialog> createState() => _LocationSharingDialogState();
}

class _LocationSharingDialogState extends State<LocationSharingDialog> {
  int _selectedHours = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCurrentlySharing = widget.currentSession != null && widget.currentSession!.isActive;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isCurrentlySharing
                        ? AppColors.secondaryTeal.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_on_outlined,
                    color: isCurrentlySharing ? AppColors.secondaryTeal : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location Sharing',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isCurrentlySharing ? 'Status: ACTIVE' : 'Status: OFF',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isCurrentlySharing ? AppColors.secondaryTeal : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.privacy_tip_outlined, size: 16, color: AppColors.secondaryTeal),
                      SizedBox(width: 6),
                      Text(
                        'Approximate Area Only',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'SafeMate shares an approximate city/transit region (~20km) with your selected trusted contact. Exact street coordinates are never shared.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (!isCurrentlySharing) ...[
              Text(
                'Sharing Duration:',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [1, 2, 4, 8].map((hours) {
                  final isSelected = _selectedHours == hours;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isSelected
                              ? AppColors.secondaryTeal.withValues(alpha: 0.15)
                              : null,
                          side: BorderSide(
                            color: isSelected ? AppColors.secondaryTeal : Colors.grey.shade400,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => setState(() => _selectedHours = hours),
                        child: Text(
                          '$hours hrs',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppColors.secondaryTeal : null,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.check),
                label: const Text('Start Approximate Sharing'),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onStart(
                    LocationSharingMode.approximate,
                    Duration(hours: _selectedHours),
                  );
                },
              ),
            ] else ...[
              Text(
                'Expires: ${widget.currentSession!.expiresAt.toLocal().toString().substring(11, 16)}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop Sharing Location'),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onStop();
                },
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
