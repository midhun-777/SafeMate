import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/trips/data/repositories/supabase_trip_repository.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip_purpose.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';
import 'package:safemate/features/trips/domain/models/trip_transport.dart';
import 'package:safemate/features/trips/presentation/controllers/trip_creation_controller.dart';

void main() {
  group('TripCreationController Tests', () {
    late ProviderContainer container;
    late SupabaseTripRepository mockRepo;

    setUp(() {
      mockRepo = SupabaseTripRepository();
      container = ProviderContainer(
        overrides: [
          tripRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state is at step 0 with empty fields', () {
      final state = container.read(tripCreationControllerProvider);
      expect(state.currentStep, equals(0));
      expect(state.trip.origin, isEmpty);
      expect(state.trip.destination, isEmpty);
      expect(state.trip.status, equals(TripStatus.draft));
    });

    test('nextStep prevents advancing from Step 0 if origin or destination is empty', () {
      final notifier = container.read(tripCreationControllerProvider.notifier);

      notifier.setOrigin('');
      notifier.setDestination('');
      final advanced = notifier.nextStep();

      expect(advanced, isFalse);
      expect(container.read(tripCreationControllerProvider).currentStep, equals(0));
      expect(container.read(tripCreationControllerProvider).errorMessage, isNotNull);
    });

    test('nextStep advances from Step 0 when origin and destination are set', () {
      final notifier = container.read(tripCreationControllerProvider.notifier);

      notifier.setOrigin('Bangalore');
      notifier.setDestination('Coorg');
      final advanced = notifier.nextStep();

      expect(advanced, isTrue);
      expect(container.read(tripCreationControllerProvider).currentStep, equals(1));
      expect(container.read(tripCreationControllerProvider).errorMessage, isNull);
    });

    test('nextStep prevents advancing from Step 1 if dates are missing', () {
      final notifier = container.read(tripCreationControllerProvider.notifier);
      notifier.setOrigin('Bangalore');
      notifier.setDestination('Coorg');
      notifier.nextStep(); // to Step 1

      final advanced = notifier.nextStep();
      expect(advanced, isFalse);
      expect(container.read(tripCreationControllerProvider).currentStep, equals(1));
    });

    test('Field mutators correctly update draft state', () {
      final notifier = container.read(tripCreationControllerProvider.notifier);

      notifier.setOrigin('Mumbai');
      notifier.setDestination('Goa');
      notifier.setDateRange(DateTime(2026, 12, 1), DateTime(2026, 12, 5));
      notifier.setTransportMode(TripTransport.train);
      notifier.setBudgetTier(TripBudgetTier.budget);
      notifier.setTripPurpose(TripPurpose.adventure);
      notifier.toggleTripStyle('beach');
      notifier.setMaxCompanions(4);

      final state = container.read(tripCreationControllerProvider);
      expect(state.trip.origin, equals('Mumbai'));
      expect(state.trip.destination, equals('Goa'));
      expect(state.trip.durationDays, equals(5));
      expect(state.trip.transportMode, equals(TripTransport.train));
      expect(state.trip.budgetTier, equals(TripBudgetTier.budget));
      expect(state.trip.tripPurpose, equals(TripPurpose.adventure));
      expect(state.trip.tripStyles, contains('beach'));
      expect(state.trip.maxCompanions, equals(4));
    });

    test('saveDraft persists current trip state to repository', () async {
      final notifier = container.read(tripCreationControllerProvider.notifier);
      notifier.setOrigin('Hyderabad');
      notifier.setDestination('Hampi');

      final success = await notifier.saveDraft();
      expect(success, isTrue);

      final state = container.read(tripCreationControllerProvider);
      final savedTrip = await mockRepo.getTrip(state.trip.id);
      expect(savedTrip, isNotNull);
      expect(savedTrip!.origin, equals('Hyderabad'));
      expect(savedTrip.destination, equals('Hampi'));
      expect(savedTrip.status, equals(TripStatus.draft));
    });

    test('publishTrip validates and transitions trip to published', () async {
      final notifier = container.read(tripCreationControllerProvider.notifier);
      notifier.setOrigin('Delhi');
      notifier.setDestination('Leh');
      notifier.setDateRange(DateTime(2026, 11, 1), DateTime(2026, 11, 10));
      notifier.setTransportMode(TripTransport.flight);

      final success = await notifier.publishTrip();
      expect(success, isTrue);

      final state = container.read(tripCreationControllerProvider);
      expect(state.trip.status, equals(TripStatus.published));

      final publishedTrip = await mockRepo.getTrip(state.trip.id);
      expect(publishedTrip, isNotNull);
      expect(publishedTrip!.status, equals(TripStatus.published));
    });

    test('loadTrip populates controller with existing trip data', () async {
      final existingTrip = Trip(
        id: 'existing-trip-1',
        userId: 'user-xyz',
        title: 'Kerala Backwaters Tour',
        origin: 'Kochi',
        destination: 'Alleppey',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 4),
        transportMode: TripTransport.bus,
        status: TripStatus.draft,
      );

      await mockRepo.saveDraft(existingTrip);

      final notifier = container.read(tripCreationControllerProvider.notifier);
      await notifier.loadTrip(existingTrip.id);

      final state = container.read(tripCreationControllerProvider);
      expect(state.trip.id, equals('existing-trip-1'));
      expect(state.trip.origin, equals('Kochi'));
      expect(state.trip.destination, equals('Alleppey'));
      expect(state.trip.durationDays, equals(4));
    });
  });
}
