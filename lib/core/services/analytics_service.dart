/// Privacy-conscious analytics service conforming to SafeMate telemetry principles.
/// Universal Engineering Rule #10: Privacy-first analytics. Never logs PII, exact coordinates, secrets, or message bodies.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for AnalyticsService.
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return const SafeMateAnalyticsService();
});

abstract class AnalyticsService {
  Future<void> logEvent(String name, {Map<String, dynamic>? parameters});
}

class SafeMateAnalyticsService implements AnalyticsService {
  const SafeMateAnalyticsService();

  static const Set<String> _forbiddenKeys = {
    'phone',
    'phone_number',
    'email',
    'address',
    'lat',
    'latitude',
    'lon',
    'longitude',
    'coordinates',
    'emergency_contact',
    'password',
    'token',
    'auth_token',
    'body',
    'message_body',
    'content',
    'message',
  };

  @override
  Future<void> logEvent(String name, {Map<String, dynamic>? parameters}) async {
    final sanitizedParams = <String, dynamic>{};

    if (parameters != null) {
      for (final entry in parameters.entries) {
        final keyLower = entry.key.toLowerCase();
        if (_forbiddenKeys.contains(keyLower)) {
          continue; // Strip forbidden PII & sensitive content keys
        }
        sanitizedParams[entry.key] = entry.value;
      }
    }

    if (kDebugMode) {
      debugPrint('[SafeMate Analytics] Event: $name | Params: $sanitizedParams');
    }
  }

  // Phase 7 Matching & Discovery Helpers
  Future<void> logMatchDiscoveryOpened(String tripId) =>
      logEvent('match_discovery_opened', parameters: {'trip_id': tripId});

  Future<void> logMatchesLoaded({required String tripId, required int count}) =>
      logEvent('matches_loaded', parameters: {'trip_id': tripId, 'count': count});

  Future<void> logMatchViewed({required String tripId, required String candidateTripId}) =>
      logEvent('match_viewed', parameters: {
        'trip_id': tripId,
        'candidate_trip_id': candidateTripId,
      });

  Future<void> logWhyMatchOpened({required String tripId, required String candidateTripId}) =>
      logEvent('why_match_opened', parameters: {
        'trip_id': tripId,
        'candidate_trip_id': candidateTripId,
      });

  Future<void> logMatchDismissed({required String tripId, required String candidateTripId}) =>
      logEvent('match_dismissed', parameters: {
        'trip_id': tripId,
        'candidate_trip_id': candidateTripId,
      });

  Future<void> logNoMatchesShown(String tripId) =>
      logEvent('no_matches_shown', parameters: {'trip_id': tripId});

  Future<void> logDiscoveryFilterUsed({required String tripId, required String filterName}) =>
      logEvent('discovery_filter_used', parameters: {
        'trip_id': tripId,
        'filter_name': filterName,
      });

  // Phase 8 Connection & Realtime Communication Helpers
  Future<void> logConnectionRequestStarted(String tripId) =>
      logEvent('connection_request_started', parameters: {'trip_id': tripId});

  Future<void> logConnectionRequestSent({
    required String connectionId,
    required String tripId,
  }) =>
      logEvent('connection_request_sent', parameters: {
        'connection_id': connectionId,
        'trip_id': tripId,
      });

  Future<void> logConnectionRequestAccepted(String requestId) =>
      logEvent('connection_request_accepted', parameters: {'request_id': requestId});

  Future<void> logConnectionRequestDeclined(String requestId) =>
      logEvent('connection_request_declined', parameters: {'request_id': requestId});

  Future<void> logConnectionRequestCancelled(String requestId) =>
      logEvent('connection_request_cancelled', parameters: {'request_id': requestId});

  Future<void> logConnectionOpened(String connectionId) =>
      logEvent('connection_opened', parameters: {'connection_id': connectionId});

  Future<void> logChatOpened(String roomId) =>
      logEvent('chat_opened', parameters: {'room_id': roomId});

  Future<void> logMessageSendStarted(String roomId) =>
      logEvent('message_send_started', parameters: {'room_id': roomId});

  Future<void> logMessageSent({required String roomId, required String messageId}) =>
      logEvent('message_sent', parameters: {
        'room_id': roomId,
        'message_id': messageId,
      });

  Future<void> logMessageFailed(String roomId) =>
      logEvent('message_failed', parameters: {'room_id': roomId});

  Future<void> logMessageRetry(String roomId) =>
      logEvent('message_retry', parameters: {'room_id': roomId});

  Future<void> logChatReportOpened(String roomId) =>
      logEvent('chat_report_opened', parameters: {'room_id': roomId});

  Future<void> logChatBlocked(String roomId) =>
      logEvent('chat_blocked', parameters: {'room_id': roomId});
}
