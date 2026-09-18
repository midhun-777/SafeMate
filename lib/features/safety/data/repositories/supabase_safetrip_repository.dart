import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../../../core/config/app_config.dart';
import '../../domain/models/safetrip_models.dart';
import '../../domain/repositories/safetrip_repository.dart';

/// Supabase implementation of SafeTripRepository with dual-mode offline development store.
/// Universal Engineering Rule #7: Strict server-side enforcement.
/// Universal Engineering Rule #11: Deterministic state machines & safe transitions.
/// Universal Engineering Rule #18: Server state must be authoritative.
class SupabaseSafeTripRepository implements SafeTripRepository {
  final sb.SupabaseClient? client;
  final _uuid = const Uuid();

  // In-memory dev storage for offline mode and testing
  final Map<String, SafeTrip> _devSafeTrips = {}; // journeyId -> SafeTrip
  final Map<String, String> _devTripToJourney = {}; // tripId -> journeyId
  final Map<String, List<JourneyCheckin>> _devCheckins = {}; // journeyId -> checkins
  final Map<String, LocationShareSession> _devLocationSessions = {}; // journeyId -> session
  final Map<String, List<Map<String, dynamic>>> _devEvents = {}; // journeyId -> events
  final Map<String, StreamController<SafeTrip>> _devStreamControllers = {};
  final Set<String> _devIdempotencyKeys = {}; // idempotency keys to prevent duplicates

  SupabaseSafeTripRepository({this.client});

  sb.SupabaseClient? get _activeClient =>
      client ??
      (AppConfig.hasValidSupabaseConfig ? sb.Supabase.instance.client : null);

  StreamController<SafeTrip> _getDevController(String journeyId) {
    return _devStreamControllers.putIfAbsent(
      journeyId,
      () => StreamController<SafeTrip>.broadcast(),
    );
  }

  void _notifyDevStream(SafeTrip trip) {
    final controller = _devStreamControllers[trip.id];
    if (controller != null && !controller.isClosed) {
      controller.add(trip);
    }
  }

  // ---------------------------------------------------------------------------
  // SAFE TRIP LIFECYCLE
  // ---------------------------------------------------------------------------

