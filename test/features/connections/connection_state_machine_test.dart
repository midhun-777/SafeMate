import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/connections/domain/models/connection.dart';
import 'package:safemate/features/connections/domain/services/connection_state_machine.dart';

void main() {
  group('ConnectionStateMachine Tests', () {
    const sm = ConnectionStateMachine();

    test('canTransition permits valid transitions', () {
      // PENDING transitions
      expect(
        ConnectionStateMachine.canTransition(
          ConnectionRequestStatus.pending,
          ConnectionRequestStatus.accepted,
        ),
        isTrue,
      );
      expect(
        ConnectionStateMachine.canTransition(
          ConnectionRequestStatus.pending,
          ConnectionRequestStatus.declined,
        ),
        isTrue,
      );
      expect(
        ConnectionStateMachine.canTransition(
          ConnectionRequestStatus.pending,
          ConnectionRequestStatus.cancelled,
        ),
        isTrue,
      );
      expect(
        ConnectionStateMachine.canTransition(
          ConnectionRequestStatus.pending,
          ConnectionRequestStatus.blocked,
        ),
        isTrue,
      );

      // ACCEPTED transitions
      expect(
        ConnectionStateMachine.canTransition(
          ConnectionRequestStatus.accepted,
          ConnectionRequestStatus.blocked,
        ),
        isTrue,
      );
      expect(
        ConnectionStateMachine.canTransition(
          ConnectionRequestStatus.accepted,
          ConnectionRequestStatus.cancelled,
        ),
        isFalse,
      );

      // DECLINED / CANCELLED transitions
      expect(
        ConnectionStateMachine.canTransition(
          ConnectionRequestStatus.declined,
          ConnectionRequestStatus.pending,
        ),
        isTrue,
      );
      expect(
        ConnectionStateMachine.canTransition(
          ConnectionRequestStatus.cancelled,
          ConnectionRequestStatus.pending,
        ),
        isTrue,
      );

      // BLOCKED is terminal
      expect(
        ConnectionStateMachine.canTransition(
          ConnectionRequestStatus.blocked,
          ConnectionRequestStatus.pending,
        ),
        isFalse,
      );
    });

    test('validateSendRequest throws on invalid conditions', () {
      // Self request
      expect(
        () => sm.validateSendRequest(
          requesterId: 'user-1',
          receiverId: 'user-1',
          isBlocked: false,
          isSuspended: false,
          hasExistingActiveRequest: false,
        ),
        throwsA(isA<ConnectionStateTransitionException>()),
      );

      // Blocked user
      expect(
        () => sm.validateSendRequest(
          requesterId: 'user-1',
          receiverId: 'user-2',
          isBlocked: true,
          isSuspended: false,
          hasExistingActiveRequest: false,
        ),
        throwsA(isA<ConnectionStateTransitionException>()),
      );

      // Suspended user
      expect(
        () => sm.validateSendRequest(
          requesterId: 'user-1',
          receiverId: 'user-2',
          isBlocked: false,
          isSuspended: true,
          hasExistingActiveRequest: false,
        ),
        throwsA(isA<ConnectionStateTransitionException>()),
      );

      // Existing active request
      expect(
        () => sm.validateSendRequest(
          requesterId: 'user-1',
          receiverId: 'user-2',
          isBlocked: false,
          isSuspended: false,
          hasExistingActiveRequest: true,
        ),
        throwsA(isA<ConnectionStateTransitionException>()),
      );
    });

    test('validateAcceptRequest enforces recipient ownership and pending status', () {
      // Unauthorized actor
      expect(
        () => sm.validateAcceptRequest(
          actorId: 'wrong-user',
          receiverId: 'recipient-1',
          currentStatus: ConnectionRequestStatus.pending,
          isBlocked: false,
        ),
        throwsA(isA<ConnectionStateTransitionException>()),
      );

      // Non-pending status
      expect(
        () => sm.validateAcceptRequest(
          actorId: 'recipient-1',
          receiverId: 'recipient-1',
          currentStatus: ConnectionRequestStatus.declined,
          isBlocked: false,
        ),
        throwsA(isA<ConnectionStateTransitionException>()),
      );

      // Blocked user
      expect(
        () => sm.validateAcceptRequest(
          actorId: 'recipient-1',
          receiverId: 'recipient-1',
          currentStatus: ConnectionRequestStatus.pending,
          isBlocked: true,
        ),
        throwsA(isA<ConnectionStateTransitionException>()),
      );

      // Valid accept passes
      expect(
        () => sm.validateAcceptRequest(
          actorId: 'recipient-1',
          receiverId: 'recipient-1',
          currentStatus: ConnectionRequestStatus.pending,
          isBlocked: false,
        ),
        returnsNormally,
      );
    });

    test('validateCancelRequest enforces requester ownership and pending status', () {
      // Recipient cannot cancel
      expect(
        () => sm.validateCancelRequest(
          actorId: 'recipient-1',
          requesterId: 'requester-1',
          currentStatus: ConnectionRequestStatus.pending,
        ),
        throwsA(isA<ConnectionStateTransitionException>()),
      );

      // Requester cancels pending successfully
      expect(
        () => sm.validateCancelRequest(
          actorId: 'requester-1',
          requesterId: 'requester-1',
          currentStatus: ConnectionRequestStatus.pending,
        ),
        returnsNormally,
      );
    });
  });
}
