import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../profile/domain/models/profile_visibility.dart';
import '../controllers/safety_controllers.dart';

/// Screen for managing Traveler Privacy, Discovery Visibility, and Location Obfuscation.
/// Universal Engineering Rule #10: Privacy and consent are first-class design constraints.
class PrivacyCenterScreen extends ConsumerWidget {
  const PrivacyCenterScreen({super.key});

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final privacyAsync = ref.watch(privacySettingsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Visibility Center'),
      ),
      body: privacyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load privacy settings: $e')),
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Privacy Principles Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.security, color: AppColors.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Privacy by Design',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'SafeMate never sells personal data or shares live, pinpoint GPS coordinates. You decide who sees your profile, your journey schedule, and your travel status.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              _buildSectionHeader(context, 'Profile Discovery'),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        settings.profileVisibility == ProfileVisibility.publicToMatches
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: settings.profileVisibility == ProfileVisibility.publicToMatches
                            ? AppColors.primary
                            : AppColors.secondaryLight,
                      ),
                      title: const Text('Public to Matches'),
                      subtitle: const Text(
                        'Visible only to verified travelers with overlapping routes and dates.',
                        style: TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        ref
                            .read(privacySettingsControllerProvider.notifier)
                            .updateSettings(
                              settings.copyWith(
                                profileVisibility: ProfileVisibility.publicToMatches,
                              ),
                            );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        settings.profileVisibility == ProfileVisibility.private
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: settings.profileVisibility == ProfileVisibility.private
                            ? AppColors.primary
                            : AppColors.secondaryLight,
                      ),
                      title: const Text('Private Connections Only'),
                      subtitle: const Text(
                        'Visible only to travelers you have explicitly approved.',
                        style: TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        ref
                            .read(privacySettingsControllerProvider.notifier)
                            .updateSettings(
                              settings.copyWith(
                                profileVisibility: ProfileVisibility.private,
                              ),
                            );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        settings.profileVisibility == ProfileVisibility.hidden
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: settings.profileVisibility == ProfileVisibility.hidden
                            ? AppColors.primary
                            : AppColors.secondaryLight,
                      ),
                      title: const Text('Hidden Mode'),
                      subtitle: const Text(
                        'Completely hidden from discovery and route recommendations.',
                        style: TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        ref
                            .read(privacySettingsControllerProvider.notifier)
                            .updateSettings(
                              settings.copyWith(
                                profileVisibility: ProfileVisibility.hidden,
                              ),
                            );
                      },
                    ),
                  ],
                ),
              ),

              _buildSectionHeader(context, 'Location & Presence Controls'),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: settings.coarseLocationOnly,
                      activeThumbColor: AppColors.primary,
                      title: const Text('Coarse Location Only (Recommended)'),
                      subtitle: const Text(
                        'Obfuscates location into ~20km geohash zones. Exact street coordinates are never shared.',
                        style: TextStyle(fontSize: 12),
                      ),
                      onChanged: (val) {
                        ref
                            .read(privacySettingsControllerProvider.notifier)
                            .updateSettings(settings.copyWith(coarseLocationOnly: val));
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: settings.showOnlinePresence,
                      activeThumbColor: AppColors.primary,
                      title: const Text('Show Online Status'),
                      subtitle: const Text(
                        'Allows active connections to see when you are online.',
                        style: TextStyle(fontSize: 12),
                      ),
                      onChanged: (val) {
                        ref
                            .read(privacySettingsControllerProvider.notifier)
                            .updateSettings(settings.copyWith(showOnlinePresence: val));
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: settings.allowCompanionRequests,
                      activeThumbColor: AppColors.primary,
                      title: const Text('Allow Companion Requests'),
                      subtitle: const Text(
                        'Permits compatible travelers to send you journey companion requests.',
                        style: TextStyle(fontSize: 12),
                      ),
                      onChanged: (val) {
                        ref
                            .read(privacySettingsControllerProvider.notifier)
                            .updateSettings(settings.copyWith(allowCompanionRequests: val));
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
