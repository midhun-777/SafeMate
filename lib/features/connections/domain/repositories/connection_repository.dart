/// Abstract Connection Repository defining connection lifecycle contracts.
/// Universal Engineering Rule #6: Strict domain boundaries, privacy-safe identity.
library;

import '../models/connection.dart';
import '../models/connection_item.dart';

abstract class ConnectionRepository {
  /// Send a connection request from requester to receiver.
  Future<Connection> sendConnectionRequest({
    required String requesterId,
    required String receiverId,
    required String requesterTripId,
    String? recipientTripId,
  });

  /// Recipient accepts a pending connection request atomically.
  Future<Connection> acceptConnectionRequest({
    required String requestId,
    required String receiverId,
  });

  /// Recipient declines a pending connection request.
  Future<Connection> declineConnectionRequest({
    required String requestId,
    required String receiverId,
  });

  /// Requester cancels their pending connection request.
  Future<Connection> cancelConnectionRequest({
    required String requestId,
    required String requesterId,
  });

  /// Retrieve a connection by its ID.
  Future<Connection?> getConnection(String connectionId);

  /// Get all active/accepted connections for a user.
  Future<List<ConnectionItem>> getActiveConnections(String userId);

  /// Get pending connection requests received by the user.
  Future<List<ConnectionItem>> getPendingRequestsReceived(String userId);

  /// Get pending connection requests sent by the user.
  Future<List<ConnectionItem>> getPendingRequestsSent(String userId);

  /// Get past/inactive/cancelled/declined connections for history.
  Future<List<ConnectionItem>> getPastConnections(String userId);

  /// Check if an active request already exists between two users.
  Future<Connection?> findActiveRequestBetween({
    required String requesterId,
    required String receiverId,
    String? tripId,
  });

  /// Block a user and transition existing connections to blocked.
  Future<void> blockConnection({
    required String blockerId,
    required String blockedId,
  });
}
