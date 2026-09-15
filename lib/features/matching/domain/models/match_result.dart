/// SafeMate Match Result model.
/// Provides deterministic score and explainable reasons (Universal Engineering Rule #17).
class MatchResult {
  final String id;
  final String userId;
  final String candidateId;
  final String tripId;
  final int compatibilityScore; // 0 to 100
  final Map<String, dynamic> scoreBreakdown;
  final List<String> matchReasons;
  final String status; // suggested, liked, passed, connected, expired
  final DateTime createdAt;

  const MatchResult({
    required this.id,
    required this.userId,
    required this.candidateId,
    required this.tripId,
    required this.compatibilityScore,
    required this.scoreBreakdown,
    required this.matchReasons,
    this.status = 'suggested',
    required this.createdAt,
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    final breakdown = json['score_breakdown'] as Map<String, dynamic>? ?? {};
    final reasons = (breakdown['reasons'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return MatchResult(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      candidateId: json['candidate_id'] as String,
      tripId: json['trip_id'] as String,
      compatibilityScore: (json['compatibility_score'] as num).toInt(),
      scoreBreakdown: breakdown,
      matchReasons: reasons,
      status: json['status'] as String? ?? 'suggested',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'candidate_id': candidateId,
      'trip_id': tripId,
      'compatibility_score': compatibilityScore,
      'score_breakdown': {
        ...scoreBreakdown,
        'reasons': matchReasons,
      },
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
