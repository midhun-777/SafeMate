import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/errors/app_exception.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/profile/data/repositories/supabase_profile_repository.dart';
import 'package:safemate/features/profile/domain/models/travel_personality.dart';
import 'package:safemate/features/profile/domain/models/travel_preferences.dart';

void main() {
  group('SupabaseProfileRepository (Mock/Development Mode Tests)', () {
    late SupabaseProfileRepository repository;

    setUp(() {
      repository = SupabaseProfileRepository();
    });

    test('getProfile returns default profile when not previously saved', () async {
      final profile = await repository.getProfile('usr-test-1');
      expect(profile, isNotNull);
      expect(profile?.displayName, equals('Traveler'));
    });

    test('saveProfile persists and returns updated profile', () async {
      final now = DateTime.now();
      final profile = UserProfile(
        id: 'usr-save-1',
        displayName: 'Dev Traveler',
        homeCity: 'Kyoto, Japan',
        languages: ['Japanese', 'English'],
        createdAt: now,
        updatedAt: now,
      );

      final saved = await repository.saveProfile(profile);
      expect(saved.id, equals('usr-save-1'));
      expect(saved.displayName, equals('Dev Traveler'));
      expect(saved.homeCity, equals('Kyoto, Japan'));

      final retrieved = await repository.getProfile('usr-save-1');
      expect(retrieved?.homeCity, equals('Kyoto, Japan'));
      expect(retrieved?.languages, equals(['Japanese', 'English']));
    });

    test('saveTravelPreferences persists and returns updated preferences', () async {
      final now = DateTime.now();
      final prefs = TravelPreferences(
        id: 'pref-save-1',
        userId: 'usr-save-1',
        travelPace: TravelPace.slow,
        budgetTier: BudgetTier.budget,
        activityInterests: ['Local Markets', 'Street Food'],
        createdAt: now,
        updatedAt: now,
      );

      final saved = await repository.saveTravelPreferences(prefs);
      expect(saved.travelPace, equals(TravelPace.slow));
      expect(saved.activityInterests, contains('Street Food'));

      final retrieved = await repository.getTravelPreferences('usr-save-1');
      expect(retrieved?.travelPace, equals(TravelPace.slow));
      expect(retrieved?.activityInterests, contains('Local Markets'));
    });

    test('uploadProfilePhoto succeeds for valid size and supported extension', () async {
      final validBytes = [1, 2, 3, 4, 5];
      final url = await repository.uploadProfilePhoto(
        userId: 'usr-photo-1',
        bytes: validBytes,
        filename: 'avatar.jpg',
      );

      expect(url, contains('usr-photo-1'));
    });

    test('uploadProfilePhoto rejects files larger than 2MB', () async {
      // 2MB + 1 byte
      final oversizedBytes = List<int>.filled(2 * 1024 * 1024 + 1, 0);

      expect(
        () => repository.uploadProfilePhoto(
          userId: 'usr-photo-2',
          bytes: oversizedBytes,
          filename: 'large.jpg',
        ),
        throwsA(isA<AppException>().having((e) => e.message, 'message', contains('2MB'))),
      );
    });

    test('uploadProfilePhoto rejects unsupported file extensions', () async {
      final bytes = [1, 2, 3];

      expect(
        () => repository.uploadProfilePhoto(
          userId: 'usr-photo-3',
          bytes: bytes,
          filename: 'avatar.exe',
        ),
        throwsA(isA<AppException>().having((e) => e.message, 'message', contains('Unsupported format'))),
      );
    });

    test('deleteProfilePhoto completes without throwing', () async {
      expect(repository.deleteProfilePhoto('usr-photo-1'), completes);
    });
  });
}
