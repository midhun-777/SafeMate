/// Production implementation of TripRepository backed by Supabase PostgreSQL.
/// Universal Engineering Rule #7: Client only accesses permitted rows via RLS.
/// Universal Engineering Rule #11: Strict server-side ownership and deterministic state transitions.
/// Universal Engineering Rule #24: Explicit development limitation notifications when offline.
library;

import 'package:flutter/foundation.dart';
import 'package:safemate/core/config/app_config.dart';
import 'package:safemate/core/errors/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../domain/models/trip.dart';
import '../../domain/models/trip_preferences.dart';
import '../../domain/models/trip_status.dart';
import '../../domain/repositories/trip_repository.dart';

class SupabaseTripRepository implements TripRepository {
  final sb.SupabaseClient? client;

  // In-memory cache for local development/testing without hosted Supabase
  final Map<String, Trip> _devTrips = {};
  final Map<String, TripPreferences> _devPreferences = {};

  SupabaseTripRepository({this.client});

  sb.SupabaseClient? get _activeClient =>
      client ?? (AppConfig.hasValidSupabaseConfig ? sb.Supabase.instance.client : null);

  @override
  Future<Trip> createTrip(Trip trip, {TripPreferences? preferences}) async {
    final validationErrors = trip.validate(isPublishing: trip.status == TripStatus.published);
    if (validationErrors.isNotEmpty) {
      throw ValidationException(validationErrors.first);
    }

    final client = _activeClient;
    if (client == null) {
      debugPrint('[Dev Limitation] Running in development mode without live Supabase trips.');
      final tripId = trip.id.isEmpty ? 'trip_${DateTime.now().millisecondsSinceEpoch}' : trip.id;
      final savedTrip = trip.copyWith(
        id: tripId,
        preferences: preferences?.copyWith(tripId: tripId),
        updatedAt: DateTime.now(),
      );
      _devTrips[tripId] = savedTrip;
      if (preferences != null) {
        _devPreferences[tripId] = preferences.copyWith(tripId: tripId);
      }
      return savedTrip;
    }

    try {
      final tripJson = trip.toJson();
      if (trip.id.isEmpty) {
        tripJson.remove('id');
      }

      final response = await client
          .from('trips')
          .insert(tripJson)
          .select()
          .single();

      final createdTrip = Trip.fromJson(response);

      TripPreferences? savedPref;
      if (preferences != null) {
        final prefJson = preferences.copyWith(tripId: createdTrip.id).toJson();
        prefJson.remove('id');
        final prefResponse = await client
            .from('trip_preferences')
            .upsert(prefJson)
            .select()
            .single();
        savedPref = TripPreferences.fromJson(prefResponse);
      }

      return createdTrip.copyWith(preferences: savedPref);
    } on sb.PostgrestException catch (e) {
      throw DatabaseException(e.message, code: e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Failed to create trip: $e');
    }
  }

  @override
  Future<Trip> saveDraft(Trip trip, {TripPreferences? preferences}) async {
    final draftTrip = trip.copyWith(status: TripStatus.draft);
    if (draftTrip.id.isEmpty) {
      return createTrip(draftTrip, preferences: preferences);
    } else {
      return updateTrip(draftTrip, preferences: preferences);
    }
  }

  @override
  Future<Trip> updateTrip(Trip trip, {TripPreferences? preferences}) async {
    final validationErrors = trip.validate(isPublishing: trip.status == TripStatus.published);
    if (validationErrors.isNotEmpty) {
      throw ValidationException(validationErrors.first);
    }

    final client = _activeClient;
    if (client == null) {
      debugPrint('[Dev Limitation] Updating trip in dev cache.');
      final updated = trip.copyWith(
        preferences: preferences ?? trip.preferences,
        updatedAt: DateTime.now(),
      );
      _devTrips[trip.id] = updated;
      if (preferences != null) {
        _devPreferences[trip.id] = preferences;
      }
      return updated;
    }

    try {
      final tripJson = trip.toJson();
      final response = await client
          .from('trips')
          .update(tripJson)
          .eq('id', trip.id)
          .eq('user_id', trip.userId) // Strict ownership guard
          .select()
          .single();

      final updatedTrip = Trip.fromJson(response);

      TripPreferences? savedPref;
      if (preferences != null) {
        final prefJson = preferences.copyWith(tripId: updatedTrip.id).toJson();
        final prefResponse = await client
            .from('trip_preferences')
            .upsert(prefJson)
            .select()
            .single();
        savedPref = TripPreferences.fromJson(prefResponse);
      }

      return updatedTrip.copyWith(preferences: savedPref);
    } on sb.PostgrestException catch (e) {
      throw DatabaseException(e.message, code: e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Failed to update trip: $e');
    }
  }

  @override
  Future<Trip?> getTrip(String tripId) async {
    final client = _activeClient;
    if (client == null) {
      final trip = _devTrips[tripId];
      if (trip == null) return null;
      final pref = _devPreferences[tripId];
      return trip.copyWith(preferences: pref);
    }

    try {
      final response = await client
          .from('trips')
          .select('*, trip_preferences(*)')
          .eq('id', tripId)
          .maybeSingle();

      if (response == null) return null;

      TripPreferences? pref;
      if (response['trip_preferences'] != null) {
        if (response['trip_preferences'] is List && (response['trip_preferences'] as List).isNotEmpty) {
          pref = TripPreferences.fromJson(response['trip_preferences'][0] as Map<String, dynamic>);
        } else if (response['trip_preferences'] is Map) {
          pref = TripPreferences.fromJson(response['trip_preferences'] as Map<String, dynamic>);
        }
      }

      return Trip.fromJson(response, preferences: pref);
    } on sb.PostgrestException catch (e) {
      throw DatabaseException(e.message, code: e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Failed to fetch trip: $e');
    }
  }

  @override
  Future<List<Trip>> getUserTrips(String userId) async {
    final client = _activeClient;
    if (client == null) {
      return _devTrips.values
          .where((t) => t.userId == userId)
          .map((t) => t.copyWith(preferences: _devPreferences[t.id]))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    try {
      final response = await client
          .from('trips')
          .select('*, trip_preferences(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((row) {
        final map = row as Map<String, dynamic>;
        TripPreferences? pref;
        if (map['trip_preferences'] != null) {
          if (map['trip_preferences'] is List && (map['trip_preferences'] as List).isNotEmpty) {
            pref = TripPreferences.fromJson(map['trip_preferences'][0] as Map<String, dynamic>);
          } else if (map['trip_preferences'] is Map) {
            pref = TripPreferences.fromJson(map['trip_preferences'] as Map<String, dynamic>);
          }
        }
        return Trip.fromJson(map, preferences: pref);
      }).toList();
    } on sb.PostgrestException catch (e) {
      throw DatabaseException(e.message, code: e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Failed to fetch trips: $e');
    }
  }

  @override
  Future<Trip> transitionTripStatus({
    required String tripId,
    required String userId,
    required TripStatus newStatus,
    String? reason,
  }) async {
    final existing = await getTrip(tripId);
    if (existing == null) {
      throw ValidationException('Trip not found: $tripId');
    }

    if (existing.userId != userId) {
      throw AuthException('Unauthorized: You can only modify your own trips.');
    }

    if (!existing.status.canTransitionTo(newStatus)) {
      throw ValidationException(
        'Invalid status transition from ${existing.status.label} to ${newStatus.label}.',
      );
    }

    final updatedNotes = reason != null
        ? (existing.notes != null ? '${existing.notes}\n$reason' : reason)
        : existing.notes;

    final updated = existing.copyWith(
      status: newStatus,
      notes: updatedNotes,
      updatedAt: DateTime.now(),
    );

    return updateTrip(updated, preferences: existing.preferences);
  }

  @override
  Future<void> deleteDraftTrip({
    required String tripId,
    required String userId,
  }) async {
    final existing = await getTrip(tripId);
    if (existing == null) return;

    if (existing.userId != userId) {
      throw AuthException('Unauthorized: You can only delete your own trip drafts.');
    }

    if (existing.status != TripStatus.draft) {
      throw ValidationException(
        'Only unpublished draft trips can be deleted. Published, cancelled, or completed journeys are preserved as historical records.',
      );
    }

    final client = _activeClient;
    if (client == null) {
      _devTrips.remove(tripId);
      _devPreferences.remove(tripId);
      return;
    }

    try {
      await client
          .from('trips')
          .delete()
          .eq('id', tripId)
          .eq('user_id', userId)
          .eq('status', 'draft');
    } on sb.PostgrestException catch (e) {
      throw DatabaseException(e.message, code: e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Failed to delete draft trip: $e');
    }
  }
}
