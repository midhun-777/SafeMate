import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/trips/data/repositories/supabase_trip_repository.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip_purpose.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';
import 'package:safemate/features/trips/domain/models/trip_transport.dart';
import 'package:safemate/features/trips/domain/models/trip_visibility.dart';
import 'package:safemate/features/trips/presentation/controllers/trip_creation_controller.dart';
import 'package:safemate/features/trips/presentation/screens/create_trip_wizard_screen.dart';
import 'package:safemate/features/trips/presentation/screens/trip_review_screen.dart';
import 'package:safemate/features/trips/presentation/widgets/trip_card.dart';
import 'package:safemate/features/trips/presentation/widgets/trip_empty_state.dart';

void main() {
  group('Trip Presentation Widgets & Wizard Tests', () {
    late SupabaseTripRepository mockRepo;

    setUp(() {
      mockRepo = SupabaseTripRepository();
    });

    Widget buildTestApp(Widget child) {
      return ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('TripEmptyState renders title, description, and action button', (tester) async {
      var actionTapped = false;

      await tester.pumpWidget(buildTestApp(
        TripEmptyState(
          icon: Icons.luggage_outlined,
          title: 'No upcoming journeys',
          description: 'Plan a trip to discover companions.',
          actionLabel: 'Plan Journey',
          onAction: () => actionTapped = true,
        ),
      ));

      expect(find.text('No upcoming journeys'), findsOneWidget);
      expect(find.text('Plan a trip to discover companions.'), findsOneWidget);
      expect(find.text('Plan Journey'), findsOneWidget);

      await tester.tap(find.text('Plan Journey'));
      await tester.pump();
      expect(actionTapped, isTrue);
    });

    testWidgets('TripCard displays journey info, dates, duration, and status', (tester) async {
      final trip = Trip(
        id: 'test-card-trip',
        userId: 'user-1',
        title: 'Goa Weekend Trip',
        origin: 'Mumbai',
        destination: 'Goa',
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 14),
        transportMode: TripTransport.flight,
        tripPurpose: TripPurpose.vacation,
        budgetTier: TripBudgetTier.moderate,
        visibility: TripVisibility.visibleForMatching,
        status: TripStatus.published,
        maxCompanions: 3,
      );

      var tapped = false;

      await tester.pumpWidget(buildTestApp(
        Scaffold(
          body: TripCard(
            trip: trip,
            onTap: () => tapped = true,
          ),
        ),
      ));

      expect(find.text('Goa Weekend Trip'), findsOneWidget);
      expect(find.text('Mumbai → Goa'), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);
      expect(find.textContaining('5 days'), findsOneWidget);
      expect(find.text('✈ Flight'), findsOneWidget);

      await tester.tap(find.text('Goa Weekend Trip'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('CreateTripWizardScreen renders Step 1 and validates inputs', (tester) async {
      await tester.pumpWidget(buildTestApp(const CreateTripWizardScreen()));
      await tester.pumpAndSettle();

      // Step 1 check
      expect(find.text('STEP 01 OF 07'), findsOneWidget);
      expect(find.text('Where are you going?'), findsOneWidget);

      // Attempt continue without inputs -> should show validation error
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a destination.'), findsOneWidget);

      // Enter origin and destination
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Delhi');
      await tester.enterText(textFields.at(1), 'Jaipur');
      await tester.pumpAndSettle();

      // Now continue to Step 2
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2 check
      expect(find.text('STEP 02 OF 07'), findsOneWidget);
      expect(find.text('When are you travelling?'), findsOneWidget);

      // Back button navigates back to Step 1
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('STEP 01 OF 07'), findsOneWidget);
    });

    testWidgets('TripReviewScreen renders summary with publish button', (tester) async {
      final container = ProviderContainer(
        overrides: [
          tripRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      // Set up a valid trip in creation controller
      final notifier = container.read(tripCreationControllerProvider.notifier);
      notifier.setOrigin('Bangalore');
      notifier.setDestination('Mysore');
      notifier.setDateRange(DateTime(2026, 11, 1), DateTime(2026, 11, 3));
      notifier.setTransportMode(TripTransport.train);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TripReviewScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Review Journey'), findsOneWidget);
      expect(find.text('Mysore'), findsWidgets);
      expect(find.text('Bangalore'), findsWidgets);
      expect(find.text('Publish Journey'), findsOneWidget);
    });

  });
}
