import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/services/ai_safety_rule_engine.dart';

/// Interactive AI safety advisory banner for chat and communication screens.
/// Universal Engineering Rule #11: Safety is a core product capability.
class AiSafetyAdvisoryBanner extends StatelessWidget {
  final SafetyWarning warning;
  final ValueChanged<String>? onApplySuggestion;
  final VoidCallback? onDismiss;

  const AiSafetyAdvisoryBanner({
    super.key,
    required this.warning,
    this.onApplySuggestion,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color accentColor;
    IconData icon;

    switch (warning.severity) {
      case SafetyWarningSeverity.critical:
        accentColor = AppColors.safetyAlert;
        icon = Icons.gpp_bad;
        break;
      case SafetyWarningSeverity.warning:
        accentColor = AppColors.safetyWarning;
        icon = Icons.warning_amber_rounded;
        break;
      case SafetyWarningSeverity.info:
        accentColor = AppColors.primary;
        icon = Icons.shield_outlined;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  warning.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  onPressed: onDismiss,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            warning.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              height: 1.35,
            ),
          ),
          if (warning.suggestedReplies.isNotEmpty && onApplySuggestion != null) ...[
            const SizedBox(height: 10),
            Text(
              'Safe replies you can send:',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: warning.suggestedReplies.map((reply) {
                return ActionChip(
                  label: Text(
                    reply,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  backgroundColor: isDark
                      ? AppColors.surfaceVariantDark
                      : AppColors.surfaceLight,
                  side: BorderSide(
                    color: accentColor.withValues(alpha: 0.3),
                  ),
                  onPressed: () => onApplySuggestion!(reply),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
