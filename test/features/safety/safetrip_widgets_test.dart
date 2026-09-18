import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/auth/domain/models/user_session.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_state.dart';
import 'package:safemate/features/safety/domain/models/safetrip_models.dart';
import 'package:safemate/features/safety/domain/models/safety_contact.dart';
import 'package:safemate/features/safety/presentation/controllers/safety_controllers.dart';
import 'package:safemate/features/safety/presentation/controllers/safetrip_controller.dart';
import 'package:safemate/features/safety/presentation/screens/journey_timeline_screen.dart';
import 'package:safemate/features/safety/presentation/screens/safetrip_active_screen.dart';
import 'package:safemate/features/safety/presentation/screens/safetrip_preparation_screen.dart';
import 'package:safemate/features/safety/presentation/widgets/location_sharing_dialog.dart';
import 'package:safemate/features/safety/presentation/widgets/need_help_dialog.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip_purpose.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';
import 'package:safemate/features/trips/domain/models/trip_transport.dart';
import 'package:safemate/features/trips/domain/models/trip_visibility.dart';
import 'package:safemate/features/trips/presentation/controllers/trips_list_controller.dart';
import 'package:safemate/features/trips/presentation/controllers/trips_list_state.dart';

void main() {
  final now = DateTime(2026, 9, 16, 10, 0);

  final testTrip = Trip(
    id: 'trip-101',
    userId: 'user-001',
    title: 'Hyderabad to Vijayawada Express',
    origin: 'Hyderabad',
    destination: 'Vijayawada',
    startDate: now.add(const Duration(hours: 1)),
    endDate: now.add(const Duration(hours: 6)),
    transportMode: TripTransport.train,
    tripPurpose: TripPurpose.vacation,
    budgetTier: TripBudgetTier.moderate,
    visibility: TripVisibility.visibleForMatching,
    status: TripStatus.published,
    createdAt: now,
    updatedAt: now,
  );

  final testContact = SafetyContact(
    id: 'contact-001',
    userId: 'user-001',
    contactName: 'Rohit Sharma',
    phoneNumber: '+919876543210',
    relationship: 'Brother',
    createdAt: now,
  );

  final testSafeTrip = SafeTrip(
    id: 'journey-505',
    tripId: 'trip-101',
    ownerId: 'user-001',
    trustedContactId: 'contact-001',
    status: SafeTripStatus.active,
    expectedStartTime: now.add(const Duration(hours: 1)),
    expectedArrivalTime: now.add(const Duration(hours: 6)),
    checkinIntervalMinutes: 60,
    gracePeriodMinutes: 15,
    lastCheckinAt: now,
    nextCheckinDeadline: now.add(const Duration(minutes: 45)),
    locationSharingMode: LocationSharingMode.approximate,
    createdAt: now,
    updatedAt: now,
  );

  Widget createWidgetForTesting(Widget child, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          (ref) => FakeAuthController(
            AuthState(
              status: AuthStatus.authenticated,
              session: UserSession(
                userId: 'user-001',
                email: 'user@safemate.internal',
                createdAt: now,
              ),
              profile: UserProfile(
                id: 'user-001',
                displayName: 'Alice Traveler',
                isVerified: true,
                isPhoneVerified: true,
                trustScore: 90,
                createdAt: now,
                updatedAt: now,
              ),
            ),
          ),
        ),
        tripsListControllerProvider.overrideWith(
          (ref) => FakeTripsListController(
            TripsListState(trips: [testTrip]),
          ),
        ),
        trustedContactsControllerProvider.overrideWith(
          (ref) => FakeTrustedContactsController(
            TrustedContactsState(contacts: [testContact]),
          ),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('SafeTripPresentation Widgets', () {
    testWidgets('SafeTripPreparationScreen renders summary, contact and consent controls',
        (tester) async {
      await tester.pumpWidget(
        createWidgetForTesting(
          const SafeTripPreparationScreen(tripId: 'trip-101'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SafeTrip Preparation'), findsOneWidget);
      expect(find.text('Hyderabad → Vijayawada'), findsOneWidget);
      expect(find.text('Designated Trusted Contact'), findsOneWidget);
      expect(find.text('Rohit Sharma (Brother)'), findsOneWidget);
      expect(find.text('Sharing & Safety Permissions'), findsOneWidget);
      expect(find.text('Share journey status with trusted contact'), findsOneWidget);
      expect(find.text('Share approximate location (~20km)'), findsOneWidget);
      expect(find.text('Send periodic check-in reminders'), findsOneWidget);
      expect(find.text('SafeTrip Privacy Promise'), findsOneWidget);
      expect(find.text('Activate SafeTrip'), findsOneWidget);

      // Tap Activate SafeTrip opens confirmation dialog
      await tester.ensureVisible(find.text('Activate SafeTrip'));
      await tester.tap(find.text('Activate SafeTrip'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm SafeTrip Activation'), findsOneWidget);
      expect(find.text('Activate Now'), findsOneWidget);
    });

    testWidgets('SafeTripActiveScreen renders calm active experience and check-in button',
        (tester) async {
      final fakeSafeTripNotifier = FakeSafeTripController(
        SafeTripState(currentTrip: testSafeTrip),
      );

      await tester.pumpWidget(
        createWidgetForTesting(
          const SafeTripActiveScreen(journeyId: 'journey-505'),
          overrides: [
            safeTripControllerProvider.overrideWith((ref) => fakeSafeTripNotifier),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SafeTrip Active'), findsOneWidget);
      expect(find.text('JOURNEY ACTIVE'), findsOneWidget);
      expect(find.text('Next Check-in'), findsOneWidget);
      expect(find.text("I'M OK"), findsOneWidget);
      expect(find.text('Approximate Location'), findsOneWidget);
      expect(find.text('Need Help?'), findsOneWidget);
      expect(find.text("I've Arrived"), findsOneWidget);

      // Tap "I'M OK" button triggers check-in
      await tester.tap(find.text("I'M OK"));
      await tester.pump();
    });

    testWidgets('NeedHelpDialog renders calm assistance options and dialer boundary',
        (tester) async {
      var sharedStatus = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NeedHelpDialog(
              trustedContactName: 'Rohit Sharma',
              trustedContactPhone: '+919876543210',
              onShareStatus: () => sharedStatus = true,
            ),
          ),
        ),
      );

      expect(find.text('Need Assistance?'), findsOneWidget);
      expect(find.text('Contact Rohit Sharma'), findsOneWidget);
      expect(find.text('Share Journey Status'), findsOneWidget);
      expect(find.text('Local Emergency Services'), findsOneWidget);

      // Tap Share Journey Status
      await tester.tap(find.text('Share Journey Status'));
      await tester.pumpAndSettle();
      expect(sharedStatus, isTrue);
    });

    testWidgets('LocationSharingDialog renders duration options and clear purpose',
        (tester) async {
      var started = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationSharingDialog(
              currentSession: null,
              onStart: (mode, duration) => started = true,
              onStop: () {},
            ),
          ),
        ),
      );

      expect(find.text('Location Sharing'), findsOneWidget);
      expect(find.text('Status: OFF'), findsOneWidget);
      expect(find.text('Approximate Area Only'), findsOneWidget);
      expect(find.text('Start Approximate Sharing'), findsOneWidget);

      await tester.tap(find.text('Start Approximate Sharing'));
      await tester.pumpAndSettle();
      expect(started, isTrue);
    });

    testWidgets('JourneyTimelineScreen renders event sequence',
        (tester) async {
      final fakeSafeTripNotifier = FakeSafeTripController(
        SafeTripState(
          currentTrip: testSafeTrip,
          events: [
            {
              'id': 'ev-1',
              'event_type': 'journey_activated',
              'created_at': now.toIso8601String(),
            },
            {
              'id': 'ev-2',
              'event_type': 'checkin_completed',
              'created_at': now.add(const Duration(minutes: 45)).toIso8601String(),
            },
          ],
        ),
      );

      await tester.pumpWidget(
        createWidgetForTesting(
          const JourneyTimelineScreen(journeyId: 'journey-505'),
          overrides: [
            safeTripControllerProvider.overrideWith((ref) => fakeSafeTripNotifier),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Journey Timeline'), findsOneWidget);
      expect(find.text('SafeTrip Activated'), findsOneWidget);
      expect(find.text('Check-in Completed'), findsOneWidget);
    });
  });
}

// -----------------------------------------------------------------------------
// FAKE CONTROLLERS FOR TESTING
// -----------------------------------------------------------------------------

class FakeAuthController extends StateNotifier<AuthState>
    implements AuthController {
  FakeAuthController(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTripsListController extends StateNotifier<TripsListState>
    implements TripsListController {
  FakeTripsListController(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTrustedContactsController
    extends StateNotifier<TrustedContactsState>
    implements TrustedContactsController {
  FakeTrustedContactsController(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSafeTripController extends StateNotifier<SafeTripState>
    implements SafeTripController {
  FakeSafeTripController(super.initialState);

  @override
  Future<void> loadSafeTrip(String journeyId) async {}

  @override
  Future<bool> recordCheckin({String? notes}) async {
    return true;
  }

  @override
  Future<bool> confirmArrival() async {
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
