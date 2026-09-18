/// Deterministic, explainable matching engine for SafeMate companion discovery.
/// Universal Engineering Rule #6: Explainable AI / Matching, 3-state preference semantics, normalized 0–100.
/// Universal Engineering Rule #11: Deterministic state machine.
library;

import 'dart:math' as math;
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/profile/domain/models/profile_visibility.dart';
import 'package:safemate/features/profile/domain/models/travel_personality.dart';
import 'package:safemate/features/profile/domain/models/travel_preferences.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip_purpose.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';
import 'package:safemate/features/trips/domain/models/trip_transport.dart';
import 'package:safemate/features/trips/domain/models/trip_visibility.dart';
import '../models/compatibility_score.dart';
import '../models/match_candidate.dart';
import '../models/match_eligibility.dart';
import '../models/match_reason.dart';
import '../models/match_result.dart';

/// Pure, deterministic matching engine with zero UI or external network dependencies.
class MatchingEngine {
  const MatchingEngine();

  // ---------------------------------------------------------------------------
  // 1. HARD ELIGIBILITY RULES
  // ---------------------------------------------------------------------------

  /// Evaluates mandatory hard constraints before scoring.
  /// If any rule fails, the candidate is immediately disqualified.
  MatchEligibility evaluateEligibility({
    required Trip userTrip,
    required UserProfile userProfile,
    required Trip candidateTrip,
    required UserProfile candidateProfile,
    bool isBlocked = false,
  }) {
    // 1. Must be different users
    if (userProfile.id == candidateProfile.id || userTrip.userId == candidateTrip.userId) {
      return const MatchEligibility.ineligible(MatchFailureReason.selfMatch);
    }

    // 2. Block relationship check
    if (isBlocked) {
      return const MatchEligibility.ineligible(MatchFailureReason.blockedUser);
    }

    // 3. Candidate trip status must be PUBLISHED
    switch (candidateTrip.status) {
      case TripStatus.draft:
        return const MatchEligibility.ineligible(MatchFailureReason.tripDraft);
      case TripStatus.cancelled:
        return const MatchEligibility.ineligible(MatchFailureReason.tripCancelled);
      case TripStatus.completed:
        return const MatchEligibility.ineligible(MatchFailureReason.tripCompleted);
      case TripStatus.paused:
      case TripStatus.published:
        break; // Active trips proceed
    }

    // 4. Candidate trip visibility check
    if (candidateTrip.visibility == TripVisibility.private) {
      return const MatchEligibility.ineligible(MatchFailureReason.privateTrip);
    }

    // 5. Candidate profile visibility check
    if (candidateProfile.visibility == ProfileVisibility.hidden) {
      return const MatchEligibility.ineligible(MatchFailureReason.hiddenProfile);
    }

    // 6. Minimum profile completion readiness (must have basic passport established)
    if (candidateProfile.completionPercentage < 30) {
      return const MatchEligibility.ineligible(MatchFailureReason.profileIncomplete);
    }

    // 7. Route compatibility check (destinations must not be completely divergent)
    if (!areRoutesCompatible(userTrip, candidateTrip)) {
      return const MatchEligibility.ineligible(MatchFailureReason.routeIncompatible);
    }

    // 8. Date compatibility check (must have date overlap or departure within tolerance)
    if (!areDatesCompatible(userTrip, candidateTrip)) {
      return const MatchEligibility.ineligible(MatchFailureReason.datesIncompatible);
    }

    return const MatchEligibility.eligible();
  }

  // ---------------------------------------------------------------------------
  // 2. ROUTE COMPATIBILITY EVALUATION
  // ---------------------------------------------------------------------------

  /// Determines if two trips have a compatible destination or route path.
  bool areRoutesCompatible(Trip userTrip, Trip candidateTrip) {
    // Same destination string (case-insensitive)
    final userDest = _normalizeLocation(userTrip.destination);
    final candDest = _normalizeLocation(candidateTrip.destination);
    if (userDest == candDest) return true;

    // Same destination city
    if (userTrip.destinationCity != null &&
        candidateTrip.destinationCity != null &&
        userTrip.destinationCity!.toLowerCase() == candidateTrip.destinationCity!.toLowerCase()) {
      return true;
    }

    // Geohash prefix match on destination (at least 3 characters ~150km radius)
    if (userTrip.destinationGeohash != null && candidateTrip.destinationGeohash != null) {
      final uHash = userTrip.destinationGeohash!;
      final cHash = candidateTrip.destinationGeohash!;
      final minLen = math.min(uHash.length, cHash.length);
      if (minLen >= 3 && uHash.substring(0, 3) == cHash.substring(0, 3)) {
        return true;
      }
    }

    return false;
  }

