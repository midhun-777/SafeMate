import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/profile/domain/models/profile_visibility.dart';
import 'package:safemate/features/safety/domain/models/privacy_settings.dart';

void main() {
  group('PrivacySettings Model', () {
    test('Defaults enforce privacy-first settings', () {
      final defaults = PrivacySettings.defaults('user-123');

      expect(defaults.userId, 'user-123');
      expect(defaults.profileVisibility, ProfileVisibility.publicToMatches);
      expect(defaults.showTripsPublicly, true);
      expect(defaults.coarseLocationOnly, true); // Strict privacy default
      expect(defaults.showOnlinePresence, true);
      expect(defaults.allowCompanionRequests, true);
    });

    test('copyWith modifies settings without altering unchanged fields', () {
      final initial = PrivacySettings.defaults('user-123');
      final updated = initial.copyWith(
        profileVisibility: ProfileVisibility.hidden,
        coarseLocationOnly: false,
      );

      expect(updated.userId, 'user-123');
      expect(updated.profileVisibility, ProfileVisibility.hidden);
      expect(updated.coarseLocationOnly, false);
      expect(updated.showOnlinePresence, true);
    });

    test('Serialization and deserialization', () {
      final original = PrivacySettings(
        userId: 'user-789',
        profileVisibility: ProfileVisibility.private,
        showTripsPublicly: false,
        coarseLocationOnly: true,
        showOnlinePresence: false,
        allowCompanionRequests: false,
        updatedAt: DateTime(2026, 1, 1),
      );

      final json = original.toJson();
      expect(json['user_id'], 'user-789');
      expect(json['profile_visibility'], 'private');
      expect(json['coarse_location_only'], true);

      final reconstructed = PrivacySettings.fromJson(json);
      expect(reconstructed.userId, original.userId);
      expect(reconstructed.profileVisibility, ProfileVisibility.private);
      expect(reconstructed.showTripsPublicly, false);
      expect(reconstructed.coarseLocationOnly, true);
      expect(reconstructed.showOnlinePresence, false);
    });
  });
}
