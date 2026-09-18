import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/trips/data/repositories/supabase_trip_repository.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip_preferences.dart';
import 'package:safemate/features/trips/domain/models/trip_purpose.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';
import 'package:safemate/features/trips/domain/models/trip_transport.dart';

void main() {
  group('SupabaseTripRepository Tests (Dev Offline Cache)', () {
    late SupabaseTripRepository repository;

    setUp(() {
      repository = SupabaseTripRepository();
    });

    test('saveDraft stores a draft trip and allows retrieval', () async {
      final draft = Trip(
        id: 'draft-test-1',
        userId: 'user-abc',
        title: 'Draft Journey to Manali',
        origin: 'Delhi',
        destination: 'Manali',
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2026, 12, 5),
        status: TripStatus.draft,
      );

      final saved = await repository.saveDraft(draft);
      expect(saved.id, equals('draft-test-1'));
      expect(saved.status, equals(TripStatus.draft));

      final retrieved = await repository.getTrip('draft-test-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.origin, equals('Delhi'));
      expect(retrieved.destination, equals('Manali'));
    });

    test('createTrip validates and publishes trip with companion preferences', () async {
      final trip = Trip(
        id: 'pub-test-1',
        userId: 'user-abc',
        title: 'Goa Coastal Getaway',
        origin: 'Mumbai',
        destination: 'Goa',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 7),
        transportMode: TripTransport.flight,
        tripPurpose: TripPurpose.vacation,
        budgetTier: TripBudgetTier.moderate,
        status: TripStatus.published,
      );

      final prefs = TripPreferences(
        tripId: 'pub-test-1',
        activityInterests: const ['Beaches', 'Food Walks'],
      );

      final created = await repository.createTrip(trip, preferences: prefs);
      expect(created.id, equals('pub-test-1'));
      expect(created.status, equals(TripStatus.published));

      final fetchedTrip = await repository.getTrip('pub-test-1');
      expect(fetchedTrip, isNotNull);
      expect(fetchedTrip!.preferences, isNotNull);
      expect(fetchedTrip.preferences!.activityInterests, contains('Beaches'));
    });


    test('transitionTripStatus enforces state machine rules', () async {
      final trip = Trip(
        id: 'state-trip-1',
        userId: 'user-abc',
        origin: 'Paris',
        destination: 'Nice',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 5),
        status: TripStatus.published,
      );
      await repository.createTrip(trip);

      // 1. Published -> Paused (Valid)
      final paused = await repository.transitionTripStatus(
        tripId: 'state-trip-1',
        userId: 'user-abc',
        newStatus: TripStatus.paused,
      );
      expect(paused.status, equals(TripStatus.paused));

      // 2. Paused -> Published (Valid)
      final resumed = await repository.transitionTripStatus(
        tripId: 'state-trip-1',
        userId: 'user-abc',
        newStatus: TripStatus.published,
      );
      expect(resumed.status, equals(TripStatus.published));

      // 3. Published -> Cancelled (Valid)
      final cancelled = await repository.transitionTripStatus(
        tripId: 'state-trip-1',
        userId: 'user-abc',
        newStatus: TripStatus.cancelled,
        reason: 'Change of schedule',
      );
      expect(cancelled.status, equals(TripStatus.cancelled));

      // 4. Cancelled -> Published (Invalid - terminal state)
      expect(
        () => repository.transitionTripStatus(
          tripId: 'state-trip-1',
          userId: 'user-abc',
          newStatus: TripStatus.published,
        ),
        throwsException,
      );
    });

    test('deleteDraftTrip deletes draft but rejects deleting published trip', () async {
      // Create a draft
      final draft = Trip(
        id: 'draft-delete-1',
        userId: 'user-abc',
        origin: 'Austin',
        destination: 'Denver',
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2026, 12, 5),
        status: TripStatus.draft,
      );
      await repository.saveDraft(draft);

      // Deleting draft should succeed
      await repository.deleteDraftTrip(tripId: 'draft-delete-1', userId: 'user-abc');
      final afterDelete = await repository.getTrip('draft-delete-1');
      expect(afterDelete, isNull);

      // Create a published trip
      final published = Trip(
        id: 'pub-nodelete-1',
        userId: 'user-abc',
        origin: 'Austin',
        destination: 'Denver',
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2026, 12, 5),
        status: TripStatus.published,
      );
      await repository.createTrip(published);

      // Attempting to delete published trip must throw exception (Rule #11)
      expect(
        () => repository.deleteDraftTrip(tripId: 'pub-nodelete-1', userId: 'user-abc'),
        throwsException,
      );
    });


    test('getUserTrips returns filtered list for specific user', () async {
      final trip1 = Trip(
        id: 'u1-trip',
        userId: 'target-user',
        origin: 'Rome',
        destination: 'Florence',
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2026, 12, 5),
        status: TripStatus.draft,
      );
      final trip2 = Trip(
        id: 'u2-trip',
        userId: 'other-user',
        origin: 'Venice',
        destination: 'Milan',
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2026, 12, 5),
        status: TripStatus.draft,
      );

      await repository.saveDraft(trip1);
      await repository.saveDraft(trip2);

      final userTrips = await repository.getUserTrips('target-user');
      expect(userTrips.any((t) => t.id == 'u1-trip'), isTrue);
      expect(userTrips.any((t) => t.id == 'u2-trip'), isFalse);
    });
  });
}
