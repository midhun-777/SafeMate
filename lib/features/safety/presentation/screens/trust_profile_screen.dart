import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../controllers/safety_controllers.dart';
import '../widgets/verification_badge.dart';

/// Traveler Trust Profile / Travel Passport Screen.
/// Provides radical transparency into how the traveler's trust score is calculated.
/// Universal Engineering Rule #11: Safety is a core product capability.
/// Universal Engineering Rule #14: Never promise absolute safety ("100% Safe").
class TrustProfileScreen extends ConsumerWidget {
  final String userId;

  const TrustProfileScreen({super.key, required this.userId});

  Widget _buildScoreGauge(BuildContext context, int score) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: CircularProgressIndicator(
              value: (score / 100.0).clamp(0.0, 1.0),
              strokeWidth: 10,
              backgroundColor: AppColors.borderLight.withValues(alpha: 0.5),
              color: score >= 70
                  ? AppColors.primary
                  : (score >= 40 ? AppColors.safetyWarning : AppColors.secondary),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              const Text(
                'TRUST SCORE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryLight,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isBonus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isBonus ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profileAsync = ref.watch(trustProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Traveler Trust Profile'),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load trust profile: $e')),
        data: (profile) {
          final b = profile.breakdown;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Top Score Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildScoreGauge(context, profile.trustScore),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          VerificationBadge(
                            isVerified: profile.isIdentityVerified,
                            isPhoneVerified: profile.isPhoneVerified,
                          ),
                          ...profile.badges.map((badge) {
                            return Chip(
                              label: Text(badge, style: const TextStyle(fontSize: 12)),
                              backgroundColor: isDark
                                  ? AppColors.surfaceVariantDark
                                  : AppColors.surfaceVariantLight,
                              side: BorderSide(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Stats Grid
              Row(
                children: [
                  Expanded(
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            const Icon(Icons.flight_takeoff, color: AppColors.primary, size: 22),
                            const SizedBox(height: 4),
                            Text(
                              '${profile.tripsCompleted}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Text('Trips Completed', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            const Icon(Icons.star, color: AppColors.safetyWarning, size: 22),
                            const SizedBox(height: 4),
                            Text(
                              profile.reliabilityRating.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Text('Rating', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            const Icon(Icons.reviews_outlined, color: AppColors.secondary, size: 22),
                            const SizedBox(height: 4),
                            Text(
                              '${profile.reviewCount}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Text('Reviews', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Explainable Score Breakdown
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calculate_outlined, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'How this score is calculated',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildBreakdownRow(
                        'Profile Completeness',
                        '${b.profileCompletenessPoints} / 20 pts',
                      ),
                      _buildBreakdownRow(
                        'Phone Verification',
                        '${b.phoneVerifiedPoints} / 15 pts',
                      ),
                      _buildBreakdownRow(
                        'Government ID & Liveness',
                        '${b.identityVerifiedPoints} / 30 pts',
                        isBonus: b.identityVerifiedPoints > 0,
                      ),
                      _buildBreakdownRow(
                        'Completed Journeys',
                        '${b.tripsCompletedPoints} / 15 pts',
                      ),
                      _buildBreakdownRow(
                        'Companion Reliability & Ratings',
                        '${b.companionReviewsPoints} / 20 pts',
                      ),
                      if (b.penaltyDeductions > 0)
                        _buildBreakdownRow(
                          'Safety Report Deductions',
                          '-${b.penaltyDeductions} pts',
                        ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Trust Score',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            '${b.totalScore} / 100',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 4. Companion Reviews Section
              Text(
                'Recent Companion Reviews',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (profile.recentReviews.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No reviews yet. Complete your first journey together to receive reviews.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryLight,
                        ),
                      ),
                    ),
                  ),
                )
              else
                ...profile.recentReviews.map((rev) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.star, color: AppColors.safetyWarning, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    rev.overallRating.toStringAsFixed(1),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Text(
                                '${rev.createdAt.day}/${rev.createdAt.month}/${rev.createdAt.year}',
                                style: const TextStyle(fontSize: 11, color: AppColors.secondaryLight),
                              ),
                            ],
                          ),
                          if (rev.comment != null && rev.comment!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              '"${rev.comment}"',
                              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              Text(
                                'Comm: ${rev.communicationRating}/5',
                                style: const TextStyle(fontSize: 10, color: AppColors.secondary),
                              ),
                              Text(
                                'Punc: ${rev.punctualityRating}/5',
                                style: const TextStyle(fontSize: 10, color: AppColors.secondary),
                              ),
                              Text(
                                'Respect: ${rev.respectRating}/5',
                                style: const TextStyle(fontSize: 10, color: AppColors.secondary),
                              ),
                              Text(
                                'Plan: ${rev.planningRating}/5',
                                style: const TextStyle(fontSize: 10, color: AppColors.secondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
