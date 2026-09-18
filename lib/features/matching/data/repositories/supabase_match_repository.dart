/// Supabase implementation of MatchRepository with offline dev simulation and caching.
/// Universal Engineering Rule #6: Pure domain evaluation, privacy-safe queries.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:safemate/core/config/app_config.dart';
import 'package:safemate/core/errors/app_exception.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/profile/domain/models/travel_personality.dart';
import 'package:safemate/features/profile/domain/models/travel_preferences.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip_purpose.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';
import 'package:safemate/features/trips/domain/models/trip_transport.dart';
import 'package:safemate/features/trips/domain/models/trip_visibility.dart';
import 'package:safemate/features/trips/domain/repositories/trip_repository.dart';
import 'package:safemate/features/trips/presentation/controllers/trip_creation_controller.dart'
    show tripRepositoryProvider;
import '../../domain/models/compatibility_score.dart';
import '../../domain/models/match_candidate.dart';
import '../../domain/models/match_reason.dart';
import '../../domain/models/match_result.dart';
import '../../domain/repositories/match_repository.dart';
import '../../domain/services/matching_engine.dart';

/// Provider for MatchRepository.
final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  final tripRepo = ref.watch(tripRepositoryProvider);
  return SupabaseMatchRepository(tripRepository: tripRepo);
});

class SupabaseMatchRepository implements MatchRepository {
  final sb.SupabaseClient? client;
  final TripRepository tripRepository;
  final MatchingEngine engine;

  // In-memory cache for offline development and testing
  final Map<String, List<MatchResult>> _devMatchesCache = {};
  final Set<String> _dismissedMatches = {};

  SupabaseMatchRepository({
    this.client,
    required this.tripRepository,
    this.engine = const MatchingEngine(),
  });

  sb.SupabaseClient? get _activeClient =>
      client ?? (AppConfig.hasValidSupabaseConfig ? sb.Supabase.instance.client : null);

  @override
  Future<List<MatchResult>> findMatches({
    required String tripId,
    required String userId,
    int limit = 20,
    int offset = 0,
    int minScore = 60,
  }) async {
    final activeClient = _activeClient;

    if (activeClient == null) {
      return _findDevMatches(
        tripId: tripId,
        userId: userId,
        limit: limit,
        offset: offset,
        minScore: minScore,
      );
    }

    try {
      // 1. Fetch user's trip
      final userTrip = await tripRepository.getTrip(tripId);
      if (userTrip == null) {
        throw const AppException('Journey not found.', code: 'not_found');
      }

      final now = DateTime.now();

      // 2. Fetch user's profile
      final userProfileRow = await activeClient
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      final userProfile = userProfileRow != null
          ? UserProfile.fromJson(userProfileRow)
          : UserProfile(
              id: userId,
              displayName: 'Traveler',
              createdAt: now,
              updatedAt: now,
            );

      // 3. Fetch user's travel preferences
      final userPrefsRow = await activeClient
          .from('travel_preferences')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      final userPreferences = userPrefsRow != null
          ? TravelPreferences.fromJson(userPrefsRow)
          : null;

      // 4. Fetch blocked user IDs
      final blockedRows = await activeClient
          .from('blocks')
          .select('blocker_id, blocked_id')
          .or('blocker_id.eq.$userId,blocked_id.eq.$userId');

      final blockedUserIds = <String>{};
      for (final row in (blockedRows as List)) {
        final bId = row['blocker_id'] as String;
        final blId = row['blocked_id'] as String;
        blockedUserIds.add(bId == userId ? blId : bId);
      }

      // 5. Query candidate trips server-side with broad date and status filters
      final earliestStart = userTrip.startDate.subtract(const Duration(days: 4));
      final latestEnd = userTrip.endDate.add(const Duration(days: 4));

      final candidateTripRows = await activeClient
          .from('trips')
          .select('*, trip_preferences(*), profiles(*)')
          .neq('user_id', userId)
          .eq('status', 'published')
          .eq('visibility', 'visible_for_matching')
          .gte('end_date', earliestStart.toIso8601String())
          .lte('start_date', latestEnd.toIso8601String());

      final candidates = <MatchCandidate>[];

      for (final row in (candidateTripRows as List)) {
        final tripMap = row as Map<String, dynamic>;
        final candUserId = tripMap['user_id'] as String;

        // Skip blocked users
        if (blockedUserIds.contains(candUserId)) continue;

        final candidateTrip = Trip.fromJson(tripMap);

        UserProfile candProfile;
        if (tripMap['profiles'] != null && tripMap['profiles'] is Map) {
          candProfile = UserProfile.fromJson(tripMap['profiles'] as Map<String, dynamic>);
        } else {
          candProfile = UserProfile(
            id: candUserId,
            displayName: 'Traveler',
            createdAt: now,
            updatedAt: now,
          );
        }

        // Fetch candidate preferences if present
        TravelPreferences? candPrefs;
        if (tripMap['trip_preferences'] != null) {
          if (tripMap['trip_preferences'] is List && (tripMap['trip_preferences'] as List).isNotEmpty) {
            candPrefs = TravelPreferences.fromJson(tripMap['trip_preferences'][0] as Map<String, dynamic>);
          } else if (tripMap['trip_preferences'] is Map) {
            candPrefs = TravelPreferences.fromJson(tripMap['trip_preferences'] as Map<String, dynamic>);
          }
        }

        candidates.add(MatchCandidate(
          trip: candidateTrip,
          profile: candProfile,
          preferences: candPrefs,
        ));
      }

      // 6. Run deterministic matching engine
      final rankedMatches = engine.rankCandidates(
        userTrip: userTrip,
        userProfile: userProfile,
        userPreferences: userPreferences,
        candidates: candidates,
        blockedUserIds: blockedUserIds,
      );

      // Filter by minScore and exclude dismissed matches
      final filteredMatches = rankedMatches.where((m) {
        return m.score.total >= minScore && !_dismissedMatches.contains(m.id);
      }).toList();

      // 7. Persist evaluated matches asynchronously to public.matches
      for (final match in filteredMatches) {
        try {
          await activeClient.from('matches').upsert(
            match.toJson(),
            onConflict: 'user_id,candidate_id,trip_id',
          );
        } catch (e) {
          debugPrint('[Matching DB] Failed to upsert match record: $e');
        }
      }

      // 8. Apply pagination
      if (offset >= filteredMatches.length) return [];
      return filteredMatches.skip(offset).take(limit).toList();
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Failed to find companion matches: $e');
    }
  }

