/// Persisted or computed companion match result with explainability breakdown.
/// Universal Engineering Rule #6: Explainable recommendations, reproducible outputs.
library;

import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'compatibility_score.dart';
import 'match_candidate.dart';
import 'match_reason.dart';

/// Represents an evaluated match between a user's journey and a candidate companion.
class MatchResult {
  final String id;
  final String tripId;
  final String candidateTripId;
  final String userId;
  final String candidateUserId;
  final MatchCandidate candidate;
  final CompatibilityScore score;
  final List<MatchReason> reasons;
  final List<MismatchExplanation> mismatches;
  final String status;
  final DateTime evaluatedAt;
  final DateTime createdAt;

  // Backward compatibility fields for legacy CompatibilityScorer
  final List<String> rawReasons;
  final Map<String, dynamic> rawBreakdown;

  const MatchResult({
    required this.id,
    required this.tripId,
    required this.candidateTripId,
    required this.userId,
    required this.candidateUserId,
    required this.candidate,
    required this.score,
    this.reasons = const [],
    this.mismatches = const [],
    this.status = 'recommended',
    required this.evaluatedAt,
    required this.createdAt,
    this.rawReasons = const [],
    this.rawBreakdown = const {},
  });

  // Backward compatible getters
  String get candidateId => candidateUserId;
  int get compatibilityScore => score.total;
  List<String> get matchReasons =>
      rawReasons.isNotEmpty ? rawReasons : reasons.map((r) => r.title).toList();
  Map<String, dynamic> get scoreBreakdown =>
      rawBreakdown.isNotEmpty ? rawBreakdown : score.components.toJson();

  bool get isDismissed => status == 'dismissed';
  bool get isViewed => status == 'viewed' || status == 'connected';

  /// Legacy factory constructor for CompatibilityScorer.
  factory MatchResult.legacy({
    required String id,
    required String userId,
    required String candidateId,
    required String tripId,
    required int compatibilityScore,
    required Map<String, dynamic> scoreBreakdown,
    required List<String> matchReasons,
    String status = 'suggested',
    required DateTime createdAt,
  }) {
    final now = DateTime.now();
    return MatchResult(
      id: id,
      tripId: tripId,
      candidateTripId: '',
      userId: userId,
      candidateUserId: candidateId,
      candidate: MatchCandidate(
        trip: Trip(
          id: '',
          userId: candidateId,
          origin: '',
          destination: '',
          startDate: now,
          endDate: now,
        ),
        profile: UserProfile(
          id: candidateId,
          displayName: 'Traveler',
          createdAt: now,
          updatedAt: now,
        ),
      ),
      score: CompatibilityScore(
        total: compatibilityScore,
        components: MatchComponentScore(
          routeScore: (scoreBreakdown['destination_points'] as num?)?.toInt() ?? 0,
          dateScore: (scoreBreakdown['date_overlap_points'] as num?)?.toInt() ?? 0,
          transportScore: (scoreBreakdown['transport_points'] as num?)?.toInt() ?? 0,
          budgetScore: 0,
          purposeScore: (scoreBreakdown['purpose_points'] as num?)?.toInt() ?? 0,
          styleScore: 0,
          preferenceScore: 0,
          scheduleScore: 0,
        ),
        band: MatchQualityBand.fromScore(compatibilityScore),
      ),
      rawReasons: matchReasons,
      rawBreakdown: scoreBreakdown,
      status: status,
      evaluatedAt: createdAt,
      createdAt: createdAt,
    );
  }

  MatchResult copyWith({
    String? id,
    String? tripId,
    String? candidateTripId,
    String? userId,
    String? candidateUserId,
    MatchCandidate? candidate,
    CompatibilityScore? score,
    List<MatchReason>? reasons,
    List<MismatchExplanation>? mismatches,
    String? status,
    DateTime? evaluatedAt,
    DateTime? createdAt,
  }) {
    return MatchResult(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      candidateTripId: candidateTripId ?? this.candidateTripId,
      userId: userId ?? this.userId,
      candidateUserId: candidateUserId ?? this.candidateUserId,
      candidate: candidate ?? this.candidate,
      score: score ?? this.score,
      reasons: reasons ?? this.reasons,
      mismatches: mismatches ?? this.mismatches,
      status: status ?? this.status,
      evaluatedAt: evaluatedAt ?? this.evaluatedAt,
      createdAt: createdAt ?? this.createdAt,
      rawReasons: rawReasons,
      rawBreakdown: rawBreakdown,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'trip_id': tripId,
        'candidate_trip_id': candidateTripId,
        'user_id': userId,
        'candidate_id': candidateUserId,
        'compatibility_score': score.total,
        'score_version': score.scoreVersion,
        'score_breakdown': score.toJson(),
        'match_reasons': reasons.map((r) => r.toJson()).toList(),
        'mismatch_notes': mismatches.map((m) => m.toJson()).toList(),
        'status': status,
        'evaluated_at': evaluatedAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}
