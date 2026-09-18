import '../models/safetrip_models.dart';

/// Repository interface for SafeTrip Real-Time Journey Safety.
/// Universal Engineering Rule #7: Strict server-side enforcement.
/// Universal Engineering Rule #11: Safety is a core product capability.
/// Universal Engineering Rule #18: Server state must be authoritative.
abstract class SafeTripRepository {
  /// Retrieves a SafeTrip associated with a [tripId], or null if none exists.
  Future<SafeTrip?> getSafeTripByTripId(String tripId);

  /// Retrieves a SafeTrip by its unique [journeyId].
  Future<SafeTrip?> getSafeTripById(String journeyId);

  /// Creates and saves a prepared SafeTrip in PREPARING or READY state.
  Future<SafeTrip> prepareSafeTrip(SafeTrip safeTrip);

  /// Server-authoritative, idempotent activation of a SafeTrip (READY -> ACTIVE).
  Future<SafeTrip> activateSafeTrip({
    required String journeyId,
    required String idempotencyKey,
    required JourneyConsent consent,
  });

  /// Pauses an active journey.
  Future<SafeTrip> pauseSafeTrip(String journeyId);

  /// Resumes a paused journey back to active.
  Future<SafeTrip> resumeSafeTrip(String journeyId);

  /// Idempotently confirms traveler arrival at destination (ACTIVE/PAUSED -> ARRIVED).
  Future<SafeTrip> confirmArrival({
    required String journeyId,
    required String idempotencyKey,
  });

  /// Completes the journey after arrival (ARRIVED -> COMPLETED).
  Future<SafeTrip> completeSafeTrip({
    required String journeyId,
    required String idempotencyKey,
  });

  /// Cancels a journey.
  Future<SafeTrip> cancelSafeTrip(String journeyId, {String? reason});

  /// Automatically marks journey expired when buffer threshold is reached.
  Future<SafeTrip> expireSafeTrip(String journeyId);

  /// Records an idempotent check-in ("I'm OK").
  Future<JourneyCheckin> recordCheckin({
    required String journeyId,
    required String userId,
    required String idempotencyKey,
    String? notes,
  });

  /// Fetches check-in history for a journey.
  Future<List<JourneyCheckin>> getCheckins(String journeyId);

  /// Starts or updates a revocable, temporary location sharing session.
  Future<LocationShareSession> startLocationSharing({
    required String journeyId,
    required String userId,
    required LocationSharingMode mode,
    required Duration duration,
    String? approxGeohash,
  });

  /// Revokes and terminates active location sharing immediately.
  Future<void> stopLocationSharing({
    required String journeyId,
    required String userId,
  });

  /// Retrieves the current active location sharing session, if any.
  Future<LocationShareSession?> getActiveLocationSession(String journeyId);

  /// Logs an auditable journey event to the journey event trail.
  Future<void> recordJourneyEvent({
    required String journeyId,
    required String userId,
    required String eventType,
    Map<String, dynamic>? payload,
  });

  /// Retrieves auditable chronological journey events.
  Future<List<Map<String, dynamic>>> getJourneyEvents(String journeyId);

  /// Realtime stream watching status updates for a specific journey.
  Stream<SafeTrip> watchSafeTrip(String journeyId);
}
