import 'package:flutter/material.dart';
import 'package:safemate/core/constants/app_colors.dart';
import 'package:safemate/features/profile/domain/models/profile_completion.dart';

/// Progress and completion indicator for the SafeMate profile wizard.
class ProfileProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String stepTitle;
  final ProfileCompletion completion;

  const ProfileProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepTitle,
    required this.completion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final progressRatio = (completion.percentage / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Step ${currentStep + 1} of $totalSteps • $stepTitle',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${completion.percentage}% • ${completion.tierLabel}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progressRatio,
            minHeight: 6,
            backgroundColor: isDark
                ? AppColors.surfaceVariantDark
                : AppColors.surfaceVariantLight,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}
