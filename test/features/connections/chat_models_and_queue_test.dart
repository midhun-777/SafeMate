import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/connections/domain/models/chat_models.dart';
import 'package:safemate/features/connections/domain/services/chat_offline_queue.dart';

void main() {
  group('Chat Models Tests', () {
    test('ChatMessage JSON serialization and delivery status mapping', () {
      final now = DateTime(2026, 9, 16, 12, 0);
      final msg = ChatMessage(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'user-1',
        clientMessageId: 'client-uuid-1',
        content: 'Hey, when are you planning to arrive?',
        deliveryStatus: MessageDeliveryStatus.sent,
        createdAt: now,
      );

      expect(msg.body, equals('Hey, when are you planning to arrive?'));
      expect(msg.isSent, isTrue);
      expect(msg.isPending, isFalse);
      expect(msg.isDeleted, isFalse);

      final json = msg.toJson();
      expect(json['client_message_id'], equals('client-uuid-1'));
      expect(json['status'], equals('sent'));

      final fromJson = ChatMessage.fromJson(json);
      expect(fromJson.id, equals(msg.id));
      expect(fromJson.content, equals(msg.content));
      expect(fromJson.deliveryStatus, equals(MessageDeliveryStatus.sent));
    });

    test('ChatRoom serialization', () {
      final now = DateTime.now();
      final room = ChatRoom(
        id: 'room-1',
        connectionId: 'conn-1',
        createdAt: now,
      );

      expect(room.isActive, isTrue);
      final json = room.toJson();
      final fromJson = ChatRoom.fromJson(json);
      expect(fromJson.id, equals(room.id));
      expect(fromJson.connectionId, equals(room.connectionId));
    });
  });

  group('ChatOfflineQueue Tests', () {
    test('ChatOfflineQueue enqueues, deduplicates, and dequeues in chronological order', () {
      final queue = ChatOfflineQueue();
      final now = DateTime.now();

      final msg1 = ChatMessage(
        id: '1',
        roomId: 'r1',
        senderId: 'u1',
        clientMessageId: 'c-1',
        content: 'First message',
        createdAt: now.subtract(const Duration(minutes: 2)),
      );

      final msg2 = ChatMessage(
        id: '2',
        roomId: 'r1',
        senderId: 'u1',
        clientMessageId: 'c-2',
        content: 'Second message',
        createdAt: now,
      );

      queue.enqueue(msg1);
      queue.enqueue(msg2);

      // Duplicate enqueue should be ignored
      queue.enqueue(msg1);

      expect(queue.count, equals(2));
      expect(queue.contains('c-1'), isTrue);
      expect(queue.contains('c-3'), isFalse);

      final pending = queue.getPendingForRoom('r1');
      expect(pending.length, equals(2));
      expect(pending.first.clientMessageId, equals('c-1'));
      expect(pending.last.clientMessageId, equals('c-2'));

      // Remove message
      final removed = queue.remove('c-1');
      expect(removed?.clientMessageId, equals('c-1'));
      expect(queue.count, equals(1));

      // Mark failed
      queue.markFailed('c-2');
      final updatedPending = queue.getPendingForRoom('r1');
      expect(updatedPending.first.isFailed, isTrue);
    });
  });
}