  @override
  Future<SafeTrip?> getSafeTripByTripId(String tripId) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      final journeyId = _devTripToJourney[tripId];
      if (journeyId == null) return null;
      return _devSafeTrips[journeyId];
    }

    try {
      final response = await activeClient
          .from('safe_trips')
          .select()
          .eq('trip_id', tripId)
          .maybeSingle();

      if (response == null) return null;
      return SafeTrip.fromJson(response);
    } catch (e) {
      debugPrint('[SupabaseSafeTripRepository] Error fetching by tripId: $e');
      final journeyId = _devTripToJourney[tripId];
      return journeyId != null ? _devSafeTrips[journeyId] : null;
    }
  }

  @override
  Future<SafeTrip?> getSafeTripById(String journeyId) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      return _devSafeTrips[journeyId];
    }

    try {
      final response = await activeClient
          .from('safe_trips')
          .select()
          .eq('id', journeyId)
          .maybeSingle();

      if (response == null) return null;
      return SafeTrip.fromJson(response);
    } catch (e) {
      debugPrint('[SupabaseSafeTripRepository] Error fetching by journeyId: $e');
      return _devSafeTrips[journeyId];
    }
  }

  @override
  Future<SafeTrip> prepareSafeTrip(SafeTrip safeTrip) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      _devSafeTrips[safeTrip.id] = safeTrip;
      _devTripToJourney[safeTrip.tripId] = safeTrip.id;
      _notifyDevStream(safeTrip);
      await recordJourneyEvent(
        journeyId: safeTrip.id,
        userId: safeTrip.ownerId,
        eventType: 'journey_prepared',
        payload: {'destination': safeTrip.tripId},
      );
      return safeTrip;
    }

    try {
      final response = await activeClient
          .from('safe_trips')
          .upsert(safeTrip.toJson())
          .select()
          .single();

      final saved = SafeTrip.fromJson(response);
      _devSafeTrips[saved.id] = saved;
      _devTripToJourney[saved.tripId] = saved.id;
      return saved;
    } catch (e) {
      debugPrint('[SupabaseSafeTripRepository] Error preparing SafeTrip: $e');
      _devSafeTrips[safeTrip.id] = safeTrip;
      _devTripToJourney[safeTrip.tripId] = safeTrip.id;
      return safeTrip;
    }
  }

  @override
  Future<SafeTrip> activateSafeTrip({
    required String journeyId,
    required String idempotencyKey,
    required JourneyConsent consent,
  }) async {
    // Check idempotency
    if (_devIdempotencyKeys.contains(idempotencyKey)) {
      final existing = await getSafeTripById(journeyId);
      if (existing != null && existing.status == SafeTripStatus.active) {
        return existing;
      }
    }
    _devIdempotencyKeys.add(idempotencyKey);

    final current = await getSafeTripById(journeyId);
    if (current == null) {
      throw StateError('SafeTrip not found: $journeyId');
    }

    final activatedTrip = SafeTripStateMachine.transition(
      current: current.copyWith(consent: consent),
      target: SafeTripStatus.active,
      timestamp: DateTime.now(),
    );

    final activeClient = _activeClient;
    if (activeClient == null) {
      _devSafeTrips[journeyId] = activatedTrip;
      _notifyDevStream(activatedTrip);

      // Schedule first check-in
      final firstCheckin = JourneyCheckin(
        id: _uuid.v4(),
        journeyId: journeyId,
        userId: current.ownerId,
        checkinNumber: 1,
        status: CheckinStatus.scheduled,
        scheduledFor: activatedTrip.nextCheckinDeadline!,
        idempotencyKey: 'sched-$idempotencyKey',
      );
      _devCheckins.putIfAbsent(journeyId, () => []).add(firstCheckin);

      await recordJourneyEvent(
        journeyId: journeyId,
        userId: current.ownerId,
        eventType: 'journey_activated',
        payload: {'idempotency_key': idempotencyKey},
      );
      return activatedTrip;
    }

    try {
      final response = await activeClient
          .from('safe_trips')
          .update(activatedTrip.toJson())
          .eq('id', journeyId)
          .select()
          .single();

      final updated = SafeTrip.fromJson(response);
      _devSafeTrips[journeyId] = updated;
      _notifyDevStream(updated);
      return updated;
    } catch (e) {
      debugPrint('[SupabaseSafeTripRepository] Error activating SafeTrip: $e');
      _devSafeTrips[journeyId] = activatedTrip;
      _notifyDevStream(activatedTrip);
      return activatedTrip;
    }
  }

  @override
  Future<SafeTrip> pauseSafeTrip(String journeyId) async {
    final current = await getSafeTripById(journeyId);
    if (current == null) throw StateError('SafeTrip not found: $journeyId');

    final updated = SafeTripStateMachine.transition(
      current: current,
      target: SafeTripStatus.paused,
    );

    _devSafeTrips[journeyId] = updated;
    _notifyDevStream(updated);

    final activeClient = _activeClient;
    if (activeClient != null) {
      try {
        await activeClient
            .from('safe_trips')
            .update(updated.toJson())
            .eq('id', journeyId);
      } catch (e) {
        debugPrint('[SupabaseSafeTripRepository] Error pausing SafeTrip: $e');
      }
    }
    return updated;
  }

  @override
  Future<SafeTrip> resumeSafeTrip(String journeyId) async {
    final current = await getSafeTripById(journeyId);
    if (current == null) throw StateError('SafeTrip not found: $journeyId');

    final updated = SafeTripStateMachine.transition(
      current: current,
      target: SafeTripStatus.active,
    );

    _devSafeTrips[journeyId] = updated;
    _notifyDevStream(updated);

    final activeClient = _activeClient;
    if (activeClient != null) {
      try {
        await activeClient
            .from('safe_trips')
            .update(updated.toJson())
            .eq('id', journeyId);
      } catch (e) {
        debugPrint('[SupabaseSafeTripRepository] Error resuming SafeTrip: $e');
      }
    }
    return updated;
  }

  @override
  Future<SafeTrip> confirmArrival({
    required String journeyId,
    required String idempotencyKey,
  }) async {
    if (_devIdempotencyKeys.contains(idempotencyKey)) {
      final existing = await getSafeTripById(journeyId);
      if (existing != null && existing.status == SafeTripStatus.arrived) {
        return existing;
      }
    }
    _devIdempotencyKeys.add(idempotencyKey);

    final current = await getSafeTripById(journeyId);
    if (current == null) throw StateError('SafeTrip not found: $journeyId');

    final arrivedTrip = SafeTripStateMachine.transition(
      current: current,
      target: SafeTripStatus.arrived,
      timestamp: DateTime.now(),
    );

    // Automatically stop location sharing on arrival
    await stopLocationSharing(journeyId: journeyId, userId: current.ownerId);

    _devSafeTrips[journeyId] = arrivedTrip;
    _notifyDevStream(arrivedTrip);

    await recordJourneyEvent(
      journeyId: journeyId,
      userId: current.ownerId,
      eventType: 'arrival_confirmed',
      payload: {'idempotency_key': idempotencyKey},
    );

    final activeClient = _activeClient;
    if (activeClient != null) {
      try {
        await activeClient
            .from('safe_trips')
            .update(arrivedTrip.toJson())
            .eq('id', journeyId);
      } catch (e) {
        debugPrint('[SupabaseSafeTripRepository] Error confirming arrival: $e');
      }
    }
    return arrivedTrip;
  }

  @override
  Future<SafeTrip> completeSafeTrip({
    required String journeyId,
    required String idempotencyKey,
  }) async {
    if (_devIdempotencyKeys.contains(idempotencyKey)) {
      final existing = await getSafeTripById(journeyId);
      if (existing != null && existing.status == SafeTripStatus.completed) {
        return existing;
      }
    }
    _devIdempotencyKeys.add(idempotencyKey);

    final current = await getSafeTripById(journeyId);
    if (current == null) throw StateError('SafeTrip not found: $journeyId');

    final completedTrip = SafeTripStateMachine.transition(
      current: current,
      target: SafeTripStatus.completed,
      timestamp: DateTime.now(),
    );

    _devSafeTrips[journeyId] = completedTrip;
    _notifyDevStream(completedTrip);

    await recordJourneyEvent(
      journeyId: journeyId,
      userId: current.ownerId,
      eventType: 'journey_completed',
      payload: {'idempotency_key': idempotencyKey},
    );

    final activeClient = _activeClient;
    if (activeClient != null) {
      try {
        await activeClient
            .from('safe_trips')
            .update(completedTrip.toJson())
            .eq('id', journeyId);
      } catch (e) {
        debugPrint('[SupabaseSafeTripRepository] Error completing SafeTrip: $e');
      }
    }
    return completedTrip;
  }

  @override
  Future<SafeTrip> cancelSafeTrip(String journeyId, {String? reason}) async {
    final current = await getSafeTripById(journeyId);
    if (current == null) throw StateError('SafeTrip not found: $journeyId');

    final cancelledTrip = SafeTripStateMachine.transition(
      current: current,
      target: SafeTripStatus.cancelled,
      timestamp: DateTime.now(),
    );

    await stopLocationSharing(journeyId: journeyId, userId: current.ownerId);

    _devSafeTrips[journeyId] = cancelledTrip;
    _notifyDevStream(cancelledTrip);

    await recordJourneyEvent(
      journeyId: journeyId,
      userId: current.ownerId,
      eventType: 'journey_cancelled',
      payload: {'reason': reason},
    );

    final activeClient = _activeClient;
    if (activeClient != null) {
      try {
        await activeClient
            .from('safe_trips')
            .update(cancelledTrip.toJson())
            .eq('id', journeyId);
      } catch (e) {
        debugPrint('[SupabaseSafeTripRepository] Error cancelling SafeTrip: $e');
      }
    }
    return cancelledTrip;
  }

  @override
  Future<SafeTrip> expireSafeTrip(String journeyId) async {
    final current = await getSafeTripById(journeyId);
    if (current == null) throw StateError('SafeTrip not found: $journeyId');

    final expiredTrip = SafeTripStateMachine.transition(
      current: current,
      target: SafeTripStatus.expired,
      timestamp: DateTime.now(),
    );

    await stopLocationSharing(journeyId: journeyId, userId: current.ownerId);

    _devSafeTrips[journeyId] = expiredTrip;
    _notifyDevStream(expiredTrip);

    await recordJourneyEvent(
      journeyId: journeyId,
      userId: current.ownerId,
      eventType: 'journey_expired',
    );

    final activeClient = _activeClient;
    if (activeClient != null) {
      try {
        await activeClient
            .from('safe_trips')
            .update(expiredTrip.toJson())
            .eq('id', journeyId);
      } catch (e) {
        debugPrint('[SupabaseSafeTripRepository] Error expiring SafeTrip: $e');
      }
    }
    return expiredTrip;
  }

  // ---------------------------------------------------------------------------
  // CHECK-IN SYSTEM
  // ---------------------------------------------------------------------------

  @override
  Future<JourneyCheckin> recordCheckin({
    required String journeyId,
    required String userId,
    required String idempotencyKey,
    String? notes,
  }) async {
    final checkins = _devCheckins.putIfAbsent(journeyId, () => []);

    // Idempotency check: if key already processed, return existing
    final existing = checkins
        .where((c) => c.idempotencyKey == idempotencyKey)
        .firstOrNull;
    if (existing != null) return existing;

    final trip = await getSafeTripById(journeyId);
    if (trip == null) throw StateError('Journey not found: $journeyId');

    final now = DateTime.now();
    final nextDeadline = SafeTripStateMachine.calculateNextDeadline(
      lastCheckinTime: now,
      intervalMinutes: trip.checkinIntervalMinutes,
    );

    // Update safe_trip state with new lastCheckinAt and nextCheckinDeadline
    final updatedTrip = trip.copyWith(
      lastCheckinAt: now,
      nextCheckinDeadline: nextDeadline,
      updatedAt: now,
    );
    _devSafeTrips[journeyId] = updatedTrip;
    _notifyDevStream(updatedTrip);

    final checkinNumber = checkins.length + 1;
    final newCheckin = JourneyCheckin(
      id: _uuid.v4(),
      journeyId: journeyId,
      userId: userId,
      checkinNumber: checkinNumber,
      status: CheckinStatus.completed,
      scheduledFor: now,
      completedAt: now,
      notes: notes,
      idempotencyKey: idempotencyKey,
    );
    checkins.add(newCheckin);

    await recordJourneyEvent(
      journeyId: journeyId,
      userId: userId,
      eventType: 'checkin_completed',
      payload: {'checkin_number': checkinNumber},
    );

    final activeClient = _activeClient;
    if (activeClient != null) {
      try {
        await activeClient
            .from('journey_checkins')
            .insert(newCheckin.toJson());
        await activeClient
            .from('safe_trips')
            .update(updatedTrip.toJson())
            .eq('id', journeyId);
      } catch (e) {
        debugPrint('[SupabaseSafeTripRepository] Error persisting check-in: $e');
      }
    }

    return newCheckin;
  }

  @override
  Future<List<JourneyCheckin>> getCheckins(String journeyId) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      return List.unmodifiable(_devCheckins[journeyId] ?? []);
    }

    try {
      final response = await activeClient
          .from('journey_checkins')
          .select()
          .eq('journey_id', journeyId)
          .order('scheduled_for', ascending: true);

      return (response as List)
          .map((item) => JourneyCheckin.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SupabaseSafeTripRepository] Error fetching checkins: $e');
      return List.unmodifiable(_devCheckins[journeyId] ?? []);
    }
  }

  // ---------------------------------------------------------------------------
  // LOCATION SHARING SESSIONS
  // ---------------------------------------------------------------------------

  @override
  Future<LocationShareSession> startLocationSharing({
    required String journeyId,
    required String userId,
    required LocationSharingMode mode,
    required Duration duration,
    String? approxGeohash,
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(duration);

    final session = LocationShareSession(
      id: _uuid.v4(),
      journeyId: journeyId,
      userId: userId,
      mode: mode,
      approxGeohash: approxGeohash,
      startedAt: now,
      expiresAt: expiresAt,
      updatedAt: now,
    );

    _devLocationSessions[journeyId] = session;

    // Update parent SafeTrip
    final trip = await getSafeTripById(journeyId);
    if (trip != null) {
      final updatedTrip = trip.copyWith(
        locationSharingMode: mode,
        locationSharingExpiresAt: expiresAt,
      );
      _devSafeTrips[journeyId] = updatedTrip;
      _notifyDevStream(updatedTrip);
    }

    await recordJourneyEvent(
      journeyId: journeyId,
      userId: userId,
      eventType: 'location_sharing_started',
      payload: {'mode': mode.code, 'expires_at': expiresAt.toIso8601String()},
    );

    final activeClient = _activeClient;
    if (activeClient != null) {
      try {
        await activeClient
            .from('location_share_sessions')
            .insert(session.toJson());
      } catch (e) {
        debugPrint('[SupabaseSafeTripRepository] Error saving location session: $e');
      }
    }
    return session;
  }

  @override
  Future<void> stopLocationSharing({
    required String journeyId,
    required String userId,
  }) async {
    final current = _devLocationSessions[journeyId];
    if (current != null && current.isActive) {
      final revoked = LocationShareSession(
        id: current.id,
        journeyId: current.journeyId,
        userId: current.userId,
        mode: LocationSharingMode.off,
        approxGeohash: null,
        startedAt: current.startedAt,
        expiresAt: current.expiresAt,
        revokedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _devLocationSessions[journeyId] = revoked;

      final trip = await getSafeTripById(journeyId);
      if (trip != null) {
        final updated = trip.copyWith(
          locationSharingMode: LocationSharingMode.off,
          locationSharingExpiresAt: DateTime.now(),
        );
        _devSafeTrips[journeyId] = updated;
        _notifyDevStream(updated);
      }

      await recordJourneyEvent(
        journeyId: journeyId,
        userId: userId,
        eventType: 'location_sharing_stopped',
      );

      final activeClient = _activeClient;
      if (activeClient != null) {
        try {
          await activeClient
              .from('location_share_sessions')
              .update(revoked.toJson())
              .eq('id', current.id);
        } catch (e) {
          debugPrint('[SupabaseSafeTripRepository] Error revoking location: $e');
        }
      }
    }
  }

  @override
  Future<LocationShareSession?> getActiveLocationSession(String journeyId) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      final session = _devLocationSessions[journeyId];
      return (session != null && session.isActive) ? session : null;
    }

    try {
      final response = await activeClient
          .from('location_share_sessions')
          .select()
          .eq('journey_id', journeyId)
          .isFilter('revoked_at', null)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('started_at', ascending: false)
          .maybeSingle();

      if (response == null) return null;
      final session = LocationShareSession.fromJson(response);
      return session.isActive ? session : null;
    } catch (e) {
      debugPrint('[SupabaseSafeTripRepository] Error getting location session: $e');
      final session = _devLocationSessions[journeyId];
      return (session != null && session.isActive) ? session : null;
    }
  }

  // ---------------------------------------------------------------------------
  // AUDITABLE JOURNEY EVENTS
  // ---------------------------------------------------------------------------

  @override
  Future<void> recordJourneyEvent({
    required String journeyId,
    required String userId,
    required String eventType,
    Map<String, dynamic>? payload,
  }) async {
    final event = {
      'id': _uuid.v4(),
      'journey_id': journeyId,
      'user_id': userId,
      'event_type': eventType,
      'payload': payload ?? {},
      'created_at': DateTime.now().toIso8601String(),
    };

    _devEvents.putIfAbsent(journeyId, () => []).add(event);

    final activeClient = _activeClient;
    if (activeClient != null) {
      try {
        await activeClient.from('journey_events').insert(event);
      } catch (e) {
        debugPrint('[SupabaseSafeTripRepository] Error logging journey event: $e');
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getJourneyEvents(String journeyId) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      final events = _devEvents[journeyId] ?? [];
      return List.unmodifiable(events);
    }

    try {
      final response = await activeClient
          .from('journey_events')
          .select()
          .eq('journey_id', journeyId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[SupabaseSafeTripRepository] Error getting journey events: $e');
      return List.unmodifiable(_devEvents[journeyId] ?? []);
    }
  }

  // ---------------------------------------------------------------------------
  // REALTIME STREAMING
  // ---------------------------------------------------------------------------

  @override
  Stream<SafeTrip> watchSafeTrip(String journeyId) {
    final activeClient = _activeClient;
    if (activeClient == null) {
      return _getDevController(journeyId).stream;
    }

    // Scoped realtime stream on 'safe_trips'
    return activeClient
        .from('safe_trips')
        .stream(primaryKey: ['id'])
        .eq('id', journeyId)
        .map((records) => SafeTrip.fromJson(records.first));
  }
}
