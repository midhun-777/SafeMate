import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/controllers/auth_state.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/phone_otp_screen.dart';
import '../features/auth/presentation/screens/sign_in_screen.dart';
import '../features/auth/presentation/screens/sign_up_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/suspended_screen.dart';
import '../features/auth/presentation/screens/welcome_screen.dart';
import '../features/profile/presentation/screens/profile_review_screen.dart';
import '../features/profile/presentation/screens/profile_setup_screen.dart';
import '../features/profile/presentation/screens/profile_view_screen.dart';
import '../features/matching/domain/models/match_result.dart';
import '../features/matching/presentation/screens/match_detail_screen.dart';
import '../features/matching/presentation/screens/match_discovery_screen.dart';
import '../features/trips/presentation/screens/create_trip_wizard_screen.dart';
import '../features/trips/presentation/screens/trip_details_screen.dart';
import '../features/trips/presentation/screens/trip_review_screen.dart';
import '../features/trips/presentation/screens/trips_home_screen.dart';
import '../features/connections/presentation/screens/connections_screen.dart';
import '../features/connections/presentation/screens/chat_screen.dart';
import '../features/safety/presentation/screens/safety_center_screen.dart';
import '../features/safety/presentation/screens/verification_center_screen.dart';
import '../features/safety/presentation/screens/trusted_contacts_screen.dart';
import '../features/safety/presentation/screens/privacy_center_screen.dart';
import '../features/safety/presentation/screens/trust_profile_screen.dart';
import '../features/safety/presentation/screens/pre_journey_safety_screen.dart';
import '../features/safety/presentation/screens/safety_report_screen.dart';
import '../features/safety/presentation/screens/safetrip_preparation_screen.dart';
import '../features/safety/presentation/screens/safetrip_active_screen.dart';
import '../features/safety/presentation/screens/journey_timeline_screen.dart';
import '../features/ai/presentation/screens/journey_copilot_screen.dart';

/// Notifier that triggers GoRouter route refresh whenever AuthState changes.
class AuthRouterNotifier extends ChangeNotifier {
  final Ref _ref;

  AuthRouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authControllerProvider,
      (previous, current) => notifyListeners(),
    );
  }
}

/// Provider for AuthRouterNotifier.
final authRouterNotifierProvider = Provider<AuthRouterNotifier>((ref) {
  return AuthRouterNotifier(ref);
});