  int calculateRouteScore(Trip userTrip, Trip candidateTrip) {
    int destScore = 0;
    int originScore = 50; // default baseline for different origin meeting at same destination

    final userDest = _normalizeLocation(userTrip.destination);
    final candDest = _normalizeLocation(candidateTrip.destination);

    if (userDest == candDest) {
      destScore = 100;
    } else if (userTrip.destinationCity != null &&
        candidateTrip.destinationCity != null &&
        userTrip.destinationCity!.toLowerCase() == candidateTrip.destinationCity!.toLowerCase()) {
      destScore = 95;
    } else if (userTrip.destinationGeohash != null && candidateTrip.destinationGeohash != null) {
      final prefix = _commonPrefixLength(userTrip.destinationGeohash!, candidateTrip.destinationGeohash!);
      if (prefix >= 5) {
        destScore = 90;
      } else if (prefix >= 4) {
        destScore = 80;
      } else if (prefix >= 3) {
        destScore = 70;
      } else {
        destScore = 50;
      }
    } else {
      destScore = 60;
    }

    // Compare origins
    final userOrig = _normalizeLocation(userTrip.origin);
    final candOrig = _normalizeLocation(candidateTrip.origin);
    if (userOrig == candOrig) {
      originScore = 100;
    } else if (userTrip.originCity != null &&
        candidateTrip.originCity != null &&
        userTrip.originCity!.toLowerCase() == candidateTrip.originCity!.toLowerCase()) {
      originScore = 90;
    } else if (userTrip.originGeohash != null && candidateTrip.originGeohash != null) {
      final prefix = _commonPrefixLength(userTrip.originGeohash!, candidateTrip.originGeohash!);
      if (prefix >= 4) {
        originScore = 85;
      } else if (prefix >= 3) {
        originScore = 70;
      }
    }

    // Weighted route score: 70% destination + 30% origin
    return (destScore * 0.70 + originScore * 0.30).round().clamp(0, 100);
  }

  // ---------------------------------------------------------------------------
  // 3. DATE COMPATIBILITY EVALUATION
  // ---------------------------------------------------------------------------

  /// Evaluates whether travel date windows overlap or fall within acceptable tolerance (max 4 days).
  bool areDatesCompatible(Trip userTrip, Trip candidateTrip) {
    final uStart = _dateOnly(userTrip.startDate);
    final uEnd = _dateOnly(userTrip.endDate);
    final cStart = _dateOnly(candidateTrip.startDate);
    final cEnd = _dateOnly(candidateTrip.endDate);

    // Overlap condition: start of one <= end of other
    if (!uStart.isAfter(cEnd) && !cStart.isAfter(uEnd)) {
      return true; // Active calendar overlap
    }

    // Proximity tolerance (departure dates within 4 days of each other)
    final departureDiff = uStart.difference(cStart).inDays.abs();
    return departureDiff <= 4;
  }

  int calculateDateScore(Trip userTrip, Trip candidateTrip) {
    final uStart = _dateOnly(userTrip.startDate);
    final uEnd = _dateOnly(userTrip.endDate);
    final cStart = _dateOnly(candidateTrip.startDate);
    final cEnd = _dateOnly(candidateTrip.endDate);

    final overlapStart = uStart.isAfter(cStart) ? uStart : cStart;
    final overlapEnd = uEnd.isBefore(cEnd) ? uEnd : cEnd;

    if (!overlapStart.isAfter(overlapEnd)) {
      // Overlap exists
      final overlapDays = overlapEnd.difference(overlapStart).inDays + 1;
      final minDuration = math.min(userTrip.durationDays, candidateTrip.durationDays);
      final ratio = minDuration > 0 ? (overlapDays / minDuration) : 1.0;

      if (ratio >= 0.8) return 100;
      if (ratio >= 0.5) return 85;
      return 70;
    }

    // Nearby dates without direct overlap
    final departureDiff = uStart.difference(cStart).inDays.abs();
    if (departureDiff <= 1) return 55;
    if (departureDiff <= 2) return 45;
    if (departureDiff <= 4) return 30;
    return 10;
  }

