/// SafeMate Offline Message Queue for resilient realtime communication.
/// Universal Engineering Rule #11: Offline resilience, deduplication via client_message_id.
library;

import '../models/chat_models.dart';

class ChatOfflineQueue {
  final Map<String, ChatMessage> _queuedMessages = {};

  List<ChatMessage> get queuedMessages => _queuedMessages.values.toList();

  int get count => _queuedMessages.length;

  /// Enqueue an outgoing message. If already queued by clientMessageId, preserves existing.
  void enqueue(ChatMessage message) {
    if (!_queuedMessages.containsKey(message.clientMessageId)) {
      _queuedMessages[message.clientMessageId] = message.copyWith(
        deliveryStatus: MessageDeliveryStatus.pending,
      );
    }
  }

  /// Remove a message from queue once server ack is received.
  ChatMessage? remove(String clientMessageId) {
    return _queuedMessages.remove(clientMessageId);
  }

  /// Retrieve all pending messages for a given room, ordered by creation time.
  List<ChatMessage> getPendingForRoom(String roomId) {
    final list = _queuedMessages.values
        .where((msg) => msg.roomId == roomId)
        .toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// Check if a specific clientMessageId is currently in queue.
  bool contains(String clientMessageId) {
    return _queuedMessages.containsKey(clientMessageId);
  }

  /// Mark a queued message as failed.
  void markFailed(String clientMessageId) {
    final existing = _queuedMessages[clientMessageId];
    if (existing != null) {
      _queuedMessages[clientMessageId] = existing.copyWith(
        deliveryStatus: MessageDeliveryStatus.failed,
      );
    }
  }

  /// Clear all queued messages.
  void clear() {
    _queuedMessages.clear();
  }
}
