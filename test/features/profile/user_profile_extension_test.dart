import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/profile/domain/models/profile_visibility.dart';

void main() {
  group('UserProfile Phase 5 Extensions', () {
    test('instantiates with new homeCity, visibility, and completionPercentage', () {
      final now = DateTime.now();
      final profile = UserProfile(
        id: 'usr-p5',
        displayName: 'Maya Patel',
        homeCity: 'San Francisco, CA',
        visibility: ProfileVisibility.private,
        completionPercentage: 85,
        createdAt: now,
        updatedAt: now,
      );

      expect(profile.id, equals('usr-p5'));
      expect(profile.displayName, equals('Maya Patel'));
      expect(profile.homeCity, equals('San Francisco, CA'));
      expect(profile.visibility, equals(ProfileVisibility.private));
      expect(profile.completionPercentage, equals(85));
    });

    test('serializes and deserializes new Phase 5 fields symmetrically', () {
      final now = DateTime.utc(2026, 9, 15, 12, 0, 0);
      final original = UserProfile(
        id: 'usr-p5-json',
        displayName: 'Elena Gomez',
        bio: 'Solo hiker & architecture lover.',
        avatarUrl: 'https://example.com/elena.jpg',
        homeCity: 'Barcelona, Spain',
        languages: ['Spanish', 'English', 'Catalan'],
        travelStyles: ['adventure', 'food_culture'],
        visibility: ProfileVisibility.hidden,
        completionPercentage: 90,
        trustScore: 75,
        tripsCompleted: 3,
        reliabilityRating: 4.9,
        createdAt: now,
        updatedAt: now,
      );

      final json = original.toJson();
      expect(json['home_city'], equals('Barcelona, Spain'));
      expect(json['profile_visibility'], equals('hidden'));
      expect(json['profile_completion_percentage'], equals(90));

      final restored = UserProfile.fromJson(json);
      expect(restored.homeCity, equals(original.homeCity));
      expect(restored.visibility, equals(original.visibility));
      expect(restored.completionPercentage, equals(original.completionPercentage));
      expect(restored.languages, equals(['Spanish', 'English', 'Catalan']));
      expect(restored.travelStyles, equals(['adventure', 'food_culture']));
    });

    test('copyWith updates new fields while preserving unchanged values', () {
      final now = DateTime.now();
      final original = UserProfile(
        id: 'usr-copy',
        displayName: 'Original Name',
        homeCity: 'Berlin',
        visibility: ProfileVisibility.publicToMatches,
        completionPercentage: 50,
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(
        homeCity: 'Munich',
        visibility: ProfileVisibility.private,
        completionPercentage: 70,
      );

      expect(updated.displayName, equals('Original Name'));
      expect(updated.homeCity, equals('Munich'));
      expect(updated.visibility, equals(ProfileVisibility.private));
      expect(updated.completionPercentage, equals(70));
    });

    test('ProfileVisibility enum helpers work as expected', () {
      expect(ProfileVisibility.fromCode('private'), equals(ProfileVisibility.private));
      expect(ProfileVisibility.fromCode('hidden'), equals(ProfileVisibility.hidden));
      expect(ProfileVisibility.fromCode('public_to_matches'), equals(ProfileVisibility.publicToMatches));
      expect(ProfileVisibility.fromCode('unknown'), equals(ProfileVisibility.publicToMatches));
      expect(ProfileVisibility.fromCode(null), equals(ProfileVisibility.publicToMatches));
    });
  });
}
