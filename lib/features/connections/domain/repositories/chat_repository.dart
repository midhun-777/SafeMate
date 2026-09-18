/// SafeMate Chat Repository contract.
/// Universal Engineering Rule #6: Strict domain boundaries, privacy-safe identity.
library;

import '../models/chat_models.dart';

abstract class ChatRepository {
  /// Retrieve or create the chat room for an accepted connection.
  Future<ChatRoom?> getChatRoomForConnection(String connectionId);

  /// Retrieve a chat room by ID.
  Future<ChatRoom?> getChatRoom(String roomId);

  /// Fetch paginated messages for a room, ordered chronologically.
  Future<List<ChatMessage>> getMessages({
    required String roomId,
    int limit = 30,
    DateTime? before,
  });

  /// Send a message with client-generated idempotency identifier.
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String senderId,
    required String content,
    required String clientMessageId,
  });

  /// Mark all unread incoming messages in a room as read.
  Future<void> markRoomAsRead({
    required String roomId,
    required String userId,
  });

  /// Realtime stream of newly arrived messages for a specific room.
  Stream<ChatMessage> subscribeToMessages(String roomId);

  /// Realtime stream of user IDs currently typing (ephemeral, not persisted).
  Stream<String> subscribeToTyping(String roomId);

  /// Broadcast ephemeral typing indicator for the active user.
  Future<void> sendTypingIndicator({
    required String roomId,
    required String userId,
  });

  /// Dispose any active streams / channels.
  void dispose();
}