/// Riverpod provider for GoRouter configuration.
/// Implements reactive authentication boundaries and redirect guards.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(authRouterNotifierProvider);

  return GoRouter(
    navigatorKey: AppRouter.rootNavigatorKey,
    refreshListenable: notifier,
    initialLocation: '/',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.uri.path;

      // While in initial state, remain on splash
      if (authState.status == AuthStatus.initial) {
        return location == '/' ? null : '/';
      }

      // Check account suspension (Rule #11)
      if (authState.isSuspended) {
        if (location != '/auth/suspended') {
          return '/auth/suspended';
        }
        return null;
      }

      final isAuth = authState.isAuthenticated;
      final isAuthRoute = location.startsWith('/auth');
      final isSplash = location == '/';

      // Unauthenticated user attempting to access protected routes
      if (!isAuth) {
        if (!isAuthRoute) {
          return '/auth/welcome';
        }
        return null;
      }

      // Authenticated user attempting to access auth routes or splash
      if (isAuthRoute || isSplash) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth',
        redirect: (context, state) => '/auth/welcome',
      ),
      GoRoute(
        path: '/auth/welcome',
        name: 'auth_welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/auth/sign-in',
        name: 'auth_sign_in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/auth/sign-up',
        name: 'auth_sign_up',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/auth/phone',
        name: 'auth_phone',
        builder: (context, state) => const PhoneOtpScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        name: 'auth_forgot_password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/auth/suspended',
        name: 'auth_suspended',
        builder: (context, state) => const SuspendedScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const TripsHomeScreen(),
      ),
      GoRoute(
        path: '/profile/setup',
        name: 'profile_setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/profile/review',
        name: 'profile_review',
        builder: (context, state) => const ProfileReviewScreen(),
      ),
      GoRoute(
        path: '/profile/view',
        name: 'profile_view',
        builder: (context, state) => const ProfileViewScreen(),
      ),
      GoRoute(
        path: '/trips/create',
        name: 'trip_create',
        builder: (context, state) => const CreateTripWizardScreen(),
      ),
      GoRoute(
        path: '/trips/review',
        name: 'trip_review',
        builder: (context, state) => const TripReviewScreen(),
      ),
      GoRoute(
        path: '/trips/:id',
        name: 'trip_details',
        builder: (context, state) {
          final tripId = state.pathParameters['id'] ?? '';
          return TripDetailsScreen(tripId: tripId);
        },
      ),
      GoRoute(
        path: '/trips/:id/matches',
        name: 'trip_matches',
        builder: (context, state) {
          final tripId = state.pathParameters['id'] ?? '';
          return MatchDiscoveryScreen(tripId: tripId);
        },
      ),
      GoRoute(
        path: '/trips/:id/matches/:matchId',
        name: 'match_detail',
        builder: (context, state) {
          final tripId = state.pathParameters['id'] ?? '';
          final matchId = state.pathParameters['matchId'] ?? '';
          final match = state.extra as MatchResult?;
          return MatchDetailScreen(
            tripId: tripId,
            matchId: matchId,
            initialMatch: match,
          );
        },
      ),
      GoRoute(
        path: '/connections',
        name: 'connections',
        builder: (context, state) => const ConnectionsScreen(),
      ),
      GoRoute(
        path: '/chat/:roomId',
        name: 'chat_room',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId'] ?? '';
          final extra = state.extra as Map<String, dynamic>?;
          return ChatScreen(
            roomId: roomId,
            companionName: extra?['companionName'] as String?,
            destination: extra?['destination'] as String?,
          );
        },
      ),
      // --- SafeMate Phase 9: Trust Verification & Safety Foundation ---
      GoRoute(
        path: '/safety',
        name: 'safety_center',
        builder: (context, state) => const SafetyCenterScreen(),
      ),
      GoRoute(
        path: '/safety/verification',
        name: 'safety_verification',
        builder: (context, state) => const VerificationCenterScreen(),
      ),
      GoRoute(
        path: '/safety/trusted-contacts',
        name: 'safety_trusted_contacts',
        builder: (context, state) => const TrustedContactsScreen(),
      ),
      GoRoute(
        path: '/safety/privacy',
        name: 'safety_privacy',
        builder: (context, state) => const PrivacyCenterScreen(),
      ),
      GoRoute(
        path: '/safety/report',
        name: 'safety_report',
        builder: (context, state) {
          final targetUserId = state.uri.queryParameters['userId'];
          final targetUserName = state.uri.queryParameters['name'];
          final contextType = state.uri.queryParameters['contextType'];
          final contextId = state.uri.queryParameters['contextId'];
          return SafetyReportScreen(
            targetUserId: targetUserId,
            targetUserName: targetUserName,
            contextType: contextType,
            contextId: contextId,
          );
        },
      ),
      GoRoute(
        path: '/profile/trust',
        name: 'profile_trust',
        builder: (context, state) {
          final authState = ref.read(authControllerProvider);
          final currentUid = authState.profile?.id ?? authState.session?.userId ?? '';
          final userId = state.uri.queryParameters['userId'] ?? currentUid;
          return TrustProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/trips/:tripId/safety-check',
        name: 'pre_journey_safety',
        builder: (context, state) {
          final tripId = state.pathParameters['tripId'];
          return PreJourneySafetyScreen(tripId: tripId);
        },
      ),
      // --- SafeMate Phase 10: SafeTrip Real-Time Journey Safety ---
      GoRoute(
        path: '/trips/:tripId/safetrip-prep',
        name: 'safetrip_prep',
        builder: (context, state) {
          final tripId = state.pathParameters['tripId'] ?? '';
          return SafeTripPreparationScreen(tripId: tripId);
        },
      ),
      GoRoute(
        path: '/safetrip/:journeyId',
        name: 'safetrip_active',
        builder: (context, state) {
          final journeyId = state.pathParameters['journeyId'] ?? '';
          return SafeTripActiveScreen(journeyId: journeyId);
        },
      ),
      GoRoute(
        path: '/safetrip/:journeyId/timeline',
        name: 'safetrip_timeline',
        builder: (context, state) {
          final journeyId = state.pathParameters['journeyId'] ?? '';
          return JourneyTimelineScreen(journeyId: journeyId);
        },
      ),
      // --- SafeMate Phase 11: AI Journey Copilot & Adaptive Safety ---
      GoRoute(
        path: '/trips/:tripId/copilot',
        name: 'journey_copilot',
        builder: (context, state) {
          final tripId = state.pathParameters['tripId'] ?? '';
          final destination = state.uri.queryParameters['destination'];
          return JourneyCopilotScreen(
            tripId: tripId,
            destination: destination,
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});

/// Router helper holding navigation keys and route definitions.
class AppRouter {
  const AppRouter._();

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'rootNav');
}
