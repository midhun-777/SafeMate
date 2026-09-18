/// Comprehensive journey review screen before publishing for companion matching.
/// Universal Engineering Rule #12: Profile/Journey review screen preventing accidental publication.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safemate/core/constants/app_colors.dart';
import 'package:safemate/features/auth/presentation/widgets/auth_button.dart';
import 'package:safemate/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:safemate/features/profile/domain/models/travel_personality.dart';
import '../controllers/trip_creation_controller.dart';
import '../controllers/trips_list_controller.dart';

class TripReviewScreen extends ConsumerWidget {
  const TripReviewScreen({super.key});

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(tripCreationControllerProvider);
    final notifier = ref.read(tripCreationControllerProvider.notifier);
    final trip = state.trip;
    final prefs = state.preferences;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Review Journey',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/trips/create'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: AuthErrorBanner(message: state.errorMessage!),
              ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Review Header
                    Text(
                      'Ready to Journey Together?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Review your journey details and companion preferences below.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 1. Destination & Route Card
                    _buildSectionCard(
                      title: 'Route & Destination',
                      onEdit: () {
                        notifier.setStep(0);
                        context.go('/trips/create');
                      },
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Trip Title', trip.title.isNotEmpty ? trip.title : 'Trip to ${trip.destination}', isDark),
                          const SizedBox(height: 8),
                          _buildDetailRow('Origin', trip.origin, isDark),
                          const SizedBox(height: 8),
                          _buildDetailRow('Destination', trip.destination, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Dates & Duration Card
                    _buildSectionCard(
                      title: 'Travel Dates',
                      onEdit: () {
                        notifier.setStep(1);
                        context.go('/trips/create');
                      },
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Departure', _formatDate(trip.startDate), isDark),
                          const SizedBox(height: 8),
                          _buildDetailRow('Return', _formatDate(trip.endDate), isDark),
                          const SizedBox(height: 8),
                          _buildDetailRow('Total Duration', trip.durationLabel, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Transport & Budget
                    _buildSectionCard(
                      title: 'Transport & Budget',
                      onEdit: () {
                        notifier.setStep(2);
                        context.go('/trips/create');
                      },
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Transport Mode', trip.transportMode.label, isDark),
                          const SizedBox(height: 8),
                          _buildDetailRow('Budget Tier', trip.budgetTier.label, isDark),
                          if (trip.estimatedBudget != null) ...[
                            const SizedBox(height: 8),
                            _buildDetailRow('Estimated Budget', '${trip.currency} ${trip.estimatedBudget!.toStringAsFixed(0)}', isDark),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Style & Purpose
                    _buildSectionCard(
                      title: 'Style & Purpose',
                      onEdit: () {
                        notifier.setStep(3);
                        context.go('/trips/create');
                      },
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Trip Purpose', trip.tripPurpose.label, isDark),
                          const SizedBox(height: 8),
                          Text(
                            'Trip Vibes:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (trip.tripStyles.isEmpty)
                            Text(
                              'Flexible / Open to all vibes',
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            )
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: trip.tripStyles.map((code) {
                                final vibe = TripVibe.fromCode(code);
                                return Chip(
                                  label: Text(vibe?.label ?? code),
                                  backgroundColor: AppColors.primaryContainer,
                                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5. Companion Criteria
                    _buildSectionCard(
                      title: 'Companion Preferences',
                      onEdit: () {
                        notifier.setStep(4);
                        context.go('/trips/create');
                      },
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Pace', prefs.travelPace.label, isDark),
                          const SizedBox(height: 8),
                          _buildDetailRow('Social Dynamic', prefs.socialEnergy.label, isDark),
                          const SizedBox(height: 8),
                          _buildDetailRow('Accommodation', prefs.accommodationPreference.label, isDark),
                          if (prefs.activityInterests.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildDetailRow('Shared Activities', prefs.activityInterests.join(', '), isDark),
                          ],
                          if (prefs.dietaryPreferences.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildDetailRow('Diet Openness', prefs.dietaryPreferences.join(', '), isDark),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 6. Privacy & Visibility
                    _buildSectionCard(
                      title: 'Privacy & Group',
                      onEdit: () {
                        notifier.setStep(5);
                        context.go('/trips/create');
                      },
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Visibility', trip.visibility.label, isDark),
                          const SizedBox(height: 8),
                          _buildDetailRow('Max Companions', '${trip.maxCompanions} travelers', isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Publish Button
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
              ),
              child: AuthButton(
                text: 'Publish Journey',
                isLoading: state.isPublishing,
                onPressed: () async {
                  final ok = await notifier.publishTrip();
                  if (ok) {
                    await ref.read(tripsListControllerProvider.notifier).loadTrips();
                    if (context.mounted) {
                      context.go('/home');
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required VoidCallback onEdit,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
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
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const Divider(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    );
  }
}
