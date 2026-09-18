/// Trip repository contract for SafeMate journeys.
/// Universal Engineering Rule #7: Client only accesses permitted rows.
/// Universal Engineering Rule #11: Strict server-side ownership and deterministic state transitions.
library;

import '../models/trip.dart';
import '../models/trip_preferences.dart';
import '../models/trip_status.dart';

abstract class TripRepository {
  /// Creates and saves a new trip record along with optional companion criteria.
  Future<Trip> createTrip(Trip trip, {TripPreferences? preferences});

  /// Saves or updates an in-progress trip draft.
  Future<Trip> saveDraft(Trip trip, {TripPreferences? preferences});

  /// Updates an existing trip's details.
  Future<Trip> updateTrip(Trip trip, {TripPreferences? preferences});

  /// Fetches a single trip by ID including its companion criteria.
  Future<Trip?> getTrip(String tripId);

  /// Retrieves all trips owned by [userId], sorted by creation date descending.
  Future<List<Trip>> getUserTrips(String userId);

  /// Deterministically transitions a trip to [newStatus] with ownership enforcement.
  Future<Trip> transitionTripStatus({
    required String tripId,
    required String userId,
    required TripStatus newStatus,
    String? reason,
  });

  /// Permanently deletes an unpublished draft trip.
  /// Strictly rejected for published, paused, cancelled, or completed journeys.
  Future<void> deleteDraftTrip({
    required String tripId,
    required String userId,
  });
}