  @override
  Future<MatchResult?> getMatchDetails({
    required String tripId,
    required String matchId,
  }) async {
    final cached = _devMatchesCache[tripId];
    if (cached != null) {
      for (final m in cached) {
        if (m.id == matchId) return m;
      }
    }

    final activeClient = _activeClient;
    if (activeClient == null) return null;

    try {
      final matchRow = await activeClient
          .from('matches')
          .select('*, trips!candidate_trip_id(*), profiles!candidate_id(*)')
          .eq('id', matchId)
          .maybeSingle();

      if (matchRow == null) return null;

      final candTrip = Trip.fromJson(matchRow['trips'] as Map<String, dynamic>);
      final candProfile = UserProfile.fromJson(matchRow['profiles'] as Map<String, dynamic>);

      final candidate = MatchCandidate(trip: candTrip, profile: candProfile);
      final score = CompatibilityScore.fromJson(matchRow['score_breakdown'] as Map<String, dynamic>);

      final reasons = (matchRow['match_reasons'] as List<dynamic>?)
              ?.map((r) => MatchReason.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [];

      final mismatches = (matchRow['mismatch_notes'] as List<dynamic>?)
              ?.map((m) => MismatchExplanation.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [];

      return MatchResult(
        id: matchRow['id'] as String,
        tripId: matchRow['trip_id'] as String,
        candidateTripId: matchRow['candidate_trip_id'] as String,
        userId: matchRow['user_id'] as String,
        candidateUserId: matchRow['candidate_id'] as String,
        candidate: candidate,
        score: score,
        reasons: reasons,
        mismatches: mismatches,
        status: matchRow['status'] as String? ?? 'recommended',
        evaluatedAt: DateTime.parse(matchRow['evaluated_at'] as String),
        createdAt: DateTime.parse(matchRow['created_at'] as String),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> dismissMatch({
    required String matchId,
    required String userId,
  }) async {
    _dismissedMatches.add(matchId);

    // Remove from dev cache
    for (final list in _devMatchesCache.values) {
      list.removeWhere((m) => m.id == matchId);
    }

    final activeClient = _activeClient;
    if (activeClient != null) {
      try {
        await activeClient
            .from('matches')
            .update({'status': 'dismissed'})
            .eq('id', matchId)
            .eq('user_id', userId);
      } catch (e) {
        debugPrint('[Matching DB] Failed to update match status: $e');
      }
    }
  }

  @override
  Future<void> recalculateMatches({
    required String tripId,
    required String userId,
  }) async {
    _devMatchesCache.remove(tripId);
  }

  // ---------------------------------------------------------------------------
  // OFFLINE DEV SIMULATION
  // ---------------------------------------------------------------------------

  Future<List<MatchResult>> _findDevMatches({
    required String tripId,
    required String userId,
    required int limit,
    required int offset,
    required int minScore,
  }) async {
    debugPrint('[Dev Limitation] Matching engine running with simulated candidate dataset.');

    final userTrip = await tripRepository.getTrip(tripId);
    if (userTrip == null) {
      throw const AppException('Journey not found.', code: 'not_found');
    }

    if (_devMatchesCache.containsKey(tripId)) {
      final cached = _devMatchesCache[tripId]!;
      final filtered = cached
          .where((m) => m.score.total >= minScore && !_dismissedMatches.contains(m.id))
          .toList();
      if (offset >= filtered.length) return [];
      return filtered.skip(offset).take(limit).toList();
    }

    final now = DateTime.now();
    final userProfile = UserProfile(
      id: userId,
      displayName: 'You',
      completionPercentage: 90,
      trustScore: 85,
      createdAt: now,
      updatedAt: now,
    );

    // Generate realistic companion candidates tailored to the destination
    final candidates = _generateDevCandidates(userTrip);

    final ranked = engine.rankCandidates(
      userTrip: userTrip,
      userProfile: userProfile,
      candidates: candidates,
    );

    _devMatchesCache[tripId] = ranked;

    final filtered = ranked
        .where((m) => m.score.total >= minScore && !_dismissedMatches.contains(m.id))
        .toList();

    if (offset >= filtered.length) return [];
    return filtered.skip(offset).take(limit).toList();
  }

  List<MatchCandidate> _generateDevCandidates(Trip targetTrip) {
    final sDate = targetTrip.startDate;
    final eDate = targetTrip.endDate;
    final devTimestamp = DateTime(2026, 1, 1);

    return [
      // 1. Excellent match: Same destination, exact dates, same transport
      MatchCandidate(
        trip: Trip(
          id: 'dev_trip_cand_1',
          userId: 'dev_user_maya',
          title: 'Journey to ${targetTrip.destination}',
          origin: targetTrip.origin,
          destination: targetTrip.destination,
          startDate: sDate,
          endDate: eDate,
          transportMode: targetTrip.transportMode,
          tripPurpose: targetTrip.tripPurpose,
          budgetTier: targetTrip.budgetTier,
          tripStyles: targetTrip.tripStyles,
          status: TripStatus.published,
          visibility: TripVisibility.visibleForMatching,
        ),
        profile: UserProfile(
          id: 'dev_user_maya',
          displayName: 'Maya Chen',
          homeCity: 'Singapore',
          trustScore: 92,
          completionPercentage: 95,
          createdAt: devTimestamp,
          updatedAt: devTimestamp,
        ),
        preferences: TravelPreferences(
          id: 'dev_pref_maya',
          userId: 'dev_user_maya',
          travelPace: TravelPace.moderate,
          planningStyle: PlanningStyle.flexible,
          schedulePreference: ScheduleStyle.flexible,
          createdAt: devTimestamp,
          updatedAt: devTimestamp,
        ),
      ),

      // 2. Strong match: Same destination, 80% date overlap, similar budget
      MatchCandidate(
        trip: Trip(
          id: 'dev_trip_cand_2',
          userId: 'dev_user_alex',
          title: 'Exploring ${targetTrip.destination}',
          origin: targetTrip.origin,
          destination: targetTrip.destination,
          startDate: sDate.add(const Duration(days: 1)),
          endDate: eDate,
          transportMode: TripTransport.flexible,
          tripPurpose: TripPurpose.exploration,
          budgetTier: targetTrip.budgetTier,
          status: TripStatus.published,
          visibility: TripVisibility.visibleForMatching,
        ),
        profile: UserProfile(
          id: 'dev_user_alex',
          displayName: 'Alex Rivera',
          homeCity: 'Barcelona',
          trustScore: 88,
          completionPercentage: 85,
          createdAt: devTimestamp,
          updatedAt: devTimestamp,
        ),
        preferences: TravelPreferences(
          id: 'dev_pref_alex',
          userId: 'dev_user_alex',
          travelPace: TravelPace.moderate,
          planningStyle: PlanningStyle.spontaneous,
          schedulePreference: ScheduleStyle.flexible,
          createdAt: devTimestamp,
          updatedAt: devTimestamp,
        ),
      ),

      // 3. Good match: Same destination, departure adjacent by 1 day
      MatchCandidate(
        trip: Trip(
          id: 'dev_trip_cand_3',
          userId: 'dev_user_rohit',
          title: '${targetTrip.destination} Getaway',
          origin: targetTrip.origin,
          destination: targetTrip.destination,
          startDate: sDate.subtract(const Duration(days: 1)),
          endDate: eDate.subtract(const Duration(days: 1)),
          transportMode: TripTransport.flexible,
          tripPurpose: TripPurpose.vacation,
          budgetTier: TripBudgetTier.moderate,
          status: TripStatus.published,
          visibility: TripVisibility.visibleForMatching,
        ),
        profile: UserProfile(
          id: 'dev_user_rohit',
          displayName: 'Rohit Verma',
          homeCity: 'Mumbai',
          trustScore: 80,
          completionPercentage: 80,
          createdAt: devTimestamp,
          updatedAt: devTimestamp,
        ),
        preferences: TravelPreferences(
          id: 'dev_pref_rohit',
          userId: 'dev_user_rohit',
          travelPace: TravelPace.flexible,
          planningStyle: PlanningStyle.flexible,
          schedulePreference: ScheduleStyle.earlyBird,
          createdAt: devTimestamp,
          updatedAt: devTimestamp,
        ),
      ),
    ];
  }
}
