/// Supabase implementation of ConnectionRepository.
/// Universal Engineering Rule #7: Strict server-side enforcement.
/// Supports offline development mode and live Supabase PostgREST & RPCs.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/models/connection.dart';
import '../../domain/models/connection_item.dart';
import '../../domain/repositories/connection_repository.dart';
import '../../domain/services/connection_state_machine.dart';

class SupabaseConnectionRepository implements ConnectionRepository {
  final sb.SupabaseClient? client;
  final ConnectionStateMachine stateMachine;
  final _uuid = const Uuid();

  // In-memory development storage for offline mode and tests
  final Map<String, Connection> _devConnections = {};
  final Map<String, Map<String, dynamic>> _devProfiles = {};
  final Map<String, Map<String, dynamic>> _devTrips = {};
  final Set<String> _devBlockedPairs = {};

  SupabaseConnectionRepository({
    this.client,
    this.stateMachine = const ConnectionStateMachine(),
  });

  sb.SupabaseClient? get _activeClient =>
      client ?? (AppConfig.hasValidSupabaseConfig ? sb.Supabase.instance.client : null);

  @override
  Future<Connection> sendConnectionRequest({
    required String requesterId,
    required String receiverId,
    required String requesterTripId,
    String? recipientTripId,
  }) async {
    final activeClient = _activeClient;

    if (activeClient == null) {
      return _sendDevRequest(
        requesterId: requesterId,
        receiverId: receiverId,
        requesterTripId: requesterTripId,
        recipientTripId: recipientTripId,
      );
    }

    try {
      // 1. Check blocked status
      final isBlocked = await _checkIfBlocked(activeClient, requesterId, receiverId);
      final hasActive = await findActiveRequestBetween(
        requesterId: requesterId,
        receiverId: receiverId,
      );

      stateMachine.validateSendRequest(
        requesterId: requesterId,
        receiverId: receiverId,
        isBlocked: isBlocked,
        isSuspended: false,
        hasExistingActiveRequest: hasActive != null,
      );

      final now = DateTime.now().toUtc();
      final insertData = {
        'requester_id': requesterId,
        'receiver_id': receiverId,
        'trip_id': requesterTripId,
        'requester_trip_id': requesterTripId,
        'recipient_trip_id': ?recipientTripId,
        'status': 'pending',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await activeClient
          .from('connections')
          .insert(insertData)
          .select()
          .single();

      return Connection.fromJson(response);
    } catch (e) {
      if (e is ConnectionStateTransitionException) rethrow;
      throw AppException(
        'Failed to send connection request: $e',
        code: 'connection_send_failed',
      );
    }
  }

  @override
  Future<Connection> acceptConnectionRequest({
    required String requestId,
    required String receiverId,
  }) async {
    final activeClient = _activeClient;

    if (activeClient == null) {
      return _acceptDevRequest(requestId: requestId, receiverId: receiverId);
    }

    try {
      // Call atomic RPC
      final result = await activeClient.rpc(
        'accept_connection_request',
        params: {'p_request_id': requestId},
      );

      if (kDebugMode) {
        debugPrint('[SafeMate Connection] Accepted request RPC result: $result');
      }

      final row = await activeClient
          .from('connections')
          .select()
          .eq('id', requestId)
          .single();

      return Connection.fromJson(row);
    } catch (e) {
      throw AppException(
        'Failed to accept connection request: $e',
        code: 'connection_accept_failed',
      );
    }
  }

  @override
  Future<Connection> declineConnectionRequest({
    required String requestId,
    required String receiverId,
  }) async {
    final activeClient = _activeClient;

    if (activeClient == null) {
      return _declineDevRequest(requestId: requestId, receiverId: receiverId);
    }

    try {
      await activeClient.rpc(
        'decline_connection_request',
        params: {'p_request_id': requestId},
      );

      final row = await activeClient
          .from('connections')
          .select()
          .eq('id', requestId)
          .single();

      return Connection.fromJson(row);
    } catch (e) {
      throw AppException(
        'Failed to decline connection request: $e',
        code: 'connection_decline_failed',
      );
    }
  }

  @override
  Future<Connection> cancelConnectionRequest({
    required String requestId,
    required String requesterId,
  }) async {
    final activeClient = _activeClient;

    if (activeClient == null) {
      return _cancelDevRequest(requestId: requestId, requesterId: requesterId);
    }

    try {
      await activeClient.rpc(
        'cancel_connection_request',
        params: {'p_request_id': requestId},
      );

      final row = await activeClient
          .from('connections')
          .select()
          .eq('id', requestId)
          .single();

      return Connection.fromJson(row);
    } catch (e) {
      throw AppException(
        'Failed to cancel connection request: $e',
        code: 'connection_cancel_failed',
      );
    }
  }

  @override
  Future<Connection?> getConnection(String connectionId) async {
    final activeClient = _activeClient;

    if (activeClient == null) {
      return _devConnections[connectionId];
    }

    final row = await activeClient
        .from('connections')
        .select()
        .eq('id', connectionId)
        .maybeSingle();

    return row != null ? Connection.fromJson(row) : null;
  }

  @override
  Future<List<ConnectionItem>> getActiveConnections(String userId) async {
    final activeClient = _activeClient;

    if (activeClient == null) {
      return _getDevConnectionItems(
        userId: userId,
        filter: (c) => c.isAccepted,
      );
    }

    final rows = await activeClient
        .from('connections')
        .select('*, requester:profiles!requester_id(*), receiver:profiles!receiver_id(*), trips!trip_id(*), chat_rooms(*)')
        .eq('status', 'accepted')
        .or('requester_id.eq.$userId,receiver_id.eq.$userId')
        .order('updated_at', ascending: false);

    return _mapRowsToConnectionItems(rows as List, userId);
  }

  @override
  Future<List<ConnectionItem>> getPendingRequestsReceived(String userId) async {
    final activeClient = _activeClient;

    if (activeClient == null) {
      return _getDevConnectionItems(
        userId: userId,
        filter: (c) => c.isPending && c.receiverId == userId,
      );
    }

    final rows = await activeClient
        .from('connections')
        .select('*, requester:profiles!requester_id(*), trips!trip_id(*)')
        .eq('receiver_id', userId)
        .or('status.eq.pending,status.eq.requested')
        .order('created_at', ascending: false);

    return _mapRowsToConnectionItems(rows as List, userId);
  }

  @override
  Future<List<ConnectionItem>> getPendingRequestsSent(String userId) async {
    final activeClient = _activeClient;

    if (activeClient == null) {
      return _getDevConnectionItems(
        userId: userId,
        filter: (c) => c.isPending && c.requesterId == userId,
      );
    }

    final rows = await activeClient
        .from('connections')
        .select('*, receiver:profiles!receiver_id(*), trips!trip_id(*)')
        .eq('requester_id', userId)
        .or('status.eq.pending,status.eq.requested')
        .order('created_at', ascending: false);

    return _mapRowsToConnectionItems(rows as List, userId);
  }

  @override
  Future<List<ConnectionItem>> getPastConnections(String userId) async {
    final activeClient = _activeClient;

    if (activeClient == null) {
      return _getDevConnectionItems(
        userId: userId,
        filter: (c) => c.isDeclined || c.isCancelled,
      );
    }

    final rows = await activeClient
        .from('connections')
        .select('*, requester:profiles!requester_id(*), receiver:profiles!receiver_id(*), trips!trip_id(*)')
        .or('requester_id.eq.$userId,receiver_id.eq.$userId')
        .inFilter('status', ['declined', 'cancelled', 'rejected'])
        .order('updated_at', ascending: false);

    return _mapRowsToConnectionItems(rows as List, userId);
  }

  @override
  Future<Connection?> findActiveRequestBetween({
    required String requesterId,
    required String receiverId,
    String? tripId,
  }) async {
    final activeClient = _activeClient;

    if (activeClient == null) {
      for (final conn in _devConnections.values) {
        if (conn.isPending &&
            ((conn.requesterId == requesterId && conn.receiverId == receiverId) ||
                (conn.requesterId == receiverId && conn.receiverId == requesterId))) {
          return conn;
        }
      }
      return null;
    }

    var query = activeClient
        .from('connections')
        .select()
        .or('status.eq.pending,status.eq.requested')
        .or('and(requester_id.eq.$requesterId,receiver_id.eq.$receiverId),and(requester_id.eq.$receiverId,receiver_id.eq.$requesterId)');

    final rows = await query;
    final list = rows as List;
    if (list.isEmpty) return null;
    return Connection.fromJson(list.first as Map<String, dynamic>);
  }

  @override
  Future<void> blockConnection({
    required String blockerId,
    required String blockedId,
  }) async {
    final activeClient = _activeClient;

    if (activeClient == null) {
      final pair = [blockerId, blockedId]..sort();
      _devBlockedPairs.add('${pair[0]}_${pair[1]}');

      // Update any existing connection
      for (final key in _devConnections.keys.toList()) {
        final c = _devConnections[key]!;
        if ((c.requesterId == blockerId && c.receiverId == blockedId) ||
            (c.requesterId == blockedId && c.receiverId == blockerId)) {
          _devConnections[key] = c.copyWith(status: 'blocked');
        }
      }
      return;
    }

    await activeClient.from('blocks').upsert({
      'blocker_id': blockerId,
      'blocked_id': blockedId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    await activeClient
        .from('connections')
        .update({'status': 'blocked'})
        .or('and(requester_id.eq.$blockerId,receiver_id.eq.$blockedId),and(requester_id.eq.$blockedId,receiver_id.eq.$blockerId)');
  }

  Future<bool> _checkIfBlocked(
    sb.SupabaseClient client,
    String userA,
    String userB,
  ) async {
    final rows = await client
        .from('blocks')
        .select('id')
        .or('and(blocker_id.eq.$userA,blocked_id.eq.$userB),and(blocker_id.eq.$userB,blocked_id.eq.$userA)')
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  List<ConnectionItem> _mapRowsToConnectionItems(List rows, String currentUserId) {
    return rows.map<ConnectionItem>((row) {
      final map = row as Map<String, dynamic>;
      final conn = Connection.fromJson(map);
      final isRequester = conn.requesterId == currentUserId;

      final companionProfile = isRequester
          ? (map['receiver'] as Map<String, dynamic>?)
          : (map['requester'] as Map<String, dynamic>?);

      final tripMap = map['trips'] as Map<String, dynamic>?;
      final roomsList = map['chat_rooms'] as List?;
      final roomId = roomsList != null && roomsList.isNotEmpty
          ? (roomsList.first as Map<String, dynamic>)['id'] as String?
          : null;

      return ConnectionItem(
        connection: conn,
        companionUserId: isRequester ? conn.receiverId : conn.requesterId,
        companionName: (companionProfile?['display_name'] as String?)?.isNotEmpty == true
            ? companionProfile!['display_name'] as String
            : 'Travel Companion',
        companionAvatarUrl: companionProfile?['avatar_url'] as String?,
        trustScore: (companionProfile?['trust_score'] as num?)?.toInt() ?? 80,
        destination: (tripMap?['destination'] as String?) ?? 'Destination',
        origin: (tripMap?['origin'] as String?) ?? 'Origin',
        startDate: tripMap?['start_date'] != null
            ? DateTime.parse(tripMap!['start_date'] as String)
            : null,
        endDate: tripMap?['end_date'] != null
            ? DateTime.parse(tripMap!['end_date'] as String)
            : null,
        roomId: roomId,
      );
    }).toList();
  }

  // ============================================================================
  // OFFLINE DEV MODE IMPLEMENTATION
  // ============================================================================

  void seedDevProfile(String userId, Map<String, dynamic> profile) {
    _devProfiles[userId] = profile;
  }

  void seedDevTrip(String tripId, Map<String, dynamic> trip) {
    _devTrips[tripId] = trip;
  }

  Future<Connection> _sendDevRequest({
    required String requesterId,
    required String receiverId,
    required String requesterTripId,
    String? recipientTripId,
  }) async {
    final pair = [requesterId, receiverId]..sort();
    final isBlocked = _devBlockedPairs.contains('${pair[0]}_${pair[1]}');

    final hasActive = await findActiveRequestBetween(
      requesterId: requesterId,
      receiverId: receiverId,
    );

    stateMachine.validateSendRequest(
      requesterId: requesterId,
      receiverId: receiverId,
      isBlocked: isBlocked,
      isSuspended: false,
      hasExistingActiveRequest: hasActive != null,
    );

    final conn = Connection(
      id: _uuid.v4(),
      requesterId: requesterId,
      receiverId: receiverId,
      tripId: requesterTripId,
      requesterTripId: requesterTripId,
      recipientTripId: recipientTripId,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    _devConnections[conn.id] = conn;
    return conn;
  }

  Future<Connection> _acceptDevRequest({
    required String requestId,
    required String receiverId,
  }) async {
    final existing = _devConnections[requestId];
    if (existing == null) {
      throw const AppException('Connection request not found.', code: 'not_found');
    }

    final pair = [existing.requesterId, existing.receiverId]..sort();
    final isBlocked = _devBlockedPairs.contains('${pair[0]}_${pair[1]}');

    stateMachine.validateAcceptRequest(
      actorId: receiverId,
      receiverId: existing.receiverId,
      currentStatus: existing.requestStatus,
      isBlocked: isBlocked,
    );

    final updated = existing.copyWith(
      status: 'accepted',
      acceptedAt: DateTime.now(),
      respondedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _devConnections[requestId] = updated;
    return updated;
  }

  Future<Connection> _declineDevRequest({
    required String requestId,
    required String receiverId,
  }) async {
    final existing = _devConnections[requestId];
    if (existing == null) {
      throw const AppException('Connection request not found.', code: 'not_found');
    }

    stateMachine.validateDeclineRequest(
      actorId: receiverId,
      receiverId: existing.receiverId,
      currentStatus: existing.requestStatus,
    );

    final updated = existing.copyWith(
      status: 'declined',
      respondedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _devConnections[requestId] = updated;
    return updated;
  }

  Future<Connection> _cancelDevRequest({
    required String requestId,
    required String requesterId,
  }) async {
    final existing = _devConnections[requestId];
    if (existing == null) {
      throw const AppException('Connection request not found.', code: 'not_found');
    }

    stateMachine.validateCancelRequest(
      actorId: requesterId,
      requesterId: existing.requesterId,
      currentStatus: existing.requestStatus,
    );

    final updated = existing.copyWith(
      status: 'cancelled',
      updatedAt: DateTime.now(),
    );
    _devConnections[requestId] = updated;
    return updated;
  }

  List<ConnectionItem> _getDevConnectionItems({
    required String userId,
    required bool Function(Connection c) filter,
  }) {
    final items = <ConnectionItem>[];
    for (final conn in _devConnections.values.where(filter)) {
      final isRequester = conn.requesterId == userId;
      final companionId = isRequester ? conn.receiverId : conn.requesterId;
      final companionProfile = _devProfiles[companionId];
      final trip = _devTrips[conn.tripId ?? ''];

      items.add(
        ConnectionItem(
          connection: conn,
          companionUserId: companionId,
          companionName: (companionProfile?['display_name'] as String?) ??
              (companionProfile?['name'] as String?) ??
              'Companion $companionId',
          companionAvatarUrl: companionProfile?['avatar_url'] as String?,
          trustScore: (companionProfile?['trust_score'] as int?) ?? 85,
          destination: (trip?['destination'] as String?) ?? 'Destination',
          origin: (trip?['origin'] as String?) ?? 'Origin',
          startDate: trip?['start_date'] != null
              ? DateTime.parse(trip!['start_date'] as String)
              : null,
          endDate: trip?['end_date'] != null
              ? DateTime.parse(trip!['end_date'] as String)
              : null,
          roomId: 'room_${conn.id}',
        ),
      );
    }
    items.sort((a, b) => b.connection.createdAt.compareTo(a.connection.createdAt));
    return items;
  }
}
