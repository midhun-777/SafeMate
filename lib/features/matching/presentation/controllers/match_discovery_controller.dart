/// Controller managing companion discovery, candidate filtering, and pagination.
/// Universal Engineering Rule #6: Pure state management, explainable recommendations.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safemate/core/errors/app_exception.dart';
import 'package:safemate/core/services/analytics_service.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip_transport.dart';
import 'package:safemate/features/trips/domain/repositories/trip_repository.dart';
import 'package:safemate/features/trips/presentation/controllers/trip_creation_controller.dart';
import '../../data/repositories/supabase_match_repository.dart';
import '../../domain/repositories/match_repository.dart';
import 'match_discovery_state.dart';

/// Family provider keyed by the target tripId.
final matchDiscoveryControllerProvider = StateNotifierProvider.family<
    MatchDiscoveryController, MatchDiscoveryState, String>((ref, tripId) {
  final matchRepo = ref.watch(matchRepositoryProvider);
  final tripRepo = ref.watch(tripRepositoryProvider);
  final analytics = ref.watch(analyticsServiceProvider);
  final authState = ref.watch(authControllerProvider);
  final userId = authState.session?.userId ?? 'dev_user_placeholder';

  return MatchDiscoveryController(
    matchRepository: matchRepo,
    tripRepository: tripRepo,
    analytics: analytics,
    tripId: tripId,
    userId: userId,
  );
});

class MatchDiscoveryController extends StateNotifier<MatchDiscoveryState> {
  final MatchRepository matchRepository;
  final TripRepository tripRepository;
  final AnalyticsService analytics;
  final String tripId;
  final String userId;

  static const int _pageSize = 20;

  MatchDiscoveryController({
    required this.matchRepository,
    required this.tripRepository,
    required this.analytics,
    required this.tripId,
    required this.userId,
  }) : super(const MatchDiscoveryState()) {
    loadMatches();
  }

  Future<void> loadMatches({bool refresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      offset: refresh ? 0 : state.offset,
    );

    try {
      // 1. Ensure target trip is populated in state
      final trip = state.targetTrip ?? await tripRepository.getTrip(tripId);
      if (trip == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Journey not found.',
        );
        return;
      }

      // Log discovery opened telemetry
      await analytics.logEvent('match_discovery_opened', parameters: {'trip_id': tripId});

      // 2. Discover companion candidates
      final matches = await matchRepository.findMatches(
        tripId: tripId,
        userId: userId,
        limit: _pageSize,
        offset: 0,
        minScore: state.minScoreFilter,
      );

      state = state.copyWith(
        targetTrip: trip,
        matches: matches,
        isLoading: false,
        offset: matches.length,
        hasMore: matches.length >= _pageSize,
      );

      // Log results telemetry
      await analytics.logEvent('matches_loaded', parameters: {
        'trip_id': tripId,
        'count': matches.length,
      });

      if (matches.isEmpty) {
        await analytics.logEvent('no_matches_shown', parameters: {'trip_id': tripId});
      }
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to discover companions right now. Please try again.',
      );
    }
  }

  Future<void> loadMoreMatches() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final moreMatches = await matchRepository.findMatches(
        tripId: tripId,
        userId: userId,
        limit: _pageSize,
        offset: state.offset,
        minScore: state.minScoreFilter,
      );

      final combined = [...state.matches, ...moreMatches];

      state = state.copyWith(
        matches: combined,
        isLoadingMore: false,
        offset: state.offset + moreMatches.length,
        hasMore: moreMatches.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> dismissMatch(String matchId) async {
    final match = state.matches.firstWhere(
      (m) => m.id == matchId,
      orElse: () => throw const AppException('Match not found'),
    );

    // Optimistic removal from state
    final updated = state.matches.where((m) => m.id != matchId).toList();
    state = state.copyWith(matches: updated, successMessage: 'Companion suggestion dismissed.');

    await analytics.logEvent('match_dismissed', parameters: {
      'trip_id': tripId,
      'candidate_trip_id': match.candidateTripId,
    });

    try {
      await matchRepository.dismissMatch(matchId: matchId, userId: userId);
    } catch (e) {
      // Background failure silently handled; state remains dismissed
    }
  }

  void setMinScoreFilter(int score) {
    state = state.copyWith(minScoreFilter: score);
    analytics.logEvent('discovery_filter_used', parameters: {
      'trip_id': tripId,
      'filter_name': 'min_score_$score',
    });
  }

  void setTransportFilter(TripTransport? transport) {
    if (transport == null) {
      state = state.copyWith(clearTransportFilter: true);
    } else {
      state = state.copyWith(transportFilter: transport);
      analytics.logEvent('discovery_filter_used', parameters: {
        'trip_id': tripId,
        'filter_name': 'transport_${transport.code}',
      });
    }
  }

  void setBudgetFilter(TripBudgetTier? budget) {
    if (budget == null) {
      state = state.copyWith(clearBudgetFilter: true);
    } else {
      state = state.copyWith(budgetFilter: budget);
      analytics.logEvent('discovery_filter_used', parameters: {
        'trip_id': tripId,
        'filter_name': 'budget_${budget.code}',
      });
    }
  }

  void clearFilters() {
    state = state.copyWith(
      minScoreFilter: 60,
      clearTransportFilter: true,
      clearBudgetFilter: true,
    );
  }

  void clearMessage() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}
