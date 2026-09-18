import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Standardized Verified Identity Badge for SafeMate travelers.
/// Universal Engineering Rule #11: Safety is a core product capability.
/// Universal Engineering Rule #14: Never promise absolute safety ("100% Safe").
class VerificationBadge extends StatelessWidget {
  final bool isVerified;
  final bool isPhoneVerified;
  final bool compact;
  final String? customLabel;

  const VerificationBadge({
    super.key,
    required this.isVerified,
    this.isPhoneVerified = false,
    this.compact = false,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!isVerified && !isPhoneVerified) {
      if (compact) {
        return const SizedBox.shrink();
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 14,
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            ),
            const SizedBox(width: 4),
            Text(
              'Unverified',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final label = customLabel ??
        (isVerified ? 'Identity Verified' : 'Phone Verified');
    final icon = isVerified ? Icons.verified : Icons.phone_android;
    final color = isVerified ? AppColors.primary : AppColors.secondary;

    if (compact) {
      return Tooltip(
        message: '$label (Identity process confirmed)',
        child: Icon(
          icon,
          size: 18,
          color: isDark ? AppColors.primaryLight : color,
        ),
      );
    }

    return Tooltip(
      message: 'Identity verification confirms government ID or phone record match.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (isDark ? AppColors.primaryLight : AppColors.primary).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isDark ? AppColors.primaryLight : AppColors.primary).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isDark ? AppColors.primaryLight : color,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isDark ? AppColors.primaryLight : color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
