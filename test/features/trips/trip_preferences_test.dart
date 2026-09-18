import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/profile/domain/models/travel_personality.dart';
import 'package:safemate/features/profile/domain/models/travel_preferences.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip_preferences.dart';

void main() {
  group('TripPreferences 3-State Model & Serialization Tests', () {
    test('Default TripPreferences has empty collections and empty flag is true', () {
      final prefs = TripPreferences(tripId: 'trip-1');
      expect(prefs.tripId, equals('trip-1'));
      expect(prefs.activityInterests, isEmpty);
      expect(prefs.preferredTransport, isEmpty);
      expect(prefs.dietaryPreferences, isEmpty);
      expect(prefs.hasPreferences, isFalse);
    });

    test('3-State evaluation for activities correctly distinguishes NOT_SPECIFIED vs NOT_SELECTED', () {
      // 1. When no activity interests specified at all -> NOT_SPECIFIED (Rule #4)
      final unconfiguredPrefs = TripPreferences(tripId: 'trip-1', activityInterests: const []);
      expect(
        unconfiguredPrefs.getActivityStatus('Hiking'),
        equals(PreferenceStatus.notSpecified),
      );
      expect(
        unconfiguredPrefs.getActivityStatus('Museums'),
        equals(PreferenceStatus.notSpecified),
      );

      // 2. When traveler explicitly selects 'Hiking'
      final configuredPrefs = TripPreferences(
        tripId: 'trip-1',
        activityInterests: const ['Hiking', 'Photography'],
      );
      expect(
        configuredPrefs.getActivityStatus('Hiking'),
        equals(PreferenceStatus.selected),
      );
      expect(
        configuredPrefs.getActivityStatus('Photography'),
        equals(PreferenceStatus.selected),
      );
      // 'Museums' is not selected, but traveler specified preferences
      expect(
        configuredPrefs.getActivityStatus('Museums'),
        equals(PreferenceStatus.notSelected),
      );
    });

    test('3-State evaluation for transport correctly distinguishes NOT_SPECIFIED vs NOT_SELECTED', () {
      final unconfigured = TripPreferences(tripId: 'trip-2');
      expect(
        unconfigured.getTransportStatus('Train'),
        equals(PreferenceStatus.notSpecified),
      );

      final configured = TripPreferences(
        tripId: 'trip-2',
        preferredTransport: const ['Train'],
      );
      expect(
        configured.getTransportStatus('Train'),
        equals(PreferenceStatus.selected),
      );
      expect(
        configured.getTransportStatus('Bus'),
        equals(PreferenceStatus.notSelected),
      );
    });

    test('3-State evaluation for dietary preferences', () {
      final unconfigured = TripPreferences(tripId: 'trip-3');
      expect(
        unconfigured.getDietaryStatus('Vegetarian'),
        equals(PreferenceStatus.notSpecified),
      );

      final configured = TripPreferences(
        tripId: 'trip-3',
        dietaryPreferences: const ['Vegetarian', 'Vegan'],
      );
      expect(
        configured.getDietaryStatus('Vegetarian'),
        equals(PreferenceStatus.selected),
      );
      expect(
        configured.getDietaryStatus('Halal'),
        equals(PreferenceStatus.notSelected),
      );
    });

    test('TripPreferences serialization and deserialization round-trip', () {
      final original = TripPreferences(
        id: 'pref-123',
        tripId: 'trip-456',
        travelPace: TravelPace.moderate,
        budgetTier: TripBudgetTier.comfortable,
        accommodationPreference: AccommodationStyle.hotel,
        socialEnergy: SocialPreference.smallGroup,
        preferredTransport: const ['Flight', 'Train'],
        activityInterests: const ['Sightseeing', 'Food Walks'],
        dietaryPreferences: const ['Vegetarian'],
        schedulePreference: ScheduleStyle.flexible,
        notes: 'Looking for a calm, friendly companion',
      );


      final json = original.toJson();
      final restored = TripPreferences.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.tripId, equals(original.tripId));
      expect(restored.travelPace, equals(original.travelPace));
      expect(restored.budgetTier, equals(original.budgetTier));
      expect(restored.accommodationPreference, equals(original.accommodationPreference));
      expect(restored.socialEnergy, equals(original.socialEnergy));
      expect(restored.preferredTransport, equals(original.preferredTransport));
      expect(restored.activityInterests, equals(original.activityInterests));
      expect(restored.dietaryPreferences, equals(original.dietaryPreferences));
      expect(restored.schedulePreference, equals(original.schedulePreference));
      expect(restored.notes, equals(original.notes));
      expect(restored.hasPreferences, isTrue);
    });
  });
}
