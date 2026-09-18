/// SafeMate Trust Profile, Companion Review, and Explainable Trust Score.
/// Universal Engineering Rule #11: Safety is a core product capability.
/// Universal Engineering Rule #10: Privacy and consent are first-class design constraints.
library;

class CompanionReview {
  final String id;
  final String tripId;
  final String reviewerId;
  final String revieweeId;
  final int communicationRating; // 1-5
  final int punctualityRating;   // 1-5
  final int respectRating;       // 1-5
  final int planningRating;      // 1-5
  final double overallRating;    // computed average
  final String? comment;
  final DateTime createdAt;

  const CompanionReview({
    required this.id,
    required this.tripId,
    required this.reviewerId,
    required this.revieweeId,
    required this.communicationRating,
    required this.punctualityRating,
    required this.respectRating,
    required this.planningRating,
    required this.overallRating,
    this.comment,
    required this.createdAt,
  });

  factory CompanionReview.fromJson(Map<String, dynamic> json) {
    final comm = (json['communication_rating'] as num?)?.toInt() ?? 5;
    final punc = (json['punctuality_rating'] as num?)?.toInt() ?? 5;
    final resp = (json['respect_rating'] as num?)?.toInt() ?? 5;
    final plan = (json['planning_rating'] as num?)?.toInt() ?? 5;
    final overall = (json['rating'] as num?)?.toDouble() ??
        ((comm + punc + resp + plan) / 4.0);

    return CompanionReview(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      reviewerId: json['reviewer_id'] as String,
      revieweeId: json['reviewee_id'] as String,
      communicationRating: comm,
      punctualityRating: punc,
      respectRating: resp,
      planningRating: plan,
      overallRating: overall,
      comment: json['comment'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'reviewer_id': reviewerId,
      'reviewee_id': revieweeId,
      'communication_rating': communicationRating,
      'punctuality_rating': punctualityRating,
      'respect_rating': respectRating,
      'planning_rating': planningRating,
      'rating': overallRating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class TrustScoreBreakdown {
  final int profileCompletenessPoints; // Max 20
  final int phoneVerifiedPoints;       // Max 15
  final int identityVerifiedPoints;    // Max 30
  final int tripsCompletedPoints;      // Max 15
  final int companionReviewsPoints;    // Max 20
  final int penaltyDeductions;         // 0 or negative

  const TrustScoreBreakdown({
    required this.profileCompletenessPoints,
    required this.phoneVerifiedPoints,
    required this.identityVerifiedPoints,
    required this.tripsCompletedPoints,
    required this.companionReviewsPoints,
    this.penaltyDeductions = 0,
  });

  int get totalScore {
    final raw = profileCompletenessPoints +
        phoneVerifiedPoints +
        identityVerifiedPoints +
        tripsCompletedPoints +
        companionReviewsPoints -
        penaltyDeductions;
    return raw.clamp(0, 100);
  }

  Map<String, dynamic> toExplanation() {
    return {
      'Profile Completeness': '$profileCompletenessPoints / 20 pts',
      'Phone Verified': '$phoneVerifiedPoints / 15 pts',
      'Government ID / Liveness': '$identityVerifiedPoints / 30 pts',
      'Trips Completed': '$tripsCompletedPoints / 15 pts',
      'Companion Reviews': '$companionReviewsPoints / 20 pts',
      'Deductions': penaltyDeductions > 0 ? '-$penaltyDeductions pts' : '0 pts',
      'Total Trust Score': '$totalScore / 100',
    };
  }
}

class TrustProfile {
  final String userId;
  final int trustScore;
  final bool isPhoneVerified;
  final bool isIdentityVerified;
  final int tripsCompleted;
  final double reliabilityRating;
  final int reviewCount;
  final TrustScoreBreakdown breakdown;
  final List<String> badges;
  final List<CompanionReview> recentReviews;

  const TrustProfile({
    required this.userId,
    required this.trustScore,
    required this.isPhoneVerified,
    required this.isIdentityVerified,
    required this.tripsCompleted,
    required this.reliabilityRating,
    required this.reviewCount,
    required this.breakdown,
    this.badges = const [],
    this.recentReviews = const [],
  });
}

class TrustScoreCalculator {
  static TrustScoreBreakdown calculateBreakdown({
    required int profileCompletionPercentage,
    required bool isPhoneVerified,
    required bool isIdentityVerified,
    required int tripsCompleted,
    required double averageRating,
    required int reviewCount,
    int penaltyDeductions = 0,
  }) {
    // 1. Profile completeness (0-20 pts)
    final profilePts = ((profileCompletionPercentage / 100.0) * 20).round().clamp(0, 20);

    // 2. Phone verified (0 or 15 pts)
    final phonePts = isPhoneVerified ? 15 : 0;

    // 3. Identity verified (0 or 30 pts)
    final idPts = isIdentityVerified ? 30 : 0;

    // 4. Trips completed (3 pts per trip up to 5 trips = 15 pts max)
    final tripsPts = (tripsCompleted * 3).clamp(0, 15);

    // 5. Companion reviews (20 pts max)
    int reviewPts;
    if (reviewCount == 0) {
      // Neutral baseline if no reviews yet
      reviewPts = 10;
    } else {
      // Scaled by average rating (1.0 to 5.0)
      reviewPts = ((averageRating / 5.0) * 20).round().clamp(0, 20);
    }

    return TrustScoreBreakdown(
      profileCompletenessPoints: profilePts,
      phoneVerifiedPoints: phonePts,
      identityVerifiedPoints: idPts,
      tripsCompletedPoints: tripsPts,
      companionReviewsPoints: reviewPts,
      penaltyDeductions: penaltyDeductions,
    );
  }
}