  int calculateOverlapDays(Trip userTrip, Trip candidateTrip) {
    final uStart = _dateOnly(userTrip.startDate);
    final uEnd = _dateOnly(userTrip.endDate);
    final cStart = _dateOnly(candidateTrip.startDate);
    final cEnd = _dateOnly(candidateTrip.endDate);

    final overlapStart = uStart.isAfter(cStart) ? uStart : cStart;
    final overlapEnd = uEnd.isBefore(cEnd) ? uEnd : cEnd;

    if (overlapStart.isAfter(overlapEnd)) return 0;
    return overlapEnd.difference(overlapStart).inDays + 1;
  }

  // ---------------------------------------------------------------------------
  // 4. TRANSPORT COMPATIBILITY (3-State Semantics)
  // ---------------------------------------------------------------------------

  int calculateTransportScore(Trip userTrip, Trip candidateTrip) {
    if (userTrip.transportMode == candidateTrip.transportMode) {
      return 100;
    }
    if (userTrip.transportMode == TripTransport.flexible ||
        candidateTrip.transportMode == TripTransport.flexible) {
      return 90;
    }

    // Related ground transit
    final isGroundUser = userTrip.transportMode == TripTransport.train ||
        userTrip.transportMode == TripTransport.bus ||
        userTrip.transportMode == TripTransport.car;
    final isGroundCand = candidateTrip.transportMode == TripTransport.train ||
        candidateTrip.transportMode == TripTransport.bus ||
        candidateTrip.transportMode == TripTransport.car;

    if (isGroundUser && isGroundCand) {
      return 75;
    }

    // Check user's trip companion criteria for transport (3-state)
    final userPrefs = userTrip.preferences;
    if (userPrefs != null) {
      final status = userPrefs.getTransportStatus(candidateTrip.transportMode.code);
      if (status.isSelected) return 95;
      if (status.isNotSpecified) return 70;
      if (status.isNotSelected) return 35;
    }

    return 60;
  }

  // ---------------------------------------------------------------------------
  // 5. BUDGET COMPATIBILITY
  // ---------------------------------------------------------------------------

  int calculateBudgetScore(Trip userTrip, Trip candidateTrip) {
    final uTier = userTrip.budgetTier;
    final cTier = candidateTrip.budgetTier;

    if (uTier == cTier) return 100;
    if (uTier == TripBudgetTier.flexible || cTier == TripBudgetTier.flexible) return 90;

    final distance = (uTier.index - cTier.index).abs();
    if (distance == 1) return 75; // e.g. backpacker & budget, or budget & moderate
    if (distance == 2) return 50; // e.g. backpacker & moderate
    return 35; // extreme disparity (e.g. backpacker & luxury)
  }

  // ---------------------------------------------------------------------------
  // 6. TRIP PURPOSE COMPATIBILITY
  // ---------------------------------------------------------------------------

  int calculatePurposeScore(Trip userTrip, Trip candidateTrip) {
    final uP = userTrip.tripPurpose;
    final cP = candidateTrip.tripPurpose;

    if (uP == cP) return 100;

    // Complementary combinations
    final isExploratory = (uP == TripPurpose.vacation && cP == TripPurpose.exploration) ||
        (uP == TripPurpose.exploration && cP == TripPurpose.vacation) ||
        (uP == TripPurpose.adventure && cP == TripPurpose.exploration) ||
        (uP == TripPurpose.exploration && cP == TripPurpose.adventure);
    if (isExploratory) return 85;

    final isCultureOrPilgrimage = (uP == TripPurpose.exploration && cP == TripPurpose.pilgrimage) ||
        (uP == TripPurpose.pilgrimage && cP == TripPurpose.exploration) ||
        (uP == TripPurpose.weekendTrip && cP == TripPurpose.vacation);
    if (isCultureOrPilgrimage) return 80;

    return 55;
  }

  // ---------------------------------------------------------------------------
  // 7. TRAVEL STYLE & PERSONALITY COMPATIBILITY
  // ---------------------------------------------------------------------------

