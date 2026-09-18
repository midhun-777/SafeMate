/// SafeMate Offline-First Chat Repository with Local Outbox.
/// Universal Engineering Rule #7: Server authorization on message delivery.
/// Universal Engineering Rule #11: Idempotency with client_message_id.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/database/local_database_service.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../domain/models/chat_models.dart';
import '../../domain/repositories/chat_repository.dart';

class OfflineFirstChatRepository implements ChatRepository {
  final ChatRepository _remoteRepo;
  final LocalDatabaseService _localDb;
  final SyncEngine? _syncEngine;

  OfflineFirstChatRepository({
    required ChatRepository remoteRepo,
    required LocalDatabaseService localDb,
    SyncEngine? syncEngine,
  })  : _remoteRepo = remoteRepo, // ignore: prefer_initializing_formals
        _localDb = localDb, // ignore: prefer_initializing_formals
        _syncEngine = syncEngine { // ignore: prefer_initializing_formals
    _syncEngine?.registerHandler('chat', _handleSyncMutation);
  }

  /// Dispatches queued outbox messages to Supabase via atomic RPC.
  Future<void> _handleSyncMutation(SyncRecord record) async {
    if (record.action == 'send_message') {
      final payload = record.payload;
      final roomId = payload['room_id'] as String;
      final senderId = payload['sender_id'] as String;
      final content = payload['content'] as String;
      final clientMessageId = payload['client_message_id'] as String;

      // Atomic RPC call re-checks server authorization (blocklist, membership)
      final serverMsg = await _remoteRepo.sendMessage(
        roomId: roomId,
        senderId: senderId,
        content: content,
        clientMessageId: clientMessageId,
      );

      // Reconcile local message to sent
      await _localDb.saveChatMessage(serverMsg, status: 'sent');
    }
  }

  @override
  Future<ChatRoom?> getChatRoomForConnection(String connectionId) {
    return _remoteRepo.getChatRoomForConnection(connectionId);
  }

  @override
  Future<ChatRoom?> getChatRoom(String roomId) {
    return _remoteRepo.getChatRoom(roomId);
  }

  @override
  Future<List<ChatMessage>> getMessages({
    required String roomId,
    int limit = 30,
    DateTime? before,
  }) async {
    // 1. Read local SQLite messages immediately
    final localMessages = await _localDb.getRoomMessages(roomId, limit: limit);

    // 2. Fetch remote messages in background if online
    try {
      final remoteMessages = await _remoteRepo.getMessages(
        roomId: roomId,
        limit: limit,
        before: before,
      );
      for (final msg in remoteMessages) {
        await _localDb.saveChatMessage(msg, status: 'delivered');
      }
      final updatedLocal = await _localDb.getRoomMessages(roomId, limit: limit);
      return updatedLocal.isNotEmpty ? updatedLocal : remoteMessages;
    } catch (_) {
      // Offline fallback: return local outbox/messages
      return localMessages;
    }
  }

  @override
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String senderId,
    required String content,
    required String clientMessageId,
  }) async {
    final now = DateTime.now();
    final localMsg = ChatMessage(
      id: 'local_${now.millisecondsSinceEpoch}',
      roomId: roomId,
      senderId: senderId,
      content: content,
      createdAt: now,
      clientMessageId: clientMessageId,
      deliveryStatus: MessageDeliveryStatus.pending,
    );

    // 1. Save to local SQLite outbox with pending status
    await _localDb.saveChatMessage(localMsg, status: 'pending');

    // 2. Attempt remote delivery via RPC
    try {
      final serverMsg = await _remoteRepo.sendMessage(
        roomId: roomId,
        senderId: senderId,
        content: content,
        clientMessageId: clientMessageId,
      );
      // Remove temporary outbox placeholder if server assigned a different authoritative ID
      if (localMsg.id != serverMsg.id) {
        await _localDb.deleteChatMessage(localMsg.id);
      }
      // Update local message to sent
      await _localDb.saveChatMessage(serverMsg, status: 'sent');
      return serverMsg;
    } catch (e) {
      debugPrint('[SafeMate OfflineChatRepo] Message saved to local outbox awaiting network: $e');
      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          userId: senderId,
          entityType: 'chat',
          entityId: clientMessageId,
          action: 'send_message',
          payload: {
            'room_id': roomId,
            'sender_id': senderId,
            'content': content,
            'client_message_id': clientMessageId,
          },
        );
      }
      return localMsg;
    }
  }

  @override
  Stream<ChatMessage> subscribeToMessages(String roomId) {
    // Realtime reconciliation: persist incoming realtime messages to local SQLite
    return _remoteRepo.subscribeToMessages(roomId).map((msg) {
      _localDb.saveChatMessage(msg, status: 'delivered');
      return msg;
    });
  }

  @override
  Stream<String> subscribeToTyping(String roomId) {
    return _remoteRepo.subscribeToTyping(roomId);
  }

  @override
  Future<void> sendTypingIndicator({
    required String roomId,
    required String userId,
  }) {
    return _remoteRepo.sendTypingIndicator(
      roomId: roomId,
      userId: userId,
    );
  }

  @override
  Future<void> markRoomAsRead({
    required String roomId,
    required String userId,
  }) {
    return _remoteRepo.markRoomAsRead(roomId: roomId, userId: userId);
  }

  @override
  void dispose() {
    _remoteRepo.dispose();
  }
}
