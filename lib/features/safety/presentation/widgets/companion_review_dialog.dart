import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../controllers/safety_controllers.dart';

/// Modal dialog for rating and reviewing a travel companion.
/// Universal Engineering Rule #11: Safety is a core product capability.
class CompanionReviewDialog extends ConsumerStatefulWidget {
  final String tripId;
  final String reviewerId;
  final String revieweeId;
  final String revieweeName;

  const CompanionReviewDialog({
    super.key,
    required this.tripId,
    required this.reviewerId,
    required this.revieweeId,
    required this.revieweeName,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String tripId,
    required String reviewerId,
    required String revieweeId,
    required String revieweeName,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => CompanionReviewDialog(
        tripId: tripId,
        reviewerId: reviewerId,
        revieweeId: revieweeId,
        revieweeName: revieweeName,
      ),
    );
  }

  @override
  ConsumerState<CompanionReviewDialog> createState() => _CompanionReviewDialogState();
}

class _CompanionReviewDialogState extends ConsumerState<CompanionReviewDialog> {
  int _commRating = 5;
  int _puncRating = 5;
  int _respRating = 5;
  int _planRating = 5;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Widget _buildRatingRow(String label, int value, ValueChanged<int> onChanged) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              final star = index + 1;
              return InkWell(
                onTap: () => onChanged(star),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Icon(
                    star <= value ? Icons.star : Icons.star_border,
                    size: 24,
                    color: star <= value ? AppColors.safetyWarning : AppColors.secondaryLight,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final success = await ref
        .read(companionReviewControllerProvider.notifier)
        .submitReview(
          tripId: widget.tripId,
          reviewerId: widget.reviewerId,
          revieweeId: widget.revieweeId,
          communicationRating: _commRating,
          punctualityRating: _puncRating,
          respectRating: _respRating,
          planningRating: _planRating,
          comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your companion review has been recorded.'),
            backgroundColor: AppColors.primary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit review. Please try again.'),
            backgroundColor: AppColors.safetyAlert,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('Review ${widget.revieweeName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your honest feedback helps build a trusted travel network for everyone.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.secondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            _buildRatingRow('Communication', _commRating, (v) => setState(() => _commRating = v)),
            _buildRatingRow('Punctuality', _puncRating, (v) => setState(() => _puncRating = v)),
            _buildRatingRow('Respect & Safety', _respRating, (v) => setState(() => _respRating = v)),
            _buildRatingRow('Trip Planning', _planRating, (v) => setState(() => _planRating = v)),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Optional comments',
                hintText: 'Share how well you coordinated...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit Review'),
        ),
      ],
    );
  }
}
