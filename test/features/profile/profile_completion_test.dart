import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/profile/domain/models/profile_completion.dart';
import 'package:safemate/features/profile/domain/models/travel_personality.dart';
import 'package:safemate/features/profile/domain/models/travel_preferences.dart';

void main() {
  group('ProfileCompletion Deterministic Calculation Tests', () {
    test('calculates 0% for blank or default Traveler profile', () {
      final now = DateTime.now();
      final blankProfile = UserProfile(
        id: 'usr-blank',
        displayName: 'Traveler',
        createdAt: now,
        updatedAt: now,
      );

      final completion = ProfileCompletion.calculate(
        profile: blankProfile,
        preferences: TravelPreferences.empty('usr-blank'),
      );

      expect(completion.percentage, equals(0));
      expect(completion.isMinimalComplete, isFalse);
      expect(completion.tierLabel, equals('Starter'));
      expect(completion.missingSuggestions, contains('Add your real full or display name.'));
    });

    test('calculates 20% when only valid display name is provided', () {
      final now = DateTime.now();
      final nameOnlyProfile = UserProfile(
        id: 'usr-name',
        displayName: 'Aria Stark',
        createdAt: now,
        updatedAt: now,
      );

      final completion = ProfileCompletion.calculate(
        profile: nameOnlyProfile,
        preferences: TravelPreferences.empty('usr-name'),
      );

      expect(completion.percentage, equals(20));
      expect(completion.isMinimalComplete, isTrue);
      expect(completion.missingSuggestions, isNot(contains('Add your real full or display name.')));
      expect(completion.missingSuggestions, contains('Write a brief bio about what kind of trips you enjoy.'));
    });

    test('calculates 60% for complete basic identity', () {
      final now = DateTime.now();
      final identityProfile = UserProfile(
        id: 'usr-id',
        displayName: 'Lucas Vance',
        bio: 'Avid mountaineer and photographer.',
        homeCity: 'Vancouver, BC',
        avatarUrl: 'https://example.com/lucas.jpg',
        languages: ['English', 'French'],
        createdAt: now,
        updatedAt: now,
      );

      final completion = ProfileCompletion.calculate(
        profile: identityProfile,
        preferences: TravelPreferences.empty('usr-id'),
      );

      expect(completion.percentage, equals(60));
      expect(completion.tierLabel, equals('Growing'));
    });

    test('calculates 85% when identity and travel personality are complete', () {
      final now = DateTime.now();
      final partialProfile = UserProfile(
        id: 'usr-part',
        displayName: 'Lucas Vance',
        bio: 'Avid mountaineer and photographer.',
        homeCity: 'Vancouver, BC',
        avatarUrl: 'https://example.com/lucas.jpg',
        languages: ['English', 'French'],
        travelStyles: ['adventure', 'nature'],
        createdAt: now,
        updatedAt: now,
      );

      final prefs = TravelPreferences.empty('usr-part').copyWith(
        travelPace: TravelPace.moderate,
      );

      final completion = ProfileCompletion.calculate(
        profile: partialProfile,
        preferences: prefs,
      );

      // Identity 60 + Styles 15 + Pace 10 = 85%
      expect(completion.percentage, equals(85));
      expect(completion.tierLabel, equals('Established'));
    });

    test('calculates 100% when all categories are completed', () {
      final now = DateTime.now();
      final fullProfile = UserProfile(
        id: 'usr-full',
        displayName: 'Lucas Vance',
        bio: 'Avid mountaineer and photographer.',
        homeCity: 'Vancouver, BC',
        avatarUrl: 'https://example.com/lucas.jpg',
        languages: ['English', 'French'],
        travelStyles: ['adventure', 'nature'],
        createdAt: now,
        updatedAt: now,
      );

      final fullPrefs = TravelPreferences.empty('usr-full').copyWith(
        travelPace: TravelPace.slow,
        budgetTier: BudgetTier.budget,
        preferredTransport: ['Train'],
        activityInterests: ['Hiking'],
      );

      final completion = ProfileCompletion.calculate(
        profile: fullProfile,
        preferences: fullPrefs,
      );

      expect(completion.percentage, equals(100));
      expect(completion.isFullyComplete, isTrue);
      expect(completion.tierLabel, equals('Complete'));
      expect(completion.missingSuggestions, isEmpty);
    });
  });
}
