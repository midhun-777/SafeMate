/// Supabase implementation of ChatRepository.
/// Universal Engineering Rule #7: Strict server-side enforcement.
/// Handles realtime subscriptions, offline development mode, and idempotency.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/models/chat_models.dart';
import '../../domain/repositories/chat_repository.dart';

class SupabaseChatRepository implements ChatRepository {
  final sb.SupabaseClient? client;
  final _uuid = const Uuid();

  // In-memory development storage for offline simulation
  final Map<String, ChatRoom> _devRooms = {};
  final Map<String, List<ChatMessage>> _devMessages = {};
  final Map<String, StreamController<ChatMessage>> _devMessageControllers = {};
  final Map<String, StreamController<String>> _devTypingControllers = {};

  // Active Supabase realtime channels
  final Map<String, sb.RealtimeChannel> _activeChannels = {};
  final Map<String, StreamController<ChatMessage>> _liveMessageControllers = {};
  final Map<String, StreamController<String>> _liveTypingControllers = {};

  SupabaseChatRepository({this.client});

  sb.SupabaseClient? get _activeClient =>
      client ?? (AppConfig.hasValidSupabaseConfig ? sb.Supabase.instance.client : null);

  @override
  Future<ChatRoom?> getChatRoomForConnection(String connectionId) async {
    final activeClient = _activeClient;

    if (activeClient == null) {
      for (final room in _devRooms.values) {
        if (room.connectionId == connectionId) return room;
      }
      // Create new dev room
      final newRoom = ChatRoom(
        id: 'room_$connectionId',
        connectionId: connectionId,
        createdAt: DateTime.now(),
      );
      _devRooms[newRoom.id] = newRoom;
      return newRoom;
    }

    try {
      final row = await activeClient
          .from('chat_rooms')
          .select()
          .eq('connection_id', connectionId)
          .maybeSingle();

      if (row != null) {
        return ChatRoom.fromJson(row);
      }

      // If not yet created, create one
      final inserted = await activeClient
          .from('chat_rooms')
          .insert({
            'connection_id': connectionId,
            'room_type': 'direct',
            'status': 'active',
          })
          .select()
          .single();

      return ChatRoom.fromJson(inserted);
    } catch (e) {
      debugPrint('[SafeMate Chat] getChatRoomForConnection error: $e');
      return null;
    }
  }

  @override
  Future<ChatRoom?> getChatRoom(String roomId) async {
    final activeClient = _activeClient;

    if (activeClient == null) {
      return _devRooms[roomId] ??
          ChatRoom(
            id: roomId,
            connectionId: 'dev_conn',
            createdAt: DateTime.now(),
          );
    }

    final row = await activeClient
        .from('chat_rooms')
        .select()
        .eq('id', roomId)
        .maybeSingle();

    return row != null ? ChatRoom.fromJson(row) : null;
  }

  @override
  Future<List<ChatMessage>> getMessages({
    required String roomId,
    int limit = 30,
    DateTime? before,
  }) async {
    final activeClient = _activeClient;

    if (activeClient == null) {
      final roomMsgs = _devMessages[roomId] ?? [];
      var filtered = List<ChatMessage>.from(roomMsgs);
      if (before != null) {
        filtered = filtered.where((m) => m.createdAt.isBefore(before)).toList();
      }
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final paged = filtered.take(limit).toList();
      paged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return paged;
    }

    try {
      var query = activeClient
          .from('messages')
          .select()
          .eq('room_id', roomId)
          .isFilter('deleted_at', null);

      if (before != null) {
        query = query.lt('created_at', before.toIso8601String());
      }

      final rows = await query
          .order('created_at', ascending: false)
          .limit(limit);

      final list = (rows as List).map((r) => ChatMessage.fromJson(r as Map<String, dynamic>)).toList();
      // Reverse to chronological order for UI rendering
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    } catch (e) {
      debugPrint('[SafeMate Chat] getMessages error: $e');
      return [];
    }
  }

