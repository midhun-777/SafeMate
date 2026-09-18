import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safemate/features/ai/presentation/controllers/journey_copilot_controller.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_state.dart';
import 'package:safemate/features/safety/data/repositories/supabase_safetrip_repository.dart';
import 'package:safemate/features/safety/presentation/controllers/safetrip_controller.dart';
import 'package:safemate/features/trips/data/repositories/supabase_trip_repository.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip_purpose.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';
import 'package:safemate/features/trips/domain/models/trip_transport.dart';
import 'package:safemate/features/trips/presentation/controllers/trip_creation_controller.dart';

void main() {
  group('JourneyCopilotController Tests', () {
    late ProviderContainer container;
    late SupabaseTripRepository tripRepo;
    late SupabaseSafeTripRepository safeTripRepo;
    late ProviderSubscription subscription;
    const testTripId = 'trip_copilot_test';
    const testUserId = 'user_alice';

    setUp(() async {
      tripRepo = SupabaseTripRepository();
      safeTripRepo = SupabaseSafeTripRepository();

      // Seed initial trip
      final trip = Trip(
        id: testTripId,
        userId: testUserId,
        title: 'Alpine Tour',
        origin: 'Zurich',
        destination: 'Lucerne',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)),
        budgetTier: TripBudgetTier.moderate,
        transportMode: TripTransport.train,
        tripPurpose: TripPurpose.vacation,
        status: TripStatus.published,
      );
      await tripRepo.createTrip(trip);

      container = ProviderContainer(
        overrides: [
          tripRepositoryProvider.overrideWithValue(tripRepo),
          safeTripRepositoryProvider.overrideWithValue(safeTripRepo),
          authControllerProvider.overrideWith((ref) => _FakeAuthController(testUserId)),
        ],
      );

      subscription = container.listen(
        journeyCopilotControllerProvider(testTripId),
        (prev, next) {},
      );
    });

    tearDown(() {
      subscription.close();
      container.dispose();
    });

    test('initializes with a reassuring welcome message', () {
      final state = container.read(journeyCopilotControllerProvider(testTripId));
      expect(state.messages, isNotEmpty);
      expect(state.messages.first.text, contains('SafeMate Journey Copilot'));
      expect(state.isLoading, isFalse);
    });

    test('requests itinerary and populates active proposal without mutating trip', () async {
      final notifier = container.read(journeyCopilotControllerProvider(testTripId).notifier);

      await notifier.requestItinerary();

      final state = container.read(journeyCopilotControllerProvider(testTripId));
      expect(state.messages.length, greaterThanOrEqualTo(3)); // welcome + user + AI
      expect(state.activeProposal, isNotNull);
      expect(state.activeProposal?['type'], 'itinerary_proposal');

      // Crucial verification: Trip notes in database remain empty/unmutated before user approval!
      final tripInDb = await tripRepo.getTrip(testTripId);
      expect(tripInDb?.notes, isNull);
    });

    test('applyActiveProposal mutates trip ONLY upon explicit user action', () async {
      final notifier = container.read(journeyCopilotControllerProvider(testTripId).notifier);

      await notifier.requestItinerary();
      final success = await notifier.applyActiveProposal();

      expect(success, isTrue);

      final state = container.read(journeyCopilotControllerProvider(testTripId));
      expect(state.activeProposal, isNull); // Proposal consumed

      // Verify trip notes were updated
      final updatedTrip = await tripRepo.getTrip(testTripId);
      expect(updatedTrip?.notes, isNotNull);
      expect(updatedTrip?.notes, contains('Suggested Itinerary'));
      expect(updatedTrip?.notes, contains('Day 1'));
    });

    test('dismissActiveProposal discards proposal and preserves original trip notes', () async {
      final notifier = container.read(journeyCopilotControllerProvider(testTripId).notifier);

      await notifier.requestItinerary();
      notifier.dismissActiveProposal();

      final state = container.read(journeyCopilotControllerProvider(testTripId));
      expect(state.activeProposal, isNull);

      final tripInDb = await tripRepo.getTrip(testTripId);
      expect(tripInDb?.notes, isNull);
    });
  });
}

class _FakeAuthController extends StateNotifier<AuthState> implements AuthController {
  _FakeAuthController(String userId)
      : super(
          AuthState(
            status: AuthStatus.authenticated,
            profile: UserProfile(
              id: userId,
              displayName: 'Alice Traveler',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ),
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
