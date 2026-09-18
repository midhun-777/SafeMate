/// Confirmation dialog for sensitive trip lifecycle actions.
/// Universal Engineering Rule #11: Explicit confirmation required, no accidental destructions.
library;

import 'package:flutter/material.dart';
import 'package:safemate/core/constants/app_colors.dart';

class TripLifecycleActionDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmLabel;
  final bool isDestructive;
  final VoidCallback onConfirm;

  const TripLifecycleActionDialog({
    super.key,
    required this.title,
    required this.content,
    required this.confirmLabel,
    this.isDestructive = false,
    required this.onConfirm,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => TripLifecycleActionDialog(
        title: title,
        content: content,
        confirmLabel: confirmLabel,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDestructive ? AppColors.error : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
        ),
      ),
      content: Text(
        content,
        style: TextStyle(
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Never mind'),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive ? AppColors.error : AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
