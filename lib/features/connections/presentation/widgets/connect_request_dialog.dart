/// SafeMate Connect Request Confirmation Dialog.
/// Universal Engineering Rule #6: Strict domain boundaries, privacy-safe identity.
/// Flow: DISCOVER -> UNDERSTAND -> REQUEST (Confirmation) -> MUTUAL ACCEPTANCE.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../controllers/connection_controllers.dart';

class ConnectRequestDialog extends ConsumerStatefulWidget {
  final String candidateUserId;
  final String candidateName;
  final String destination;
  final String userTripId;
  final String? candidateTripId;
  final String currentUserId;

  const ConnectRequestDialog({
    super.key,
    required this.candidateUserId,
    required this.candidateName,
    required this.destination,
    required this.userTripId,
    this.candidateTripId,
    required this.currentUserId,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String candidateUserId,
    required String candidateName,
    required String destination,
    required String userTripId,
    String? candidateTripId,
    required String currentUserId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConnectRequestDialog(
        candidateUserId: candidateUserId,
        candidateName: candidateName,
        destination: destination,
        userTripId: userTripId,
        candidateTripId: candidateTripId,
        currentUserId: currentUserId,
      ),
    );
  }

  @override
  ConsumerState<ConnectRequestDialog> createState() => _ConnectRequestDialogState();
}

class _ConnectRequestDialogState extends ConsumerState<ConnectRequestDialog> {
  bool _isSending = false;
  String? _errorMessage;

  Future<void> _handleSend() async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    final controller = ref.read(connectionActionControllerProvider.notifier);
    final result = await controller.sendRequest(
      requesterId: widget.currentUserId,
      receiverId: widget.candidateUserId,
      requesterTripId: widget.userTripId,
      recipientTripId: widget.candidateTripId,
    );

    if (!mounted) return;

    if (result != null) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection request sent to ${widget.candidateName}.'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      final state = ref.read(connectionActionControllerProvider);
      setState(() {
        _isSending = false;
        _errorMessage = state.error?.toString() ?? 'Unable to send request. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Connect with ${widget.candidateName}?',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Travel coordination description
          Text(
            "You're both planning a journey to ${widget.destination}. Send a connection request to coordinate travel details and prepare together safely.",
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 16),

          // Privacy note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your private contact details will not be shared. Chat unlocks only upon mutual acceptance.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],

          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSending ? null : () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSending ? null : _handleSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Send Request',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