  int calculateStyleScore({
    required Trip userTrip,
    required Trip candidateTrip,
    TravelPreferences? userPreferences,
    TravelPreferences? candidatePreferences,
  }) {
    int paceScore = 75;
    int planningScore = 75;
    int vibeScore = 70;

    if (userPreferences != null && candidatePreferences != null) {
      // Pace
      if (userPreferences.travelPace == candidatePreferences.travelPace) {
        paceScore = 100;
      } else if (userPreferences.travelPace == TravelPace.flexible ||
          candidatePreferences.travelPace == TravelPace.flexible) {
        paceScore = 85;
      } else {
        paceScore = 60;
      }

      // Planning style
      if (userPreferences.planningStyle == candidatePreferences.planningStyle) {
        planningScore = 100;
      } else if (userPreferences.planningStyle == PlanningStyle.flexible ||
          candidatePreferences.planningStyle == PlanningStyle.flexible) {
        planningScore = 85;
      } else {
        planningScore = 65;
      }
    }

    // Shared Trip Styles / Vibes
    final sharedStyles = userTrip.tripStyles.toSet().intersection(candidateTrip.tripStyles.toSet());
    if (sharedStyles.length >= 2) {
      vibeScore = 100;
    } else if (sharedStyles.length == 1) {
      vibeScore = 85;
    }

    return ((paceScore + planningScore + vibeScore) / 3).round().clamp(0, 100);
  }

  // ---------------------------------------------------------------------------
  // 8. SCHEDULE COMPATIBILITY
  // ---------------------------------------------------------------------------

  int calculateScheduleScore(TravelPreferences? userPreferences, TravelPreferences? candidatePreferences) {
    if (userPreferences == null || candidatePreferences == null) return 80;

    final uS = userPreferences.schedulePreference;
    final cS = candidatePreferences.schedulePreference;

    if (uS == cS) return 100;
    if (uS == ScheduleStyle.flexible || cS == ScheduleStyle.flexible) return 90;
    if (uS == ScheduleStyle.notSpecified || cS == ScheduleStyle.notSpecified) return 80;

    // Early bird vs Night owl clash
    if ((uS == ScheduleStyle.earlyBird && cS == ScheduleStyle.nightOwl) ||
        (uS == ScheduleStyle.nightOwl && cS == ScheduleStyle.earlyBird)) {
      return 45;
    }

    return 70;
  }

  // ---------------------------------------------------------------------------
  // 9. COMPANION PREFERENCE COMPATIBILITY (3-State Model)
  // ---------------------------------------------------------------------------

  int calculatePreferenceScore({
    required Trip userTrip,
    required UserProfile candidateProfile,
    TravelPreferences? candidatePreferences,
  }) {
    final tripPrefs = userTrip.preferences;
    if (tripPrefs == null) return 85; // neutral-positive if no constraints configured

    int score = 85;

    // Gender alignment criteria
    if (tripPrefs.preferredGender.isNotEmpty && tripPrefs.preferredGender != 'any') {
      score += 5;
    }

    // Activity interests overlap (3-State evaluation)
    if (tripPrefs.activityInterests.isNotEmpty && candidatePreferences != null) {
      int matched = 0;
      for (final interest in tripPrefs.activityInterests) {
        final status = candidatePreferences.getActivityStatus(interest);
        if (status.isSelected) matched++;
      }
      if (matched >= 2) {
        score += 10;
      } else if (matched == 1) {
        score += 5;
      }
    }

    return score.clamp(0, 100);
  }

  // ---------------------------------------------------------------------------
  // 10. OVERALL SCORING & EXPLANATIONS
  // ---------------------------------------------------------------------------

  CompatibilityScore calculateScore({
    required Trip userTrip,
    required UserProfile userProfile,
    TravelPreferences? userPreferences,
    required Trip candidateTrip,
    required UserProfile candidateProfile,
    TravelPreferences? candidatePreferences,
  }) {
    final routeScore = calculateRouteScore(userTrip, candidateTrip);
    final dateScore = calculateDateScore(userTrip, candidateTrip);
    final transportScore = calculateTransportScore(userTrip, candidateTrip);
    final budgetScore = calculateBudgetScore(userTrip, candidateTrip);
    final purposeScore = calculatePurposeScore(userTrip, candidateTrip);
    final styleScore = calculateStyleScore(
      userTrip: userTrip,
      candidateTrip: candidateTrip,
      userPreferences: userPreferences,
      candidatePreferences: candidatePreferences,
    );
    final scheduleScore = calculateScheduleScore(userPreferences, candidatePreferences);
    final preferenceScore = calculatePreferenceScore(
      userTrip: userTrip,
      candidateProfile: candidateProfile,
      candidatePreferences: candidatePreferences,
    );

    final components = MatchComponentScore(
      routeScore: routeScore,
      dateScore: dateScore,
      transportScore: transportScore,
      budgetScore: budgetScore,
      purposeScore: purposeScore,
      styleScore: styleScore,
      preferenceScore: preferenceScore,
      scheduleScore: scheduleScore,
    );

    return CompatibilityScore.fromComponents(components);
  }

