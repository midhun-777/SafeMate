/// Deterministic Connection Request State Machine for SafeMate.
/// Universal Engineering Rule #11: Deterministic state machines & safe transitions.
library;

import '../models/connection.dart';

class ConnectionStateTransitionException implements Exception {
  final String message;
  final ConnectionRequestStatus? from;
  final ConnectionRequestStatus? to;

  const ConnectionStateTransitionException(this.message, {this.from, this.to});

  @override
  String toString() => 'ConnectionStateTransitionException: $message (from: $from, to: $to)';
}

class ConnectionStateMachine {
  const ConnectionStateMachine();

  /// Checks if a transition between two states is structurally permitted.
  static bool canTransition(
    ConnectionRequestStatus current,
    ConnectionRequestStatus next,
  ) {
    switch (current) {
      case ConnectionRequestStatus.pending:
        return next == ConnectionRequestStatus.accepted ||
            next == ConnectionRequestStatus.declined ||
            next == ConnectionRequestStatus.cancelled ||
            next == ConnectionRequestStatus.blocked;
      case ConnectionRequestStatus.accepted:
        // An accepted connection can transition to blocked if a user blocks
        return next == ConnectionRequestStatus.blocked;
      case ConnectionRequestStatus.declined:
      case ConnectionRequestStatus.cancelled:
        // Can transition back to pending if re-requested
        return next == ConnectionRequestStatus.pending ||
            next == ConnectionRequestStatus.blocked;
      case ConnectionRequestStatus.blocked:
        // Terminal until explicit unblock
        return false;
    }
  }

  /// Validates preconditions for sending a new connection request.
  void validateSendRequest({
    required String requesterId,
    required String receiverId,
    required bool isBlocked,
    required bool isSuspended,
    required bool hasExistingActiveRequest,
  }) {
    if (requesterId.isEmpty || receiverId.isEmpty) {
      throw const ConnectionStateTransitionException(
        'Requester and receiver IDs must not be empty.',
      );
    }
    if (requesterId == receiverId) {
      throw const ConnectionStateTransitionException(
        'Self-connection requests are not permitted.',
      );
    }
    if (isSuspended) {
      throw const ConnectionStateTransitionException(
        'Suspended accounts cannot initiate connection requests.',
      );
    }
    if (isBlocked) {
      throw const ConnectionStateTransitionException(
        'Cannot send connection request to or from a blocked user.',
      );
    }
    if (hasExistingActiveRequest) {
      throw const ConnectionStateTransitionException(
        'An active pending request already exists between these users.',
      );
    }
  }

  /// Validates an acceptance operation.
  void validateAcceptRequest({
    required String actorId,
    required String receiverId,
    required ConnectionRequestStatus currentStatus,
    required bool isBlocked,
  }) {
    if (actorId != receiverId) {
      throw const ConnectionStateTransitionException(
        'Unauthorized: Only the designated recipient may accept a connection request.',
      );
    }
    if (currentStatus != ConnectionRequestStatus.pending) {
      throw ConnectionStateTransitionException(
        'Cannot accept a request with status $currentStatus. Only pending requests can be accepted.',
        from: currentStatus,
        to: ConnectionRequestStatus.accepted,
      );
    }
    if (isBlocked) {
      throw const ConnectionStateTransitionException(
        'Cannot accept connection: one or more users are blocked.',
      );
    }
  }

  /// Validates a decline operation.
  void validateDeclineRequest({
    required String actorId,
    required String receiverId,
    required ConnectionRequestStatus currentStatus,
  }) {
    if (actorId != receiverId) {
      throw const ConnectionStateTransitionException(
        'Unauthorized: Only the designated recipient may decline a connection request.',
      );
    }
    if (currentStatus != ConnectionRequestStatus.pending) {
      throw ConnectionStateTransitionException(
        'Cannot decline a request with status $currentStatus. Only pending requests can be declined.',
        from: currentStatus,
        to: ConnectionRequestStatus.declined,
      );
    }
  }

  /// Validates a cancellation operation.
  void validateCancelRequest({
    required String actorId,
    required String requesterId,
    required ConnectionRequestStatus currentStatus,
  }) {
    if (actorId != requesterId) {
      throw const ConnectionStateTransitionException(
        'Unauthorized: Only the original requester may cancel a pending request.',
      );
    }
    if (currentStatus != ConnectionRequestStatus.pending) {
      throw ConnectionStateTransitionException(
        'Cannot cancel a request with status $currentStatus. Only pending requests can be cancelled.',
        from: currentStatus,
        to: ConnectionRequestStatus.cancelled,
      );
    }
  }
}
