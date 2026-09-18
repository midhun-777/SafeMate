import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/safety/domain/models/trust_models.dart';

void main() {
  group('TrustScoreCalculator and Explainable Formula', () {
    test('Calculates perfect 100 score for fully verified and experienced traveler', () {
      final breakdown = TrustScoreCalculator.calculateBreakdown(
        profileCompletionPercentage: 100, // 20 pts
        isPhoneVerified: true,             // 15 pts
        isIdentityVerified: true,          // 30 pts
        tripsCompleted: 5,                 // 15 pts (3 pts * 5)
        averageRating: 5.0,                // 20 pts
        reviewCount: 5,
      );

      expect(breakdown.profileCompletenessPoints, 20);
      expect(breakdown.phoneVerifiedPoints, 15);
      expect(breakdown.identityVerifiedPoints, 30);
      expect(breakdown.tripsCompletedPoints, 15);
      expect(breakdown.companionReviewsPoints, 20);
      expect(breakdown.penaltyDeductions, 0);
      expect(breakdown.totalScore, 100);

      final explanation = breakdown.toExplanation();
      expect(explanation['Total Trust Score'], '100 / 100');
    });

    test('Calculates score for new unverified user correctly with neutral baseline', () {
      final breakdown = TrustScoreCalculator.calculateBreakdown(
        profileCompletionPercentage: 50, // 10 pts
        isPhoneVerified: false,           // 0 pts
        isIdentityVerified: false,        // 0 pts
        tripsCompleted: 0,                // 0 pts
        averageRating: 5.0,
        reviewCount: 0,                  // neutral 10 pts baseline
      );

      expect(breakdown.profileCompletenessPoints, 10);
      expect(breakdown.phoneVerifiedPoints, 0);
      expect(breakdown.identityVerifiedPoints, 0);
      expect(breakdown.tripsCompletedPoints, 0);
      expect(breakdown.companionReviewsPoints, 10);
      expect(breakdown.totalScore, 20);
    });

    test('Applies penalty deductions without going below zero', () {
      final breakdown = TrustScoreCalculator.calculateBreakdown(
        profileCompletionPercentage: 20,
        isPhoneVerified: false,
        isIdentityVerified: false,
        tripsCompleted: 0,
        averageRating: 1.0,
        reviewCount: 1,
        penaltyDeductions: 50,
      );

      expect(breakdown.totalScore, 0);
    });

    test('CompanionReview serialization and deserialization', () {
      final now = DateTime.now();
      final review = CompanionReview(
        id: 'rev-1',
        tripId: 'trip-10',
        reviewerId: 'user-a',
        revieweeId: 'user-b',
        communicationRating: 4,
        punctualityRating: 5,
        respectRating: 5,
        planningRating: 4,
        overallRating: 4.5,
        comment: 'Great companion to travel with!',
        createdAt: now,
      );

      final json = review.toJson();
      expect(json['id'], 'rev-1');
      expect(json['communication_rating'], 4);
      expect(json['punctuality_rating'], 5);
      expect(json['rating'], 4.5);

      final reconstructed = CompanionReview.fromJson(json);
      expect(reconstructed.id, review.id);
      expect(reconstructed.overallRating, 4.5);
      expect(reconstructed.comment, 'Great companion to travel with!');
    });
  });
}
