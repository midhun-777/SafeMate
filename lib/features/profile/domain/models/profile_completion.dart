import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'travel_personality.dart';
import 'travel_preferences.dart';

/// Completion assessment and actionable tips for SafeMate profile setup.
/// Universal Engineering Rule #11: Deterministic, testable profile completion calculations.
class ProfileCompletion {
  final int percentage;
  final List<String> missingSuggestions;
  final bool isMinimalComplete;

  const ProfileCompletion({
    required this.percentage,
    required this.missingSuggestions,
    required this.isMinimalComplete,
  });

  bool get isFullyComplete => percentage >= 100;

  String get tierLabel {
    if (percentage >= 90) return 'Complete';
    if (percentage >= 70) return 'Established';
    if (percentage >= 40) return 'Growing';
    return 'Starter';
  }

  /// Calculates profile completion percentage and determines missing suggestions.
  static ProfileCompletion calculate({
    required UserProfile profile,
    TravelPreferences? preferences,
  }) {
    int score = 0;
    final suggestions = <String>[];

    // 1. Basic Identity (60% weight)
    final hasValidName = profile.displayName.trim().isNotEmpty &&
        profile.displayName.trim() != 'Traveler';
    if (hasValidName) {
      score += 20;
    } else {
      suggestions.add('Add your real full or display name.');
    }

    if (profile.bio?.trim().isNotEmpty == true) {
      score += 10;
    } else {
      suggestions.add('Write a brief bio about what kind of trips you enjoy.');
    }

    if (profile.avatarUrl?.trim().isNotEmpty == true) {
      score += 10;
    } else {
      suggestions.add('Upload a profile photo to build visual trust.');
    }

    if (profile.homeCity?.trim().isNotEmpty == true) {
      score += 10;
    } else {
      suggestions.add('Add your home city or region for local companion matching.');
    }

    if (profile.languages.isNotEmpty) {
      score += 10;
    } else {
      suggestions.add('List the languages you speak to ease on-trip communication.');
    }

    // 2. Travel Personality (25% weight)
    if (profile.travelStyles.isNotEmpty) {
      score += 15;
    } else {
      suggestions.add('Select your trip vibes (relaxed, adventure, culture, etc.).');
    }

    if (preferences != null && preferences.travelPace != TravelPace.flexible) {
      score += 10;
    } else {
      suggestions.add('Set your preferred travel pace (slow, balanced, or fast).');
    }

    // 3. Travel Preferences (15% weight)
    if (preferences != null && preferences.budgetTier != BudgetTier.notSpecified && preferences.budgetTier != BudgetTier.flexible) {
      score += 5;
    } else {
      suggestions.add('Specify your general travel budget tier.');
    }

    if (preferences != null && preferences.preferredTransport.isNotEmpty) {
      score += 5;
    } else {
      suggestions.add('Pick your preferred modes of transport.');
    }

    if (preferences != null && preferences.activityInterests.isNotEmpty) {
      score += 5;
    } else {
      suggestions.add('Choose your favorite activity interests.');
    }

    final finalPercentage = score.clamp(0, 100);

    return ProfileCompletion(
      percentage: finalPercentage,
      missingSuggestions: suggestions,
      isMinimalComplete: hasValidName,
    );
  }
}
