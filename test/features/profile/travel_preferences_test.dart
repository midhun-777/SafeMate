import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/profile/domain/models/travel_personality.dart';
import 'package:safemate/features/profile/domain/models/travel_preferences.dart';

void main() {
  group('TravelPreferences Model & Data Quality Tests', () {
    test('instantiates with sensible defaults', () {
      final now = DateTime.now();
      final prefs = TravelPreferences(
        id: 'pref-1',
        userId: 'usr-1',
        createdAt: now,
        updatedAt: now,
      );

      expect(prefs.travelPace, equals(TravelPace.flexible));
      expect(prefs.budgetTier, equals(BudgetTier.notSpecified));
      expect(prefs.preferredTransport, isEmpty);
      expect(prefs.accommodationPreference, equals(AccommodationStyle.flexible));
      expect(prefs.socialEnergy, equals(SocialPreference.flexible));
      expect(prefs.dietaryPreferences, isEmpty);
      expect(prefs.activityInterests, isEmpty);
      expect(prefs.planningStyle, equals(PlanningStyle.flexible));
      expect(prefs.schedulePreference, equals(ScheduleStyle.flexible));
    });

    test('serializes and deserializes symmetrically', () {
      final now = DateTime.utc(2026, 9, 15, 12, 0, 0);
      final original = TravelPreferences(
        id: 'pref-json-1',
        userId: 'usr-json-1',
        travelPace: TravelPace.slow,
        budgetTier: BudgetTier.budget,
        preferredTransport: ['Train', 'Bus'],
        accommodationPreference: AccommodationStyle.hostel,
        smokingPreference: 'non_smoker',
        socialEnergy: SocialPreference.social,
        dietaryPreferences: ['Vegetarian'],
        activityInterests: ['Mountain Treks', 'Street Food'],
        planningStyle: PlanningStyle.spontaneous,
        schedulePreference: ScheduleStyle.earlyBird,
        createdAt: now,
        updatedAt: now,
      );

      final json = original.toJson();
      final restored = TravelPreferences.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.userId, equals(original.userId));
      expect(restored.travelPace, equals(TravelPace.slow));
      expect(restored.budgetTier, equals(BudgetTier.budget));
      expect(restored.preferredTransport, equals(['Train', 'Bus']));
      expect(restored.accommodationPreference, equals(AccommodationStyle.hostel));
      expect(restored.socialEnergy, equals(SocialPreference.social));
      expect(restored.dietaryPreferences, equals(['Vegetarian']));
      expect(restored.activityInterests, equals(['Mountain Treks', 'Street Food']));
      expect(restored.planningStyle, equals(PlanningStyle.spontaneous));
      expect(restored.schedulePreference, equals(ScheduleStyle.earlyBird));
    });

    test('distinguishes between SELECTED, NOT_SELECTED, and NOT_SPECIFIED (Rule #6)', () {
      // 1. Unspecified state: user has empty list
      final emptyPrefs = TravelPreferences.empty('usr-unspecified');
      expect(emptyPrefs.getActivityStatus('Hiking'), equals(PreferenceStatus.notSpecified));
      expect(emptyPrefs.getActivityStatus('Beaches'), equals(PreferenceStatus.notSpecified));
      expect(emptyPrefs.getTransportStatus('Train'), equals(PreferenceStatus.notSpecified));
      expect(emptyPrefs.getDietaryStatus('Vegan'), equals(PreferenceStatus.notSpecified));

      // 2. Selected vs Not Selected state
      final specificPrefs = emptyPrefs.copyWith(
        activityInterests: ['Hiking', 'Museums'],
        preferredTransport: ['Train'],
        dietaryPreferences: ['Vegetarian'],
      );

      // Selected items
      expect(specificPrefs.getActivityStatus('Hiking'), equals(PreferenceStatus.selected));
      expect(specificPrefs.getActivityStatus('Museums'), equals(PreferenceStatus.selected));
      expect(specificPrefs.getTransportStatus('Train'), equals(PreferenceStatus.selected));
      expect(specificPrefs.getDietaryStatus('Vegetarian'), equals(PreferenceStatus.selected));

      // Not selected items (user selected others, but omitted these)
      expect(specificPrefs.getActivityStatus('Beaches'), equals(PreferenceStatus.notSelected));
      expect(specificPrefs.getActivityStatus('Nightlife'), equals(PreferenceStatus.notSelected));
      expect(specificPrefs.getTransportStatus('Flight'), equals(PreferenceStatus.notSelected));
      expect(specificPrefs.getDietaryStatus('Vegan'), equals(PreferenceStatus.notSelected));
    });

    test('copyWith properly updates fields without mutating unchanged values', () {
      final original = TravelPreferences.empty('usr-copy');
      final updated = original.copyWith(
        travelPace: TravelPace.fast,
        budgetTier: BudgetTier.comfortable,
        activityInterests: ['Photography'],
      );

      expect(updated.travelPace, equals(TravelPace.fast));
      expect(updated.budgetTier, equals(BudgetTier.comfortable));
      expect(updated.activityInterests, equals(['Photography']));
      expect(updated.userId, equals('usr-copy'));
    });
  });
}
