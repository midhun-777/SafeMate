import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/services/analytics_service.dart';
import 'package:safemate/features/connections/domain/models/connection.dart';
import 'package:safemate/features/connections/domain/services/connection_state_machine.dart';

void main() {
  group('Phase 8 Security & Authorization Tests', () {
    const sm = ConnectionStateMachine();

    test('User A cannot accept a request intended for User B', () {
      expect(
        () => sm.validateAcceptRequest(
          actorId: 'user-a',
          receiverId: 'user-b',
          currentStatus: ConnectionRequestStatus.pending,
          isBlocked: false,
        ),
        throwsA(
          predicate((e) =>
              e is ConnectionStateTransitionException &&
              e.message.contains('Only the designated recipient may accept')),
        ),
      );
    });

    test('User B cannot cancel a request initiated by User A', () {
      expect(
        () => sm.validateCancelRequest(
          actorId: 'user-b',
          requesterId: 'user-a',
          currentStatus: ConnectionRequestStatus.pending,
        ),
        throwsA(
          predicate((e) =>
              e is ConnectionStateTransitionException &&
              e.message.contains('Only the original requester may cancel')),
        ),
      );
    });

    test('Blocked user cannot be targeted or initiate connection requests', () {
      expect(
        () => sm.validateSendRequest(
          requesterId: 'user-a',
          receiverId: 'user-b',
          isBlocked: true,
          isSuspended: false,
          hasExistingActiveRequest: false,
        ),
        throwsA(
          predicate((e) =>
              e is ConnectionStateTransitionException &&
              e.message.contains('blocked user')),
        ),
      );
    });

    test('Suspended account cannot initiate connection requests', () {
      expect(
        () => sm.validateSendRequest(
          requesterId: 'user-suspended',
          receiverId: 'user-b',
          isBlocked: false,
          isSuspended: true,
          hasExistingActiveRequest: false,
        ),
        throwsA(
          predicate((e) =>
              e is ConnectionStateTransitionException &&
              e.message.contains('Suspended accounts')),
        ),
      );
    });

    test('Self connection request is strictly forbidden', () {
      expect(
        () => sm.validateSendRequest(
          requesterId: 'user-a',
          receiverId: 'user-a',
          isBlocked: false,
          isSuspended: false,
          hasExistingActiveRequest: false,
        ),
        throwsA(
          predicate((e) =>
              e is ConnectionStateTransitionException &&
              e.message.contains('Self-connection requests are not permitted')),
        ),
      );
    });

    test('AnalyticsService strictly strips message body and PII keys', () async {
      const analytics = SafeMateAnalyticsService();
      // Should not throw and should strip forbidden keys
      await analytics.logEvent('message_sent', parameters: {
        'room_id': 'room-123',
        'message_id': 'msg-456',
        'body': 'Secret hotel room 204 password is 1234',
        'content': 'Secret message text',
        'phone': '+1234567890',
        'email': 'user@example.com',
      });
    });
  });
}
