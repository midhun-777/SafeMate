import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Need Help Dialog with calm, human, non-alarming safety options.
/// Universal Engineering Rule #11 & Rule #12: No fake emergency dispatch or autonomous emergency calls.
class NeedHelpDialog extends StatelessWidget {
  final String? trustedContactName;
  final String? trustedContactPhone;
  final VoidCallback onShareStatus;

  const NeedHelpDialog({
    super.key,
    this.trustedContactName,
    this.trustedContactPhone,
    required this.onShareStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                    color: AppColors.secondaryTeal.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppColors.secondaryTeal,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Need Assistance?',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Choose the support action you need:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Option 1: Contact Trusted Contact
            _buildHelpOption(
              context: context,
              icon: Icons.contact_phone_outlined,
              title: trustedContactName != null
                  ? 'Contact $trustedContactName'
                  : 'Contact Trusted Person',
              subtitle: trustedContactPhone != null
                  ? 'Call or message your designated safety contact'
                  : 'Reach out to your pre-configured safety contact',
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      trustedContactName != null
                          ? 'Opening communication with $trustedContactName ($trustedContactPhone)'
                          : 'Please configure a trusted contact in Safety Center.',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            // Option 2: Share Journey Status
            _buildHelpOption(
              context: context,
              icon: Icons.share_location_outlined,
              title: 'Share Journey Status',
              subtitle: 'Send your current status update to authorized contacts',
              onTap: () {
                Navigator.of(context).pop();
                onShareStatus();
              },
            ),
            const SizedBox(height: 10),

            // Option 3: Local Emergency Guidance
            _buildHelpOption(
              context: context,
              icon: Icons.info_outline,
              title: 'Safety Guidelines & Resources',
              subtitle: 'Review pre-journey checklists and local advice',
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Accessing SafeMate Community Safety Guidelines.'),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            // Option 4: Local Emergency Services (Confirmation boundary)
            _buildHelpOption(
              context: context,
              icon: Icons.local_police_outlined,
              title: 'Local Emergency Services',
              subtitle: 'If you are in immediate danger, contact emergency services (112 / 911)',
              isEmergency: true,
              onTap: () {
                Navigator.of(context).pop();
                _showEmergencyConfirm(context);
              },
            ),
            const SizedBox(height: 16),

            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isEmergency = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isEmergency
          ? Colors.red.withValues(alpha: 0.08)
          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: isEmergency ? Colors.redAccent : AppColors.secondaryTeal,
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isEmergency ? Colors.redAccent : null,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: isDark ? Colors.white30 : Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmergencyConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Call Emergency Services?'),
        content: const Text(
          'If you are facing immediate personal danger, please use your device dialer to connect directly to local law enforcement or rescue services (e.g. 112 / 911).\n\nSafeMate does not automatically place emergency calls.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please dial 112 / 911 on your phone dialer.'),
                ),
              );
            },
            child: const Text('Open Phone Dialer'),
          ),
        ],
      ),
    );
  }
}
