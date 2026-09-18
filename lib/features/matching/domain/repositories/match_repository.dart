/// Repository interface for matching engine operations and companion discovery.
/// Universal Engineering Rule #6: Strict domain boundaries, no UI logic in repositories.
library;

import '../models/match_result.dart';

abstract class MatchRepository {
  /// Discovers and returns ranked companion matches for a specific journey.
  Future<List<MatchResult>> findMatches({
    required String tripId,
    required String userId,
    int limit = 20,
    int offset = 0,
    int minScore = 60,
  });

  /// Retrieves a specific evaluated match by ID.
  Future<MatchResult?> getMatchDetails({
    required String tripId,
    required String matchId,
  });

  /// Dismisses a match so it does not appear in discovery.
  Future<void> dismissMatch({
    required String matchId,
    required String userId,
  });

  /// Triggers a fresh evaluation of candidates for a trip.
  Future<void> recalculateMatches({
    required String tripId,
    required String userId,
  });
}
