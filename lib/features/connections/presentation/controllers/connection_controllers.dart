/// SafeMate Riverpod Controllers for Connection Requests and Connections List.
/// Universal Engineering Rule #6: Strict domain boundaries.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/supabase_connection_repository.dart';
import '../../domain/models/connection.dart';
import '../../domain/models/connection_item.dart';
import '../../domain/repositories/connection_repository.dart';

/// Provider for ConnectionRepository.
final connectionRepositoryProvider = Provider<ConnectionRepository>((ref) {
  return SupabaseConnectionRepository();
});

/// State for Connections List Screen.
class ConnectionsListState {
  final List<ConnectionItem> active;
  final List<ConnectionItem> pendingReceived;
  final List<ConnectionItem> pendingSent;
  final List<ConnectionItem> past;
  final bool isLoading;
  final String? errorMessage;

  const ConnectionsListState({
    this.active = const [],
    this.pendingReceived = const [],
    this.pendingSent = const [],
    this.past = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ConnectionsListState copyWith({
    List<ConnectionItem>? active,
    List<ConnectionItem>? pendingReceived,
    List<ConnectionItem>? pendingSent,
    List<ConnectionItem>? past,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ConnectionsListState(
      active: active ?? this.active,
      pendingReceived: pendingReceived ?? this.pendingReceived,
      pendingSent: pendingSent ?? this.pendingSent,
      past: past ?? this.past,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Controller managing connections lists across tabs.
class ConnectionsListController extends StateNotifier<ConnectionsListState> {
  final ConnectionRepository _repository;
  final AnalyticsService _analytics;
  final String? _currentUserId;

  ConnectionsListController({
    required this._repository,
    required this._analytics,
    required this._currentUserId,
  }) : super(const ConnectionsListState()) {
    if (_currentUserId != null) {
      loadAll();
    }
  }

  Future<void> loadAll() async {
    final userId = _currentUserId;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final active = await _repository.getActiveConnections(userId);
      final received = await _repository.getPendingRequestsReceived(userId);
      final sent = await _repository.getPendingRequestsSent(userId);
      final past = await _repository.getPastConnections(userId);

      state = state.copyWith(
        active: active,
        pendingReceived: received,
        pendingSent: sent,
        past: past,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load connections: $e',
      );
    }
  }

  Future<bool> acceptRequest(String requestId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      await _repository.acceptConnectionRequest(
        requestId: requestId,
        receiverId: userId,
      );
      await _analytics.logEvent('connection_request_accepted', parameters: {
        'request_id': requestId,
      });
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to accept request: $e');
      return false;
    }
  }

  Future<bool> declineRequest(String requestId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      await _repository.declineConnectionRequest(
        requestId: requestId,
        receiverId: userId,
      );
      await _analytics.logEvent('connection_request_declined', parameters: {
        'request_id': requestId,
      });
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to decline request: $e');
      return false;
    }
  }

  Future<bool> cancelRequest(String requestId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      await _repository.cancelConnectionRequest(
        requestId: requestId,
        requesterId: userId,
      );
      await _analytics.logEvent('connection_request_cancelled', parameters: {
        'request_id': requestId,
      });
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to cancel request: $e');
      return false;
    }
  }
}

/// Provider for ConnectionsListController.
final connectionsListControllerProvider =
    StateNotifierProvider<ConnectionsListController, ConnectionsListState>((ref) {
  final repo = ref.watch(connectionRepositoryProvider);
  final analytics = ref.watch(analyticsServiceProvider);
  final authState = ref.watch(authControllerProvider);
  final userId = authState.profile?.id ?? authState.session?.userId;

  return ConnectionsListController(
    repository: repo,
    analytics: analytics,
    currentUserId: userId,
  );
});

/// Controller for single connection actions (e.g. sending request from Match Detail).
class ConnectionActionController extends StateNotifier<AsyncValue<Connection?>> {
  final ConnectionRepository _repository;
  final AnalyticsService _analytics;

  ConnectionActionController({
    required this._repository,
    required this._analytics,
  }) : super(const AsyncValue.data(null));

  Future<Connection?> sendRequest({
    required String requesterId,
    required String receiverId,
    required String requesterTripId,
    String? recipientTripId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _analytics.logEvent('connection_request_started', parameters: {
        'trip_id': requesterTripId,
      });

      final conn = await _repository.sendConnectionRequest(
        requesterId: requesterId,
        receiverId: receiverId,
        requesterTripId: requesterTripId,
        recipientTripId: recipientTripId,
      );

      await _analytics.logEvent('connection_request_sent', parameters: {
        'connection_id': conn.id,
        'trip_id': requesterTripId,
      });

      state = AsyncValue.data(conn);
      return conn;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Connection?> checkExistingRequest({
    required String requesterId,
    required String receiverId,
  }) async {
    return _repository.findActiveRequestBetween(
      requesterId: requesterId,
      receiverId: receiverId,
    );
  }
}

final connectionActionControllerProvider =
    StateNotifierProvider<ConnectionActionController, AsyncValue<Connection?>>((ref) {
  final repo = ref.watch(connectionRepositoryProvider);
  final analytics = ref.watch(analyticsServiceProvider);

  return ConnectionActionController(
    repository: repo,
    analytics: analytics,
  );
});
