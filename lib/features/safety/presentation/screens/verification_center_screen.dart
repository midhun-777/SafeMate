import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/models/verification_models.dart';
import '../controllers/safety_controllers.dart';
import '../widgets/verification_badge.dart';

/// Screen for managing and completing Identity and Phone Verification.
/// Universal Engineering Rule #11: Safety is a core product capability.
/// Universal Engineering Rule #10: Privacy and consent are first-class design constraints.
class VerificationCenterScreen extends ConsumerStatefulWidget {
  const VerificationCenterScreen({super.key});

  @override
  ConsumerState<VerificationCenterScreen> createState() => _VerificationCenterScreenState();
}

class _VerificationCenterScreenState extends ConsumerState<VerificationCenterScreen> {
  bool _isProcessing = false;

  Future<void> _handleStartVerification(VerificationType type) async {
    setState(() => _isProcessing = true);
    final controller = ref.read(verificationControllerProvider.notifier);
    final record = await controller.startVerification(type);

    if (record != null && mounted) {
      // In development / prototype mode, simulate successful verification approval
      final approved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Complete ${type.displayName}'),
          content: Text(
            'SafeMate connects to certified ID verification providers.\n\n'
            'For this demonstration, would you like to simulate successful verification of your ${type.displayName}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Simulate Failure'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Simulate Approval'),
            ),
          ],
        ),
      );

      if (approved != null && mounted) {
        await controller.completeVerification(
          recordId: record.id,
          approved: approved,
          failureReason: approved ? null : 'Simulated verification decline',
        );

        // Refresh user profile state
        ref.read(authControllerProvider.notifier).refreshProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                approved
                    ? '${type.displayName} verified successfully!'
                    : 'Verification was not completed.',
              ),
              backgroundColor: approved ? AppColors.primary : AppColors.safetyAlert,
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Widget _buildVerificationCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isVerified,
    required VerificationStatus status,
    required VoidCallback onVerify,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isVerified
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : (isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isVerified ? AppColors.primary : AppColors.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      VerificationBadge(
                        isVerified: isVerified,
                        customLabel: isVerified ? 'Verified' : status.displayName,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            if (!isVerified)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isProcessing ? null : onVerify,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text('Verify $title'),
                ),
              )
            else
              Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Active and verified',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final verState = ref.watch(verificationControllerProvider);
    final authState = ref.watch(authControllerProvider);

    final isIdVerified = authState.profile?.isVerified ??
        (verState.identityVerification?.status == VerificationStatus.verified);
    final isPhoneVerified = authState.profile?.isPhoneVerified ??
        (verState.phoneVerification?.status == VerificationStatus.verified);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity & Trust Verification'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Privacy and Data Protection Notice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceVariantDark.withValues(alpha: 0.5)
                  : AppColors.surfaceVariantLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.privacy_tip_outlined, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Privacy is Guaranteed',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SafeMate NEVER stores raw government documents, passport scans, or national ID numbers. We store only cryptographic verification confirmation hashes.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 1. Phone Verification Card
          _buildVerificationCard(
            title: 'Phone Number',
            description:
                'Authenticates your mobile phone number via secure one-time verification code.',
            icon: Icons.phone_iphone,
            isVerified: isPhoneVerified,
            status: verState.phoneVerification?.status ?? VerificationStatus.notStarted,
            onVerify: () => _handleStartVerification(VerificationType.phone),
          ),

          // 2. Government ID & Selfie Card
          _buildVerificationCard(
            title: 'Government ID & Selfie Liveness',
            description:
                'Verifies official government identification and biometric selfie liveness to prevent impersonation and fake profiles.',
            icon: Icons.badge_outlined,
            isVerified: isIdVerified,
            status: verState.identityVerification?.status ?? VerificationStatus.notStarted,
            onVerify: () => _handleStartVerification(VerificationType.governmentId),
          ),

          const SizedBox(height: 12),
          // Disclaimer
          Center(
            child: Text(
              'Identity verification confirms identity record validity. SafeMate does not guarantee future conduct. Always follow Community Safety Guidelines.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