  @override
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String senderId,
    required String content,
    required String clientMessageId,
  }) async {
    if (content.trim().isEmpty) {
      throw const AppException('Message content cannot be empty.', code: 'empty_content');
    }
    if (content.length > 4000) {
      throw const AppException(
        'Message exceeds maximum length of 4,000 characters.',
        code: 'message_too_long',
      );
    }

    final activeClient = _activeClient;

    if (activeClient == null) {
      return _sendDevMessage(
        roomId: roomId,
        senderId: senderId,
        content: content,
        clientMessageId: clientMessageId,
      );
    }

    try {
      // Call atomic RPC send_chat_message for server authorization and idempotency
      final response = await activeClient.rpc(
        'send_chat_message',
        params: {
          'p_room_id': roomId,
          'p_content': content,
          'p_client_message_id': clientMessageId,
        },
      );

      final msg = ChatMessage.fromJson(Map<String, dynamic>.from(response as Map));
      return msg;
    } catch (e) {
      debugPrint('[SafeMate Chat] sendMessage error: $e');
      throw AppException(
        'Failed to deliver message: $e',
        code: 'message_send_failed',
      );
    }
  }

  @override
  Future<void> markRoomAsRead({
    required String roomId,
    required String userId,
  }) async {
    final activeClient = _activeClient;

    if (activeClient == null) {
      final msgs = _devMessages[roomId];
      if (msgs != null) {
        for (var i = 0; i < msgs.length; i++) {
          if (msgs[i].senderId != userId) {
            msgs[i] = msgs[i].copyWith(deliveryStatus: MessageDeliveryStatus.read);
          }
        }
      }
      return;
    }

    try {
      await activeClient.rpc('mark_chat_room_read', params: {'p_room_id': roomId});
    } catch (e) {
      debugPrint('[SafeMate Chat] markRoomAsRead error: $e');
    }
  }

  @override
  Stream<ChatMessage> subscribeToMessages(String roomId) {
    final activeClient = _activeClient;

    if (activeClient == null) {
      final controller = _devMessageControllers.putIfAbsent(
        roomId,
        () => StreamController<ChatMessage>.broadcast(),
      );
      return controller.stream;
    }

    final controller = _liveMessageControllers.putIfAbsent(
      roomId,
      () => StreamController<ChatMessage>.broadcast(),
    );

    _ensureLiveChannel(roomId);
    return controller.stream;
  }

  @override
  Stream<String> subscribeToTyping(String roomId) {
    final activeClient = _activeClient;

    if (activeClient == null) {
      final controller = _devTypingControllers.putIfAbsent(
        roomId,
        () => StreamController<String>.broadcast(),
      );
      return controller.stream;
    }

    final controller = _liveTypingControllers.putIfAbsent(
      roomId,
      () => StreamController<String>.broadcast(),
    );

    _ensureLiveChannel(roomId);
    return controller.stream;
  }

  @override
  Future<void> sendTypingIndicator({
    required String roomId,
    required String userId,
  }) async {
    final activeClient = _activeClient;

    if (activeClient == null) {
      final controller = _devTypingControllers[roomId];
      controller?.add(userId);
      return;
    }

    final channel = _activeChannels[roomId];
    if (channel != null) {
      await channel.sendBroadcastMessage(
        event: 'typing',
        payload: {'user_id': userId},
      );
    }
  }

  void _ensureLiveChannel(String roomId) {
    if (_activeChannels.containsKey(roomId)) return;
    final activeClient = _activeClient;
    if (activeClient == null) return;

    final channel = activeClient.channel('room:$roomId');

    channel
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            final msg = ChatMessage.fromJson(newRecord);
            _liveMessageControllers[roomId]?.add(msg);
          },
        )
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final typingUserId = payload['user_id'] as String?;
            if (typingUserId != null) {
              _liveTypingControllers[roomId]?.add(typingUserId);
            }
          },
        )
        .subscribe();

    _activeChannels[roomId] = channel;
  }

  ChatMessage _sendDevMessage({
    required String roomId,
    required String senderId,
    required String content,
    required String clientMessageId,
  }) {
    final list = _devMessages.putIfAbsent(roomId, () => []);

    // Idempotency check: if clientMessageId exists, return it
    for (final existing in list) {
      if (existing.clientMessageId == clientMessageId) {
        return existing;
      }
    }

    final now = DateTime.now();
    final msg = ChatMessage(
      id: _uuid.v4(),
      roomId: roomId,
      senderId: senderId,
      clientMessageId: clientMessageId,
      content: content,
      deliveryStatus: MessageDeliveryStatus.sent,
      createdAt: now,
      updatedAt: now,
    );

    list.add(msg);
    _devMessageControllers[roomId]?.add(msg);
    return msg;
  }

  @override
  void dispose() {
    for (final channel in _activeChannels.values) {
      channel.unsubscribe();
    }
    _activeChannels.clear();
    for (final c in _liveMessageControllers.values) {
      c.close();
    }
    _liveMessageControllers.clear();
    for (final c in _liveTypingControllers.values) {
      c.close();
    }
    _liveTypingControllers.clear();
  }
}
