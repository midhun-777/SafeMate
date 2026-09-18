import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safemate/core/constants/app_colors.dart';
import 'package:safemate/features/profile/domain/models/travel_personality.dart';
import '../controllers/profile_controller.dart';

/// Public / Companion preview screen for a user's verified traveler profile.
class ProfileViewScreen extends ConsumerWidget {
  const ProfileViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(profileControllerProvider);

    final profile = state.profile;
    final preferences = state.preferences;
    final completion = state.completion;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Traveler Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () => context.go('/profile/setup'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer,
                  border: Border.all(color: AppColors.primary, width: 2),
                  image: profile.avatarUrl?.isNotEmpty == true &&
                          profile.avatarUrl!.startsWith('http')
                      ? DecorationImage(
                          image: NetworkImage(profile.avatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: profile.avatarUrl?.isEmpty != false
                    ? const Icon(
                        Icons.person_outline,
                        size: 48,
                        color: AppColors.primary,
                      )
                    : null,
              ),
              const SizedBox(height: 16),

              // Name & Location
              Text(
                profile.displayName.isNotEmpty ? profile.displayName : 'Traveler',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              if (profile.homeCity?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.place_outlined, size: 16, color: AppColors.textSecondaryLight),
                    const SizedBox(width: 4),
                    Text(
                      profile.homeCity!,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // Trust & Completion Badges
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Trust Score: ${profile.trustScore}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: Text(
                      '${completion.percentage}% Complete',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Bio Card
              if (profile.bio?.isNotEmpty == true) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'About Me',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        profile.bio!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Trip Vibes
              if (profile.travelStyles.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Trip Vibes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.start,
                  children: profile.travelStyles.map((code) {
                    final vibe = TripVibe.fromCode(code);
                    return Chip(
                      label: Text(vibe?.label ?? code),
                      backgroundColor: AppColors.primaryContainer,
                      labelStyle: const TextStyle(fontSize: 12, color: AppColors.onPrimaryContainer),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],

              // Travel Dynamics Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    _buildRow(
                      icon: Icons.speed_outlined,
                      label: 'Pace',
                      val: preferences.travelPace.label,
                    ),
                    const Divider(height: 16),
                    _buildRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Budget',
                      val: preferences.budgetTier.label,
                    ),
                    const Divider(height: 16),
                    _buildRow(
                      icon: Icons.hotel_outlined,
                      label: 'Lodging',
                      val: preferences.accommodationPreference.label,
                    ),
                    const Divider(height: 16),
                    _buildRow(
                      icon: Icons.groups_outlined,
                      label: 'Social',
                      val: preferences.socialEnergy.label,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Update Profile & Preferences'),
                onPressed: () => context.go('/profile/setup'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow({required IconData icon, required String label, required String val}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
        ),
        const Spacer(),
        Text(
          val,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