  List<MatchReason> generateReasons({
    required Trip userTrip,
    required Trip candidateTrip,
    required CompatibilityScore score,
    TravelPreferences? userPreferences,
    TravelPreferences? candidatePreferences,
  }) {
    final reasons = <MatchReason>[];

    // Destination Match
    if (_normalizeLocation(userTrip.destination) == _normalizeLocation(candidateTrip.destination)) {
      reasons.add(MatchReason(
        type: MatchReasonType.sameDestination,
        title: 'Same Destination',
        explanation: 'Both travelers are journeying to ${candidateTrip.destination}.',
        supportingValue: candidateTrip.destination,
      ));
    } else if (score.components.routeScore >= 80) {
      reasons.add(MatchReason(
        type: MatchReasonType.routeOverlap,
        title: 'Route Overlap',
        explanation: 'Destinations and routes are geographically aligned within the same region.',
      ));
    }

    // Dates Overlap
    final overlapDays = calculateOverlapDays(userTrip, candidateTrip);
    if (overlapDays > 0) {
      reasons.add(MatchReason(
        type: MatchReasonType.dateOverlap,
        title: 'Date Overlap',
        explanation: 'Your journey dates coincide for $overlapDays days.',
        supportingValue: '$overlapDays days',
      ));
    }

    // Transport Alignment
    if (userTrip.transportMode == candidateTrip.transportMode &&
        userTrip.transportMode != TripTransport.flexible) {
      reasons.add(MatchReason(
        type: MatchReasonType.sameTransport,
        title: 'Same Transport',
        explanation: 'Both journeys plan to use ${candidateTrip.transportMode.label}.',
        supportingValue: candidateTrip.transportMode.label,
      ));
    }

    // Budget Alignment
    if (userTrip.budgetTier == candidateTrip.budgetTier &&
        userTrip.budgetTier != TripBudgetTier.flexible) {
      reasons.add(MatchReason(
        type: MatchReasonType.similarBudget,
        title: 'Similar Budget',
        explanation: 'Both travelers share a ${candidateTrip.budgetTier.label} spending preference.',
        supportingValue: candidateTrip.budgetTier.label,
      ));
    }

    // Purpose Alignment
    if (userTrip.tripPurpose == candidateTrip.tripPurpose) {
      reasons.add(MatchReason(
        type: MatchReasonType.samePurpose,
        title: 'Shared Purpose',
        explanation: 'Both journeys are planned with a focus on ${candidateTrip.tripPurpose.label}.',
        supportingValue: candidateTrip.tripPurpose.label,
      ));
    }

    // Shared Trip Styles / Activities
    final sharedStyles = userTrip.tripStyles.toSet().intersection(candidateTrip.tripStyles.toSet());
    if (sharedStyles.isNotEmpty) {
      final styleLabels = sharedStyles.map((code) => TripVibe.fromCode(code)?.label ?? code).join(', ');
      reasons.add(MatchReason(
        type: MatchReasonType.sharedInterests,
        title: 'Shared Travel Style',
        explanation: 'Common journey vibe: $styleLabels.',
        supportingValue: styleLabels,
      ));
    }

    return reasons;
  }

  List<MismatchExplanation> generateMismatches({
    required Trip userTrip,
    required Trip candidateTrip,
    TravelPreferences? userPreferences,
    TravelPreferences? candidatePreferences,
  }) {
    final mismatches = <MismatchExplanation>[];

    // Dates difference
    final overlapDays = calculateOverlapDays(userTrip, candidateTrip);
    if (overlapDays < userTrip.durationDays && overlapDays > 0) {
      mismatches.add(MismatchExplanation(
        dimension: 'Travel Dates',
        note: 'Dates overlap for $overlapDays of ${userTrip.durationDays} days.',
      ));
    }

    // Budget difference
    if (userTrip.budgetTier != candidateTrip.budgetTier &&
        userTrip.budgetTier != TripBudgetTier.flexible &&
        candidateTrip.budgetTier != TripBudgetTier.flexible) {
      mismatches.add(MismatchExplanation(
        dimension: 'Budget Tier',
        note: 'You prefer ${userTrip.budgetTier.label}, while candidate prefers ${candidateTrip.budgetTier.label}.',
      ));
    }

    // Schedule difference
    if (userPreferences != null && candidatePreferences != null) {
      final uS = userPreferences.schedulePreference;
      final cS = candidatePreferences.schedulePreference;
      if (uS != cS && uS != ScheduleStyle.flexible && cS != ScheduleStyle.flexible &&
          uS != ScheduleStyle.notSpecified && cS != ScheduleStyle.notSpecified) {
        mismatches.add(MismatchExplanation(
          dimension: 'Daily Schedule',
          note: 'Preferred schedule: ${uS.label} vs ${cS.label}.',
        ));
      }
    }

    return mismatches;
  }

