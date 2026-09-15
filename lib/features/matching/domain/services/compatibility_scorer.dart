import '../models/match_result.dart';
import '../../../trips/domain/models/trip.dart';

/// Deterministic Compatibility Scorer for SafeMate.
/// Universal Engineering Rule #17:
/// "SafeMate matching should consider relevant factors such as:
/// Route, Origin, Destination, Date, Date overlap, Transport, Budget, Trip purpose.
/// The compatibility score should be explainable. Do not create fake precision."
class CompatibilityScorer {
  const CompatibilityScorer._();

  /// Calculates deterministic compatibility score between two trips.
  static MatchResult calculate({
    required String matchId,
    required Trip tripA,
    required Trip tripB,
  }) {
    int totalScore = 0;
    final List<String> reasons = [];
    final Map<String, dynamic> breakdown = {};

    // 1. Destination Match (Up to 30 points)
    final bool exactDestination = tripA.destination.trim().toLowerCase() ==
        tripB.destination.trim().toLowerCase();
    if (exactDestination) {
      totalScore += 30;
      reasons.add('Same destination: ${tripA.destination}');
      breakdown['destination_points'] = 30;
    } else {
      breakdown['destination_points'] = 0;
    }

    // 2. Origin Match (Up to 15 points)
    final bool exactOrigin =
        tripA.origin.trim().toLowerCase() == tripB.origin.trim().toLowerCase();
    if (exactOrigin) {
      totalScore += 15;
      reasons.add('Same starting point: ${tripA.origin}');
      breakdown['origin_points'] = 15;
    } else {
      breakdown['origin_points'] = 0;
    }

    // 3. Date Overlap (Up to 25 points)
    final DateTime overlapStart =
        tripA.startDate.isAfter(tripB.startDate) ? tripA.startDate : tripB.startDate;
    final DateTime overlapEnd =
        tripA.endDate.isBefore(tripB.endDate) ? tripA.endDate : tripB.endDate;

    if (!overlapStart.isAfter(overlapEnd)) {
      final int overlapDays = overlapEnd.difference(overlapStart).inDays + 1;
      final int dateScore = (overlapDays >= 3) ? 25 : (overlapDays * 8);
      totalScore += dateScore;
      reasons.add('Overlapping travel dates: $overlapDays ${overlapDays == 1 ? "day" : "days"}');
      breakdown['date_overlap_points'] = dateScore;
    } else {
      breakdown['date_overlap_points'] = 0;
    }

    // 4. Transport Mode Alignment (Up to 15 points)
    final bool transportMatch = tripA.transportMode == 'flexible' ||
        tripB.transportMode == 'flexible' ||
        tripA.transportMode == tripB.transportMode;
    if (transportMatch) {
      totalScore += 15;
      if (tripA.transportMode == tripB.transportMode && tripA.transportMode != 'flexible') {
        reasons.add('Same preferred transport: ${tripA.transportMode}');
      } else {
        reasons.add('Compatible travel transport');
      }
      breakdown['transport_points'] = 15;
    } else {
      breakdown['transport_points'] = 0;
    }

    // 5. Trip Purpose Alignment (Up to 15 points)
    final bool purposeMatch = tripA.tripPurpose == tripB.tripPurpose;
    if (purposeMatch) {
      totalScore += 15;
      reasons.add('Shared trip purpose: ${tripA.tripPurpose}');
      breakdown['purpose_points'] = 15;
    } else {
      breakdown['purpose_points'] = 0;
    }

    // Bound score strictly 0..100
    final int finalScore = totalScore.clamp(0, 100);

    return MatchResult(
      id: matchId,
      userId: tripA.userId,
      candidateId: tripB.userId,
      tripId: tripA.id,
      compatibilityScore: finalScore,
      scoreBreakdown: breakdown,
      matchReasons: reasons,
      status: 'suggested',
      createdAt: DateTime.now(),
    );
  }
}
