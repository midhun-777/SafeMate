import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/models/report_models.dart';
import '../controllers/safety_controllers.dart';

/// Screen for filing confidential safety reports and blocking bad actors.
/// Universal Engineering Rule #11: Safety is a core product capability.
/// Universal Engineering Rule #10: Privacy and consent are first-class design constraints.
class SafetyReportScreen extends ConsumerStatefulWidget {
  final String? targetUserId;
  final String? targetUserName;
  final String? contextType;
  final String? contextId;

  const SafetyReportScreen({
    super.key,
    this.targetUserId,
    this.targetUserName,
    this.contextType,
    this.contextId,
  });

  @override
  ConsumerState<SafetyReportScreen> createState() => _SafetyReportScreenState();
}

class _SafetyReportScreenState extends ConsumerState<SafetyReportScreen> {
  ReportCategory _selectedCategory = ReportCategory.harassment;
  final _descriptionController = TextEditingController();
  final _userIdController = TextEditingController();
  bool _alsoBlockUser = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.targetUserId != null) {
      _userIdController.text = widget.targetUserId!;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final authState = ref.read(authControllerProvider);
    final currentUserId = authState.profile?.id ?? authState.session?.userId;

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to file a report')),
      );
      return;
    }

    final targetUid = _userIdController.text.trim();
    if (targetUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or select the user to report')),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the safety concern')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await ref.read(reportControllerProvider.notifier).submitReport(
          reporterId: currentUserId,
          reportedUserId: targetUid,
          category: _selectedCategory,
          description: _descriptionController.text.trim(),
          contextType: widget.contextType ?? 'general',
          contextId: widget.contextId,
        );

    if (_alsoBlockUser && success) {
      await ref.read(reportControllerProvider.notifier).blockUser(
            blockerId: currentUserId,
            targetUserId: targetUid,
            reason: _selectedCategory.toDbValue(),
          );
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Report Submitted'),
            content: const Text(
              'Thank you for helping keep SafeMate safe. Your report is completely confidential.\n\n'
              'Our 24/7 Safety Review Team will investigate promptly.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit report. Please try again.'),
            backgroundColor: AppColors.safetyAlert,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report a Safety Concern'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.safetyAlert.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.safetyAlert.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.safetyAlert, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your report is strictly confidential. The reported user will never be told who submitted the report.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (widget.targetUserId == null) ...[
            TextField(
              controller: _userIdController,
              decoration: const InputDecoration(
                labelText: 'User ID or Handle to Report',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
          ] else if (widget.targetUserName != null) ...[
            Text(
              'Reporting: ${widget.targetUserName}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
          ],

          Text(
            'What is the nature of the issue?',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ...ReportCategory.values.map((cat) {
            final isSelected = cat == _selectedCategory;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? AppColors.safetyAlert : AppColors.secondaryLight,
              ),
              title: Text(cat.displayName, style: const TextStyle(fontSize: 14)),
              onTap: () {
                setState(() => _selectedCategory = cat);
              },
            );
          }),

          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Details / Description',
              hintText: 'Please provide specific details so our safety team can investigate...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),

          CheckboxListTile(
            value: _alsoBlockUser,
            activeColor: AppColors.safetyAlert,
            title: const Text('Block this user immediately', style: TextStyle(fontSize: 14)),
            subtitle: const Text(
              'They will not be able to message you, view your trips, or match with you.',
              style: TextStyle(fontSize: 12),
            ),
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              setState(() => _alsoBlockUser = val ?? true);
            },
          ),
          const SizedBox(height: 20),

          FilledButton(
            onPressed: _isSubmitting ? null : _submitReport,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.safetyAlert,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Submit Confidential Report'),
          ),
        ],
      ),
    );
  }
}
