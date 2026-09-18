/// Immutable state for companion matching and discovery.
/// Universal Engineering Rule #6: Clear state boundaries, no raw errors.
library;

import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip_transport.dart';
import '../../domain/models/match_result.dart';

class MatchDiscoveryState {
  final Trip? targetTrip;
  final List<MatchResult> matches;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int minScoreFilter;
  final TripTransport? transportFilter;
  final TripBudgetTier? budgetFilter;
  final String? errorMessage;
  final String? successMessage;
  final int offset;

  const MatchDiscoveryState({
    this.targetTrip,
    this.matches = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.minScoreFilter = 60,
    this.transportFilter,
    this.budgetFilter,
    this.errorMessage,
    this.successMessage,
    this.offset = 0,
  });

  /// Client-side filtered matches based on active discovery filters.
  List<MatchResult> get filteredMatches {
    return matches.where((match) {
      if (match.score.total < minScoreFilter) return false;
      if (transportFilter != null && match.candidate.trip.transportMode != transportFilter) {
        return false;
      }
      if (budgetFilter != null && match.candidate.trip.budgetTier != budgetFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  MatchDiscoveryState copyWith({
    Trip? targetTrip,
    List<MatchResult>? matches,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? minScoreFilter,
    TripTransport? transportFilter,
    bool clearTransportFilter = false,
    TripBudgetTier? budgetFilter,
    bool clearBudgetFilter = false,
    String? errorMessage,
    String? successMessage,
    int? offset,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return MatchDiscoveryState(
      targetTrip: targetTrip ?? this.targetTrip,
      matches: matches ?? this.matches,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      minScoreFilter: minScoreFilter ?? this.minScoreFilter,
      transportFilter: clearTransportFilter ? null : (transportFilter ?? this.transportFilter),
      budgetFilter: clearBudgetFilter ? null : (budgetFilter ?? this.budgetFilter),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      offset: offset ?? this.offset,
    );
  }
}
