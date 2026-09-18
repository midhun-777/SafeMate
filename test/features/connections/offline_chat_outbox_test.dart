import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/sync/sync_engine.dart';
import 'package:safemate/features/connections/data/repositories/offline_first_chat_repository.dart';
import 'package:safemate/features/connections/data/repositories/supabase_chat_repository.dart';
import 'package:safemate/features/connections/domain/models/chat_models.dart';

void main() {
  sqfliteFfiInit();

  late LocalDatabaseService localDb;
  late SyncEngine syncEngine;
  late SupabaseChatRepository remoteRepo;
  late OfflineFirstChatRepository offlineChatRepo;

  setUp(() async {
    localDb = LocalDatabaseService();
    await localDb.initialize(
      databaseFactory: databaseFactoryFfi,
      dbName: 'offline_chat_repo_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    syncEngine = SyncEngine(localDb: localDb);
    remoteRepo = SupabaseChatRepository();
    offlineChatRepo = OfflineFirstChatRepository(
      remoteRepo: remoteRepo,
      localDb: localDb,
      syncEngine: syncEngine,
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await localDb.close();
  });

  group('Phase 12.3 Offline Chat Outbox Tests (12.3.15 & 12.3.18)', () {
    test('sendMessage creates outbox entry with clientMessageId and marks sent upon server confirmation', () async {
      final clientMsgId = 'client_uuid_chat_001';
      final sentMsg = await offlineChatRepo.sendMessage(
        roomId: 'room_101',
        senderId: 'user_sender',
        content: 'Hey, are you at the train station?',
        clientMessageId: clientMsgId,
      );

      expect(sentMsg.clientMessageId, equals(clientMsgId));
      expect(sentMsg.content, equals('Hey, are you at the train station?'));

      // Check SQLite local store
      final localMsgs = await localDb.getRoomMessages('room_101');
      expect(localMsgs.length, equals(1));
      expect(localMsgs.first.clientMessageId, equals(clientMsgId));
      expect(localMsgs.first.deliveryStatus, equals(MessageDeliveryStatus.sent));
    });

    test('getMessages returns instantaneous local outbox messages', () async {
      final initialMsg = ChatMessage(
        id: 'msg_cached_001',
        roomId: 'room_202',
        senderId: 'user_sender',
        content: 'Arrived at the lobby.',
        createdAt: DateTime.now(),
        clientMessageId: 'client_msg_cached_001',
        deliveryStatus: MessageDeliveryStatus.pending,
      );
      await localDb.saveChatMessage(initialMsg, status: 'pending');

      final messages = await offlineChatRepo.getMessages(roomId: 'room_202');
      expect(messages.isNotEmpty, isTrue);
      expect(messages.first.content, equals('Arrived at the lobby.'));
      expect(messages.first.deliveryStatus, equals(MessageDeliveryStatus.pending));
    });
  });
}
