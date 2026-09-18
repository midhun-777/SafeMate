import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safemate/core/constants/app_colors.dart';
import 'package:safemate/features/auth/presentation/widgets/auth_button.dart';
import 'package:safemate/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:safemate/features/profile/domain/models/travel_personality.dart';
import '../controllers/profile_controller.dart';

/// Pre-completion summary screen allowing users to review and edit their traveler identity.
/// Universal Engineering Rule #12: Profile Review Screen.
class ProfileReviewScreen extends ConsumerWidget {
  const ProfileReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(profileControllerProvider);
    final notifier = ref.read(profileControllerProvider.notifier);

    final profile = state.profile;
    final preferences = state.preferences;
    final completion = state.completion;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            notifier.setStep(3);
            context.go('/profile/setup');
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to travel?',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Review your travel identity summary below before confirming.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Completion Banner Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Profile is ${completion.percentage}% Complete',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  completion.tierLabel == 'Complete'
                                      ? 'You are ready for companion matching!'
                                      : 'You can update remaining preferences anytime.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (state.errorMessage != null) ...[
                      AuthErrorBanner(
                        message: state.errorMessage!,
                        onDismiss: () => notifier.clearMessage(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Section 1: Basic Identity
                    _buildReviewCard(
                      context: context,
                      title: 'Basic Identity',
                      stepIndex: 0,
                      isDark: isDark,
                      content: [
                        _buildDataRow('Display Name', profile.displayName),
                        _buildDataRow('Home Region', profile.homeCity ?? 'Not specified'),
                        _buildDataRow('Bio', profile.bio?.isNotEmpty == true ? profile.bio! : 'Not added yet'),
                        _buildDataRow('Languages', profile.languages.isNotEmpty ? profile.languages.join(', ') : 'None listed'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section 2: Travel Personality
                    _buildReviewCard(
                      context: context,
                      title: 'Travel Personality',
                      stepIndex: 1,
                      isDark: isDark,
                      content: [
                        _buildDataRow(
                          'Trip Vibes',
                          profile.travelStyles.isNotEmpty
                              ? profile.travelStyles.map((s) => TripVibe.fromCode(s)?.label ?? s).join(', ')
                              : 'Flexible',
                        ),
                        _buildDataRow('Travel Pace', preferences.travelPace.label),
                        _buildDataRow('Schedule', preferences.schedulePreference.label),
                        _buildDataRow('Planning Style', preferences.planningStyle.label),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section 3: Travel Preferences
                    _buildReviewCard(
                      context: context,
                      title: 'Travel Preferences',
                      stepIndex: 2,
                      isDark: isDark,
                      content: [
                        _buildDataRow('Budget Tier', preferences.budgetTier.label),
                        _buildDataRow('Accommodation', preferences.accommodationPreference.label),
                        _buildDataRow('Social Style', preferences.socialEnergy.label),
                        _buildDataRow(
                          'Transport',
                          preferences.preferredTransport.isNotEmpty
                              ? preferences.preferredTransport.join(', ')
                              : 'Flexible',
                        ),
                        _buildDataRow(
                          'Interests',
                          preferences.activityInterests.isNotEmpty
                              ? preferences.activityInterests.join(', ')
                              : 'None selected',
                        ),
                        _buildDataRow(
                          'Dietary',
                          preferences.dietaryPreferences.isNotEmpty
                              ? preferences.dietaryPreferences.join(', ')
                              : 'Flexible',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section 4: Privacy Settings
                    _buildReviewCard(
                      context: context,
                      title: 'Privacy Settings',
                      stepIndex: 3,
                      isDark: isDark,
                      content: [
                        _buildDataRow('Visibility', profile.visibility.label),
                        _buildDataRow('Protection', 'Email, phone, and coordinates hidden'),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Confirm Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
              ),
              child: AuthButton(
                text: 'Confirm & Go to Home',
                isLoading: state.isSaving,
                onPressed: () async {
                  final success = await notifier.completeProfileSetup();
                  if (success && context.mounted) {
                    context.go('/home');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard({
    required BuildContext context,
    required String title,
    required int stepIndex,
    required bool isDark,
    required List<Widget> content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  return TextButton(
                    onPressed: () {
                      ref.read(profileControllerProvider.notifier).setStep(stepIndex);
                      context.go('/profile/setup');
                    },
                    child: const Text(
                      'Edit',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
            ],
          ),
          const Divider(height: 16),
          ...content,
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
