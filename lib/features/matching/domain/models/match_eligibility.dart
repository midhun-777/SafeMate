/// Hard eligibility model for SafeMate matching.
/// Universal Engineering Rule #11: Deterministic state machines, no arbitrary client mutations.
/// Universal Engineering Rule #6: Strict validation before scoring.
library;

/// Enumeration of distinct reasons why a candidate pair cannot be matched.
enum MatchFailureReason {
  selfMatch('Cannot match with your own trip.'),
  tripNotPublished('Candidate journey is not published.'),
  tripCancelled('Candidate journey has been cancelled.'),
  tripDraft('Candidate journey is still an unpublished draft.'),
  tripCompleted('Candidate journey is already completed.'),
  privateTrip('Trip visibility is set to private.'),
  hiddenProfile('Candidate profile is hidden from discovery.'),
  blockedUser('A block relationship exists between these travelers.'),
  datesIncompatible('Travel dates have no overlap or acceptable proximity.'),
  routeIncompatible('Journey routes are geographically incompatible.'),
  profileIncomplete('Travel profile does not meet minimum readiness requirements.');

  final String description;
  const MatchFailureReason(this.description);
}

/// Represents the deterministic outcome of evaluating hard eligibility rules.
class MatchEligibility {
  final bool isEligible;
  final MatchFailureReason? failureReason;
  final String? failureMessage;

  const MatchEligibility({
    required this.isEligible,
    this.failureReason,
    this.failureMessage,
  });

  const MatchEligibility.eligible()
      : isEligible = true,
        failureReason = null,
        failureMessage = null;

  const MatchEligibility.ineligible(
    MatchFailureReason this.failureReason, [
    this.failureMessage,
  ]) : isEligible = false;

  String get effectiveMessage => failureMessage ?? failureReason?.description ?? '';

  @override
  String toString() => isEligible
      ? 'MatchEligibility(Eligible)'
      : 'MatchEligibility(Ineligible: ${failureReason?.name} - $effectiveMessage)';
}