  // ---------------------------------------------------------------------------
  // 11. COMPLETE EVALUATION & RANKING
  // ---------------------------------------------------------------------------

  MatchResult? evaluateCandidate({
    required Trip userTrip,
    required UserProfile userProfile,
    TravelPreferences? userPreferences,
    required MatchCandidate candidate,
    bool isBlocked = false,
  }) {
    final eligibility = evaluateEligibility(
      userTrip: userTrip,
      userProfile: userProfile,
      candidateTrip: candidate.trip,
      candidateProfile: candidate.profile,
      isBlocked: isBlocked,
    );

    if (!eligibility.isEligible) {
      return null;
    }

    final score = calculateScore(
      userTrip: userTrip,
      userProfile: userProfile,
      userPreferences: userPreferences,
      candidateTrip: candidate.trip,
      candidateProfile: candidate.profile,
      candidatePreferences: candidate.preferences,
    );

    final reasons = generateReasons(
      userTrip: userTrip,
      candidateTrip: candidate.trip,
      score: score,
      userPreferences: userPreferences,
      candidatePreferences: candidate.preferences,
    );

    final mismatches = generateMismatches(
      userTrip: userTrip,
      candidateTrip: candidate.trip,
      userPreferences: userPreferences,
      candidatePreferences: candidate.preferences,
    );

    final now = DateTime.now();
    return MatchResult(
      id: 'match_${userTrip.id}_${candidate.trip.id}',
      tripId: userTrip.id,
      candidateTripId: candidate.trip.id,
      userId: userProfile.id,
      candidateUserId: candidate.profile.id,
      candidate: candidate,
      score: score,
      reasons: reasons,
      mismatches: mismatches,
      status: score.band == MatchQualityBand.low ? 'suggested' : 'recommended',
      evaluatedAt: now,
      createdAt: now,
    );
  }

  List<MatchResult> rankCandidates({
    required Trip userTrip,
    required UserProfile userProfile,
    TravelPreferences? userPreferences,
    required List<MatchCandidate> candidates,
    Set<String> blockedUserIds = const {},
  }) {
    final results = <MatchResult>[];

    for (final candidate in candidates) {
      final isBlocked = blockedUserIds.contains(candidate.profile.id);
      final match = evaluateCandidate(
        userTrip: userTrip,
        userProfile: userProfile,
        userPreferences: userPreferences,
        candidate: candidate,
        isBlocked: isBlocked,
      );

      if (match != null) {
        results.add(match);
      }
    }

    // Deterministic ranking:
    // 1. Compatibility score descending
    // 2. Candidate trip start date ascending
    // 3. Candidate trip id ascending (tie-breaker)
    results.sort((a, b) {
      final scoreCmp = b.score.total.compareTo(a.score.total);
      if (scoreCmp != 0) return scoreCmp;
      final dateCmp = a.candidate.trip.startDate.compareTo(b.candidate.trip.startDate);
      if (dateCmp != 0) return dateCmp;
      return a.candidateTripId.compareTo(b.candidateTripId);
    });

    return results;
  }

  // ---------------------------------------------------------------------------
  // HELPER UTILITIES
  // ---------------------------------------------------------------------------

  String _normalizeLocation(String location) {
    return location.split(',').first.trim().toLowerCase();
  }

  DateTime _dateOnly(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  int _commonPrefixLength(String a, String b) {
    int length = 0;
    final minLen = math.min(a.length, b.length);
    for (int i = 0; i < minLen; i++) {
      if (a[i].toLowerCase() == b[i].toLowerCase()) {
        length++;
      } else {
        break;
      }
    }
    return length;
  }
}
