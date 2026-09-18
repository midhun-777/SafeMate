import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/sync/sync_engine.dart';
import 'package:safemate/features/connections/data/repositories/offline_first_chat_repository.dart';
import 'package:safemate/features/connections/data/repositories/supabase_chat_repository.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late LocalDatabaseService dbService;
  late SyncEngine syncEngine;
  late OfflineFirstChatRepository offlineChatRepo;
  late SupabaseChatRepository remoteChatRepo;

  setUp(() async {
    dbService = LocalDatabaseService();
    await dbService.init(
      databaseFactory: databaseFactoryFfi,
      dbName: 'chat_offline_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    syncEngine = SyncEngine(localDb: dbService);
    remoteChatRepo = SupabaseChatRepository(); // In dev offline mode
    offlineChatRepo = OfflineFirstChatRepository(
      remoteRepo: remoteChatRepo,
      localDb: dbService,
      syncEngine: syncEngine,
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await dbService.close();
  });

  group('Phase 12.7 OfflineFirstChatRepository Tests', () {
    test('sendMessage creates local outbox message with clientMessageId and delivers', () async {
      final msg = await offlineChatRepo.sendMessage(
        roomId: 'room_123',
        senderId: 'user_alice',
        content: 'Meet at the train platform at 10 AM',
        clientMessageId: 'client_msg_uuid_001',
      );

      expect(msg.content, 'Meet at the train platform at 10 AM');
      expect(msg.clientMessageId, 'client_msg_uuid_001');

      // Verify cached in SQLite
      final localMsgs = await dbService.getRoomMessages('room_123');
      expect(localMsgs.length, 1);
      expect(localMsgs.first.clientMessageId, 'client_msg_uuid_001');
    });

    test('getMessages reads local cached messages immediately', () async {
      await offlineChatRepo.sendMessage(
        roomId: 'room_456',
        senderId: 'user_bob',
        content: 'Arrived at the hotel.',
        clientMessageId: 'client_msg_uuid_002',
      );

      final fetched = await offlineChatRepo.getMessages(roomId: 'room_456');
      expect(fetched.length, 1);
      expect(fetched.first.content, 'Arrived at the hotel.');
    });
  });
}
