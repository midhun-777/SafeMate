import 'package:flutter/material.dart';

/// SafeMate Brand Palette.
/// Guided by Universal Engineering Rule #18:
/// "SafeMate must feel: Premium, Calm, Intelligent, Human, Trustworthy, Modern, Simple."
/// Avoids aggressive alarms and dating-app bright neon hues.
class AppColors {
  const AppColors._();

  // Primary Trust Accents (Teal & Navy)
  static const Color primary = Color(0xFF0F766E); // Deep Teal
  static const Color primaryLight = Color(0xFF14B8A6); // Soft Teal
  static const Color primaryDark = Color(0xFF115E59);
  static const Color primaryContainer = Color(0xFFCCFBF1);
  static const Color onPrimaryContainer = Color(0xFF134E4A);

  // Secondary Calm Accents (Slate Indigo)
  static const Color secondary = Color(0xFF475569); // Slate Gray
  static const Color secondaryLight = Color(0xFF64748B);
  static const Color secondaryContainer = Color(0xFFF1F5F9);
  static const Color onSecondaryContainer = Color(0xFF1E293B);

  // Safety & Status Signals (Calm, Informative, Never Panic-Inducing)
  static const Color safetyActive = Color(0xFF059669); // Calm Emerald (Journey Active)
  static const Color safetyWarning = Color(0xFFD97706); // Amber Warning (Check-in Due)
  static const Color safetyAlert = Color(0xFFE11D48); // Rose Alert (SOS)
  static const Color safetyNeutral = Color(0xFF6B7280);

  // Background & Surfaces
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF1F5F9);
  static const Color borderLight = Color(0xFFE2E8F0);

  // Dark Mode Surfaces
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceVariantDark = Color(0xFF334155);
  static const Color borderDark = Color(0xFF334155);

  // Text & Typography
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textTertiaryDark = Color(0xFF64748B);
}
