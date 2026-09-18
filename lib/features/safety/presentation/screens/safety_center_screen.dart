import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/safety_controllers.dart';
import '../widgets/verification_badge.dart';

/// Main Hub for SafeMate Trust & Safety Foundation.
/// Universal Engineering Rule #11: Safety is a core product capability.
class SafetyCenterScreen extends ConsumerWidget {
  const SafetyCenterScreen({super.key});

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String statusText,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
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
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSafetyGuidelines(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.shield, color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Community Safety Guidelines',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'SafeMate is built on radical accountability, privacy-first design, and mutual traveler respect.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                _buildGuidelineItem(
                  '1. Public Meetups First',
                  'Always conduct your initial greeting in a busy, well-lit, public location like a transit station concourse or airport lounge.',
                ),
                _buildGuidelineItem(
                  '2. No Advance Money Transfers',
                  'Never wire funds, pay advance deposits, or exchange booking fees with companions. Each traveler purchases their own transport tickets.',
                ),
                _buildGuidelineItem(
                  '3. Verify Meetup Codes',
                  'Use our 6-digit cryptographic meetup code on arrival to confirm identity before departing together.',
                ),
                _buildGuidelineItem(
                  '4. Inform Trusted Contacts',
                  'Configure at least one trusted contact so your journey departure is automatically noted.',
                ),
                _buildGuidelineItem(
                  '5. Keep Communication on SafeMate',
                  'Maintain travel coordination inside the app so safety advisories and records protect you.',
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Understood & Agreed'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Widget _buildGuidelineItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: const TextStyle(color: AppColors.secondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final verState = ref.watch(verificationControllerProvider);
    final contactsState = ref.watch(trustedContactsControllerProvider);
    final privacyState = ref.watch(privacySettingsControllerProvider);

    final isIdVerified = authState.profile?.isVerified ?? false;
    final isPhoneVerified = authState.profile?.isPhoneVerified ?? false;
    final contactsCount = contactsState.contacts.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety & Trust Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Safety Guidelines',
            onPressed: () => _showSafetyGuidelines(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Trust Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Traveler Trust Shield',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    VerificationBadge(
                      isVerified: isIdVerified,
                      isPhoneVerified: isPhoneVerified,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Multi-layered verification, trusted contact alerts, and cryptographic meetup codes ensure safer journeys.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    final uid = authState.profile?.id ?? authState.session?.userId;
                    if (uid != null) {
                      context.push('/profile/trust?userId=$uid');
                    }
                  },
                  icon: const Icon(Icons.badge_outlined, color: Colors.white, size: 18),
                  label: const Text(
                    'View My Trust Profile',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Safety Controls',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // 1. Identity Verification
          _buildFeatureCard(
            context,
            icon: Icons.verified_user_outlined,
            iconColor: AppColors.primary,
            title: 'Identity Verification',
            subtitle: 'Government ID match and selfie liveness verification',
            statusText: isIdVerified
                ? 'Status: Verified'
                : (verState.isLoading ? 'Checking status...' : 'Status: Unverified — Verify Now'),
            onTap: () => context.push('/safety/verification'),
          ),

          // 2. Trusted Contacts
          _buildFeatureCard(
            context,
            icon: Icons.contact_phone_outlined,
            iconColor: AppColors.secondary,
            title: 'Trusted Safety Contacts',
            subtitle: 'Notify designated loved ones when your journeys begin',
            statusText: '$contactsCount of 5 contacts configured',
            onTap: () => context.push('/safety/trusted-contacts'),
          ),

          // 3. Privacy & Visibility
          _buildFeatureCard(
            context,
            icon: Icons.lock_outline,
            iconColor: AppColors.primaryLight,
            title: 'Privacy & Visibility',
            subtitle: 'Control profile discovery and coarse geohash precision',
            statusText: privacyState.value?.coarseLocationOnly == true
                ? 'Coarse location active (20km privacy radius)'
                : 'Privacy settings active',
            onTap: () => context.push('/safety/privacy'),
          ),

          // 4. Pre-Journey Safety & Meetup Code
          _buildFeatureCard(
            context,
            icon: Icons.checklist_rtl_rounded,
            iconColor: AppColors.safetyActive,
            title: 'Pre-Journey Safety & Meetup Code',
            subtitle: '6-point safety checklist and secure 6-digit meetup code',
            statusText: 'Checklist & Code Generator ready',
            onTap: () => context.push('/trips/active/safety-check'),
          ),

          // 5. Reporting & Help
          _buildFeatureCard(
            context,
            icon: Icons.report_problem_outlined,
            iconColor: AppColors.safetyAlert,
            title: 'Report a Concern or Block User',
            subtitle: 'Confidential safety reporting and instantaneous blocking',
            statusText: '24/7 Safety Review Team',
            onTap: () => context.push('/safety/report'),
          ),
        ],
      ),
    );
  }
}
