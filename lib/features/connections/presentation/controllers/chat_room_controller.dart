/// SafeMate Chat Room Controller.
/// Universal Engineering Rule #6: Strict domain boundaries, privacy-safe identity.
/// Universal Engineering Rule #11: Offline resilience, deduplication, deterministic state.
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/supabase_chat_repository.dart';
import '../../domain/models/chat_models.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/services/chat_offline_queue.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final repo = SupabaseChatRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});

class ChatRoomState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isLoadingOlder;
  final bool isSending;
  final bool hasMoreOlder;
  final String? errorMessage;
  final String? typingUserId;

  const ChatRoomState({
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingOlder = false,
    this.isSending = false,
    this.hasMoreOlder = true,
    this.errorMessage,
    this.typingUserId,
  });

  ChatRoomState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isLoadingOlder,
    bool? isSending,
    bool? hasMoreOlder,
    String? errorMessage,
    String? typingUserId,
    bool clearTyping = false,
  }) {
    return ChatRoomState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      isSending: isSending ?? this.isSending,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      errorMessage: errorMessage,
      typingUserId: clearTyping ? null : (typingUserId ?? this.typingUserId),
    );
  }
}

class ChatRoomController extends StateNotifier<ChatRoomState> {
  final String roomId;
  final ChatRepository _repository;
  final AnalyticsService _analytics;
  final String? _currentUserId;
  final ChatOfflineQueue _offlineQueue = ChatOfflineQueue();
  final _uuid = const Uuid();

  StreamSubscription<ChatMessage>? _messageSub;
  StreamSubscription<String>? _typingSub;
  Timer? _typingExpiryTimer;
  Timer? _readThrottleTimer;

  ChatRoomController({
    required this.roomId,
    required this._repository,
    required this._analytics,
    required this._currentUserId,
  }) : super(const ChatRoomState()) {
    _init();
  }

  void _init() {
    _subscribeToStreams();
    loadMessages();
    _analytics.logEvent('chat_opened', parameters: {'room_id': roomId});
  }

