import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/errors/app_exception.dart';
import 'package:safemate/features/connections/data/repositories/supabase_chat_repository.dart';
import 'package:safemate/features/connections/domain/models/chat_models.dart';

void main() {
  group('SupabaseChatRepository Tests', () {
    late SupabaseChatRepository repo;

    setUp(() {
      repo = SupabaseChatRepository();
    });

    tearDown(() {
      repo.dispose();
    });

    test('getChatRoomForConnection provisions room for connection', () async {
      final room = await repo.getChatRoomForConnection('conn-100');
      expect(room, isNotNull);
      expect(room?.connectionId, equals('conn-100'));
      expect(room?.isActive, isTrue);

      // Subsequent call retrieves existing
      final room2 = await repo.getChatRoomForConnection('conn-100');
      expect(room2?.id, equals(room?.id));
    });

    test('sendMessage delivers and enforces idempotency via clientMessageId', () async {
      final msg1 = await repo.sendMessage(
        roomId: 'room-1',
        senderId: 'user-1',
        content: 'Hello, SafeMate companion!',
        clientMessageId: 'client-id-123',
      );

      expect(msg1.content, equals('Hello, SafeMate companion!'));
      expect(msg1.clientMessageId, equals('client-id-123'));
      expect(msg1.isSent, isTrue);

      // Resending with same clientMessageId should return existing without duplicate
      final msgDuplicate = await repo.sendMessage(
        roomId: 'room-1',
        senderId: 'user-1',
        content: 'Hello, SafeMate companion!',
        clientMessageId: 'client-id-123',
      );

      expect(msgDuplicate.id, equals(msg1.id));

      final msgs = await repo.getMessages(roomId: 'room-1');
      expect(msgs.length, equals(1));
    });

    test('sendMessage rejects empty content and content exceeding 4000 chars', () async {
      expect(
        () => repo.sendMessage(
          roomId: 'room-1',
          senderId: 'user-1',
          content: '   ',
          clientMessageId: 'id-empty',
        ),
        throwsA(isA<AppException>()),
      );

      final massiveContent = 'a' * 4001;
      expect(
        () => repo.sendMessage(
          roomId: 'room-1',
          senderId: 'user-1',
          content: massiveContent,
          clientMessageId: 'id-long',
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('subscribeToMessages streams newly sent messages', () async {
      final stream = repo.subscribeToMessages('room-stream');
      final received = <ChatMessage>[];
      final sub = stream.listen(received.add);

      await repo.sendMessage(
        roomId: 'room-stream',
        senderId: 'user-a',
        content: 'Realtime update',
        clientMessageId: 'rt-1',
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(received.length, equals(1));
      expect(received.first.content, equals('Realtime update'));

      await sub.cancel();
    });

    test('markRoomAsRead marks companion messages as read', () async {
      await repo.sendMessage(
        roomId: 'room-read',
        senderId: 'user-other',
        content: 'Unread message',
        clientMessageId: 'unread-1',
      );

      await repo.markRoomAsRead(roomId: 'room-read', userId: 'user-me');

      final msgs = await repo.getMessages(roomId: 'room-read');
      expect(msgs.first.isRead, isTrue);
    });
  });
}
