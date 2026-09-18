import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/auth_button.dart';

/// Calm, modern welcome screen for SafeMate.
/// Universal Engineering Rule #18: Premium, calm, trustworthy, avoid dating-app clichés.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Brand Icon & Identity
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Icon(
                    Icons.explore_outlined,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'SafeMate',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Find compatible, verified travel companions\nand journey together safely.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 28),

              // Trust pillars
              _buildFeaturePillar(
                icon: Icons.verified_user_outlined,
                title: 'Verified Travelers',
                subtitle: 'Government ID & factual community trust scores',
                isDark: isDark,
              ),
              const SizedBox(height: 14),
              _buildFeaturePillar(
                icon: Icons.timeline_outlined,
                title: 'Route-Matched Companions',
                subtitle: 'Match strictly by itinerary dates, destination & travel style',
                isDark: isDark,
              ),
              const SizedBox(height: 14),
              _buildFeaturePillar(
                icon: Icons.shield_outlined,
                title: 'SafeTrip Live Monitoring',
                subtitle: 'Proactive check-ins, automated alerts & emergency contacts',
                isDark: isDark,
              ),

              const SizedBox(height: 32),

              // Action buttons
              AuthButton(
                text: 'Create Account',
                onPressed: () => context.go('/auth/sign-up'),
              ),
              const SizedBox(height: 12),
              AuthButton(
                text: 'Sign In',
                isSecondary: true,
                onPressed: () => context.go('/auth/sign-in'),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => context.go('/auth/phone'),
                child: Text(
                  'Continue with Phone Number',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturePillar({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
