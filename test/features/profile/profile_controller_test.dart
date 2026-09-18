import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/profile/data/repositories/supabase_profile_repository.dart';
import 'package:safemate/features/profile/domain/models/travel_personality.dart';
import 'package:safemate/features/profile/domain/models/travel_preferences.dart';
import 'package:safemate/features/profile/presentation/controllers/profile_controller.dart';

void main() {
  group('ProfileController State Machine Tests', () {
    late ProviderContainer container;
    late SupabaseProfileRepository mockRepo;
    const testUserId = 'test-controller-user';

    setUp(() async {
      mockRepo = SupabaseProfileRepository();
      container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      // Seed initial profile in mock repo
      await mockRepo.saveProfile(
        UserProfile(
          id: testUserId,
          displayName: 'Initial Traveler',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state loads seeded profile and calculates completion', () async {
      final controller = ProfileController(mockRepo, testUserId);
      await controller.loadProfile();

      expect(controller.state.profile.displayName, equals('Initial Traveler'));
      expect(controller.state.completion.percentage, greaterThan(0));
      expect(controller.state.currentStep, equals(0));
    });

    test('updates basic identity fields and recalculates completion dynamically', () async {
      final controller = ProfileController(mockRepo, testUserId);
      await controller.loadProfile();
      final initialCompletion = controller.state.completion.percentage;

      controller.setBio('Passionate solo traveler.');
      controller.setHomeCity('Sydney, Australia');
      controller.toggleLanguage('English');

      expect(controller.state.profile.bio, equals('Passionate solo traveler.'));
      expect(controller.state.profile.homeCity, equals('Sydney, Australia'));
      expect(controller.state.profile.languages, contains('English'));
      expect(controller.state.completion.percentage, greaterThan(initialCompletion));
      expect(controller.state.isDirty, isTrue);
    });

    test('updates travel personality and preference fields', () async {
      final controller = ProfileController(mockRepo, testUserId);
      await controller.loadProfile();

      controller.toggleTravelStyle(TripVibe.adventure.code);
      controller.setTravelPace(TravelPace.slow);
      controller.setBudgetTier(BudgetTier.budget);
      controller.setAccommodation(AccommodationStyle.hostel);

      expect(controller.state.profile.travelStyles, contains('adventure'));
      expect(controller.state.preferences.travelPace, equals(TravelPace.slow));
      expect(controller.state.preferences.budgetTier, equals(BudgetTier.budget));
      expect(controller.state.preferences.accommodationPreference, equals(AccommodationStyle.hostel));
    });

    test('wizard step navigation transitions correctly', () async {
      final controller = ProfileController(mockRepo, testUserId);
      expect(controller.state.currentStep, equals(0));

      controller.nextStep();
      expect(controller.state.currentStep, equals(1));

      controller.nextStep();
      expect(controller.state.currentStep, equals(2));

      controller.previousStep();
      expect(controller.state.currentStep, equals(1));

      controller.setStep(3);
      expect(controller.state.currentStep, equals(3));
    });

    test('saveDraft persists changes to repository and clears isDirty', () async {
      final controller = ProfileController(mockRepo, testUserId);
      await controller.loadProfile();

      controller.setDisplayName('Alex Traveler');
      controller.setHomeCity('Berlin, Germany');
      expect(controller.state.isDirty, isTrue);

      final success = await controller.saveDraft();
      expect(success, isTrue);
      expect(controller.state.isDirty, isFalse);
      expect(controller.state.successMessage, isNotNull);

      // Verify in repository
      final savedProfile = await mockRepo.getProfile(testUserId);
      expect(savedProfile?.displayName, equals('Alex Traveler'));
      expect(savedProfile?.homeCity, equals('Berlin, Germany'));
    });

    test('completeProfileSetup blocks completion if display name is invalid', () async {
      final controller = ProfileController(mockRepo, testUserId);
      await controller.loadProfile();

      controller.setDisplayName(''); // Invalid empty name

      final success = await controller.completeProfileSetup();
      expect(success, isFalse);
      expect(controller.state.errorMessage, contains('display name'));
    });
  });
}