  void _subscribeToStreams() {
    _messageSub?.cancel();
    _messageSub = _repository.subscribeToMessages(roomId).listen((newMsg) {
      _handleIncomingMessage(newMsg);
    });

    _typingSub?.cancel();
    _typingSub = _repository.subscribeToTyping(roomId).listen((userId) {
      if (userId != _currentUserId) {
        state = state.copyWith(typingUserId: userId);
        _typingExpiryTimer?.cancel();
        _typingExpiryTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            state = state.copyWith(clearTyping: true);
          }
        });
      }
    });
  }

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final msgs = await _repository.getMessages(roomId: roomId, limit: 30);
      state = state.copyWith(
        messages: msgs,
        isLoading: false,
        hasMoreOlder: msgs.length >= 30,
      );
      markAsRead();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load messages: $e',
      );
    }
  }

  Future<void> loadOlderMessages() async {
    if (state.isLoadingOlder || !state.hasMoreOlder || state.messages.isEmpty) {
      return;
    }

    state = state.copyWith(isLoadingOlder: true);
    try {
      final oldest = state.messages.first;
      final older = await _repository.getMessages(
        roomId: roomId,
        limit: 30,
        before: oldest.createdAt,
      );

      final combined = [...older, ...state.messages];
      state = state.copyWith(
        messages: combined,
        isLoadingOlder: false,
        hasMoreOlder: older.length >= 30,
      );
    } catch (e) {
      state = state.copyWith(isLoadingOlder: false);
    }
  }

  Future<void> sendMessage(String content) async {
    final senderId = _currentUserId;
    final trimmed = content.trim();
    if (senderId == null || trimmed.isEmpty) return;

    final clientMessageId = _uuid.v4();
    final now = DateTime.now();

    // 1. Optimistic pending message
    final optimisticMsg = ChatMessage(
      id: clientMessageId,
      roomId: roomId,
      senderId: senderId,
      clientMessageId: clientMessageId,
      content: trimmed,
      deliveryStatus: MessageDeliveryStatus.pending,
      createdAt: now,
      updatedAt: now,
    );

    _offlineQueue.enqueue(optimisticMsg);
    final updatedList = List<ChatMessage>.from(state.messages)..add(optimisticMsg);
    state = state.copyWith(messages: updatedList, isSending: true);

    await _analytics.logEvent('message_send_started', parameters: {
      'room_id': roomId,
    });

    try {
      final confirmed = await _repository.sendMessage(
        roomId: roomId,
        senderId: senderId,
        content: trimmed,
        clientMessageId: clientMessageId,
      );

      _offlineQueue.remove(clientMessageId);

      // Update message in state to sent
      final finalMessages = state.messages.map((m) {
        if (m.clientMessageId == clientMessageId) {
          return confirmed;
        }
        return m;
      }).toList();

      state = state.copyWith(messages: finalMessages, isSending: false);

      await _analytics.logEvent('message_sent', parameters: {
        'room_id': roomId,
        'message_id': confirmed.id,
      });
    } catch (e) {
      _offlineQueue.markFailed(clientMessageId);

      final failedMessages = state.messages.map((m) {
        if (m.clientMessageId == clientMessageId) {
          return m.copyWith(deliveryStatus: MessageDeliveryStatus.failed);
        }
        return m;
      }).toList();

      state = state.copyWith(
        messages: failedMessages,
        isSending: false,
        errorMessage: 'Failed to deliver message. Tap to retry.',
      );

      await _analytics.logEvent('message_failed', parameters: {
        'room_id': roomId,
      });
    }
  }

  Future<void> retryMessage(ChatMessage message) async {
    final senderId = _currentUserId;
    if (senderId == null) return;

    await _analytics.logEvent('message_retry', parameters: {
      'room_id': roomId,
    });

    // Mark pending again
    final retrying = state.messages.map((m) {
      if (m.clientMessageId == message.clientMessageId) {
        return m.copyWith(deliveryStatus: MessageDeliveryStatus.pending);
      }
      return m;
    }).toList();
    state = state.copyWith(messages: retrying, errorMessage: null);

    try {
      final confirmed = await _repository.sendMessage(
        roomId: roomId,
        senderId: senderId,
        content: message.content,
        clientMessageId: message.clientMessageId,
      );

      _offlineQueue.remove(message.clientMessageId);

      final finalMessages = state.messages.map((m) {
        if (m.clientMessageId == message.clientMessageId) {
          return confirmed;
        }
        return m;
      }).toList();

      state = state.copyWith(messages: finalMessages);
    } catch (e) {
      _offlineQueue.markFailed(message.clientMessageId);

      final failedMessages = state.messages.map((m) {
        if (m.clientMessageId == message.clientMessageId) {
          return m.copyWith(deliveryStatus: MessageDeliveryStatus.failed);
        }
        return m;
      }).toList();

      state = state.copyWith(
        messages: failedMessages,
        errorMessage: 'Retry failed. Please check your connection.',
      );
    }
  }

  void _handleIncomingMessage(ChatMessage newMsg) {
    // Deduplication check: if message already exists by id or clientMessageId, update it
    final index = state.messages.indexWhere(
      (m) => m.id == newMsg.id || m.clientMessageId == newMsg.clientMessageId,
    );

    if (index >= 0) {
      final updated = List<ChatMessage>.from(state.messages);
      updated[index] = newMsg;
      state = state.copyWith(messages: updated);
    } else {
      final updated = List<ChatMessage>.from(state.messages)..add(newMsg);
      state = state.copyWith(messages: updated);
    }

    if (newMsg.senderId != _currentUserId) {
      markAsRead();
    }
  }

  void markAsRead() {
    final userId = _currentUserId;
    if (userId == null) return;

    _readThrottleTimer?.cancel();
    _readThrottleTimer = Timer(const Duration(milliseconds: 500), () {
      _repository.markRoomAsRead(roomId: roomId, userId: userId);
    });
  }

  void sendTyping() {
    final userId = _currentUserId;
    if (userId == null) return;
    _repository.sendTypingIndicator(roomId: roomId, userId: userId);
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _typingSub?.cancel();
    _typingExpiryTimer?.cancel();
    _readThrottleTimer?.cancel();
    super.dispose();
  }
}

final chatRoomControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatRoomController, ChatRoomState, String>((ref, roomId) {
  final repo = ref.watch(chatRepositoryProvider);
  final analytics = ref.watch(analyticsServiceProvider);
  final authState = ref.watch(authControllerProvider);
  final userId = authState.profile?.id ?? authState.session?.userId;

  return ChatRoomController(
    roomId: roomId,
    repository: repo,
    analytics: analytics,
    currentUserId: userId,
  );
});
