import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/services/analytics_service.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/auth/domain/models/user_session.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_state.dart';
import 'package:safemate/features/connections/presentation/controllers/connection_controllers.dart';
import 'package:safemate/features/connections/presentation/screens/chat_screen.dart';
import 'package:safemate/features/connections/presentation/screens/connections_screen.dart';
import 'package:safemate/features/connections/presentation/widgets/connect_request_dialog.dart';

void main() {
  group('Phase 8 Widget Tests', () {
    testWidgets('ConnectRequestDialog renders prompt and buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ConnectRequestDialog.show(
                    context,
                    candidateUserId: 'user-sam',
                    candidateName: 'Sam Chen',
                    destination: 'Kyoto',
                    userTripId: 'trip-1',
                    currentUserId: 'user-alex',
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Connect with Sam Chen?'), findsOneWidget);
      expect(
        find.textContaining("You're both planning a journey to Kyoto"),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Send Request'), findsOneWidget);

      // Cancel dismisses
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Connect with Sam Chen?'), findsNothing);
    });

    testWidgets('ConnectionsScreen renders tabs and handles empty state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectionsListControllerProvider.overrideWith(
              (ref) => ConnectionsListController(
                repository: ref.watch(connectionRepositoryProvider),
                analytics: ref.watch(analyticsServiceProvider),
                currentUserId: 'test-user',
              ),
            ),
          ],
          child: const MaterialApp(
            home: ConnectionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Connections'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
      expect(find.text('Past'), findsOneWidget);

      // Empty state for active
      expect(find.text('No active connections yet'), findsOneWidget);
      expect(find.text('Find Travel Companions'), findsOneWidget);

      // Switch to Requests tab
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      expect(find.text('No pending requests'), findsOneWidget);

      // Switch to Sent tab
      await tester.tap(find.text('Sent'));
      await tester.pumpAndSettle();
      expect(find.text('No sent requests'), findsOneWidget);
    });

    testWidgets('ChatScreen renders empty state conversation starters, safety banner, and composer',
        (tester) async {
      final dummyUser = UserProfile(
        id: 'user-me',
        displayName: 'Alex',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              (ref) => _MockAuthController(dummyUser),
            ),
          ],
          child: const MaterialApp(
            home: ChatScreen(
              roomId: 'room-test-123',
              companionName: 'Sam Chen',
              destination: 'Kyoto',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header
      expect(find.text('Sam Chen'), findsOneWidget);
      expect(find.text('Journey to Kyoto'), findsOneWidget);

      // Safety banner
      expect(
        find.textContaining('Never share passwords, OTPs, financial details'),
        findsOneWidget,
      );

      // Conversation starters
      expect(find.text("You're connected!"), findsOneWidget);
      expect(find.text("What's your planned departure time?"), findsOneWidget);
      expect(find.text("Have you finalized your itinerary?"), findsOneWidget);

      // Composer
      expect(find.byKey(const Key('chat_composer_input')), findsOneWidget);
      expect(find.byKey(const Key('chat_send_button')), findsOneWidget);

      // Tapping a starter populates the composer
      await tester.tap(find.text("What's your planned departure time?"));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byKey(const Key('chat_composer_input')));
      expect(textField.controller?.text, equals("What's your planned departure time?"));
    });
  });
}

class _MockAuthController extends StateNotifier<AuthState> implements AuthController {
  _MockAuthController(UserProfile user)
      : super(
          AuthState(
            status: AuthStatus.authenticated,
            session: UserSession(
              userId: user.id,
              email: 'alex@example.com',
              createdAt: DateTime.now(),
            ),
            profile: user,
          ),
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
