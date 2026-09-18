import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/trips/data/repositories/supabase_trip_repository.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';
import 'package:safemate/features/trips/presentation/controllers/trip_creation_controller.dart';
import 'package:safemate/features/trips/presentation/controllers/trips_list_controller.dart';
import 'package:safemate/features/trips/presentation/controllers/trips_list_state.dart';

void main() {
  group('TripsListController Tests', () {
    late ProviderContainer container;
    late SupabaseTripRepository mockRepo;

    setUp(() async {
      mockRepo = SupabaseTripRepository();

      // Seed initial trips into mock dev repo
      await mockRepo.createTrip(Trip(
        id: 'trip-upcoming-1',
        userId: 'dev_user_placeholder',
        title: 'Upcoming Mountain Escape',
        origin: 'Shimla',
        destination: 'Manali',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 5),
        status: TripStatus.published,
      ));

      await mockRepo.saveDraft(Trip(
        id: 'trip-draft-1',
        userId: 'dev_user_placeholder',
        title: 'Draft Roadtrip',
        origin: 'Delhi',
        destination: 'Agra',
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2026, 12, 5),
        status: TripStatus.draft,
      ));

      await mockRepo.createTrip(Trip(
        id: 'trip-past-1',
        userId: 'dev_user_placeholder',
        title: 'Completed Voyage',
        origin: 'Kochi',
        destination: 'Munnar',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 5),
        status: TripStatus.completed,
      ));

      await mockRepo.createTrip(Trip(
        id: 'trip-cancelled-1',
        userId: 'dev_user_placeholder',
        title: 'Cancelled Trek',
        origin: 'Rishikesh',
        destination: 'Kedarnath',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 5),
        status: TripStatus.cancelled,
      ));

      container = ProviderContainer(
        overrides: [
          tripRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('loadTrips categorizes journeys by lifecycle state', () async {
      final notifier = container.read(tripsListControllerProvider.notifier);
      await notifier.loadTrips();

      final state = container.read(tripsListControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.upcomingTrips.any((t) => t.id == 'trip-upcoming-1'), isTrue);
      expect(state.draftTrips.any((t) => t.id == 'trip-draft-1'), isTrue);
      expect(state.pastTrips.any((t) => t.id == 'trip-past-1'), isTrue);
      expect(state.cancelledTrips.any((t) => t.id == 'trip-cancelled-1'), isTrue);
    });

    test('setTab toggles current tab and exposes correct trips', () async {
      final notifier = container.read(tripsListControllerProvider.notifier);
      await notifier.loadTrips();

      notifier.setTab(TripListTab.drafts);
      expect(container.read(tripsListControllerProvider).currentTab, equals(TripListTab.drafts));
      expect(
        container.read(tripsListControllerProvider).currentTabTrips.first.id,
        equals('trip-draft-1'),
      );

      notifier.setTab(TripListTab.past);
      expect(container.read(tripsListControllerProvider).currentTab, equals(TripListTab.past));
      expect(
        container.read(tripsListControllerProvider).currentTabTrips.first.id,
        equals('trip-past-1'),
      );
    });

    test('pauseTrip and resumeTrip toggle trip status', () async {
      final notifier = container.read(tripsListControllerProvider.notifier);
      await notifier.loadTrips();

      // Pause
      final pausedSuccess = await notifier.pauseTrip('trip-upcoming-1');
      expect(pausedSuccess, isTrue);
      var trip = await mockRepo.getTrip('trip-upcoming-1');
      expect(trip?.status, equals(TripStatus.paused));

      // Resume
      final resumeSuccess = await notifier.resumeTrip('trip-upcoming-1');
      expect(resumeSuccess, isTrue);
      trip = await mockRepo.getTrip('trip-upcoming-1');
      expect(trip?.status, equals(TripStatus.published));
    });

    test('cancelTrip marks journey as cancelled with reason', () async {
      final notifier = container.read(tripsListControllerProvider.notifier);
      await notifier.loadTrips();

      final success = await notifier.cancelTrip('trip-upcoming-1', reason: 'Personal emergency');
      expect(success, isTrue);

      final trip = await mockRepo.getTrip('trip-upcoming-1');
      expect(trip?.status, equals(TripStatus.cancelled));
      expect(trip?.notes, contains('Personal emergency'));
    });

    test('completeTrip marks journey as completed', () async {
      final notifier = container.read(tripsListControllerProvider.notifier);
      await notifier.loadTrips();

      final success = await notifier.completeTrip('trip-upcoming-1');
      expect(success, isTrue);

      final trip = await mockRepo.getTrip('trip-upcoming-1');
      expect(trip?.status, equals(TripStatus.completed));
    });

    test('deleteDraft removes draft from list and repository', () async {
      final notifier = container.read(tripsListControllerProvider.notifier);
      await notifier.loadTrips();

      final success = await notifier.deleteDraft('trip-draft-1');
      expect(success, isTrue);

      final state = container.read(tripsListControllerProvider);
      expect(state.draftTrips.any((t) => t.id == 'trip-draft-1'), isFalse);

      final trip = await mockRepo.getTrip('trip-draft-1');
      expect(trip, isNull);
    });
  });
}
