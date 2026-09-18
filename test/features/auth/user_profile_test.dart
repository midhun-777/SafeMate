import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/auth/domain/models/account_state.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';

void main() {
  group('UserProfile Model Tests', () {
    test('instantiates with default values', () {
      final now = DateTime.now();
      final profile = UserProfile(
        id: 'usr-123',
        displayName: 'Sam Traveler',
        createdAt: now,
        updatedAt: now,
      );

      expect(profile.id, equals('usr-123'));
      expect(profile.displayName, equals('Sam Traveler'));
      expect(profile.trustScore, equals(0));
      expect(profile.tripsCompleted, equals(0));
      expect(profile.reliabilityRating, equals(5.0));
      expect(profile.languages, isEmpty);
      expect(profile.travelStyles, isEmpty);
      expect(profile.isProfileComplete, isTrue);
    });

    test('evaluates isProfileComplete correctly', () {
      final now = DateTime.now();
      final defaultProfile = UserProfile(
        id: 'usr-default',
        displayName: 'Traveler',
        createdAt: now,
        updatedAt: now,
      );
      expect(defaultProfile.isProfileComplete, isFalse);

      final customProfile = UserProfile(
        id: 'usr-custom',
        displayName: 'Elena Rostova',
        createdAt: now,
        updatedAt: now,
      );
      expect(customProfile.isProfileComplete, isTrue);

      final emptyProfile = UserProfile(
        id: 'usr-empty',
        displayName: '   ',
        createdAt: now,
        updatedAt: now,
      );
      expect(emptyProfile.isProfileComplete, isFalse);
    });

    test('serializes to and from JSON symmetrically', () {
      final now = DateTime.utc(2026, 9, 15, 12, 0, 0);
      final original = UserProfile(
        id: 'profile-abc',
        displayName: 'Maya Lin',
        bio: 'Solo backpacker exploring mountains.',
        avatarUrl: 'https://example.com/avatar.jpg',
        languages: ['English', 'Spanish'],
        travelStyles: ['Adventure', 'Budget'],
        trustScore: 85,
        tripsCompleted: 4,
        reliabilityRating: 4.8,
        createdAt: now,
        updatedAt: now,
      );

      final json = original.toJson();
      final reconstructed = UserProfile.fromJson(json);

      expect(reconstructed.id, equals(original.id));
      expect(reconstructed.displayName, equals(original.displayName));
      expect(reconstructed.bio, equals(original.bio));
      expect(reconstructed.avatarUrl, equals(original.avatarUrl));
      expect(reconstructed.languages, equals(['English', 'Spanish']));
      expect(reconstructed.travelStyles, equals(['Adventure', 'Budget']));
      expect(reconstructed.trustScore, equals(85));
      expect(reconstructed.tripsCompleted, equals(4));
      expect(reconstructed.reliabilityRating, closeTo(4.8, 0.01));
    });

    test('copyWith updates fields without mutating unchanged fields', () {
      final now = DateTime.now();
      final original = UserProfile(
        id: 'profile-xyz',
        displayName: 'Initial Name',
        trustScore: 10,
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(
        displayName: 'Updated Name',
        trustScore: 25,
      );

      expect(updated.id, equals('profile-xyz'));
      expect(updated.displayName, equals('Updated Name'));
      expect(updated.trustScore, equals(25));
      expect(updated.createdAt, equals(original.createdAt));
    });

    test('AccountState enum flags reflect active and restricted states', () {
      expect(AccountState.profileComplete.isActive, isTrue);
      expect(AccountState.profileIncomplete.isActive, isTrue);
      expect(AccountState.newUser.isActive, isFalse);
      expect(AccountState.suspended.isActive, isFalse);

      expect(AccountState.suspended.isRestricted, isTrue);
      expect(AccountState.blocked.isRestricted, isTrue);
      expect(AccountState.profileComplete.isRestricted, isFalse);
    });
  });
}
