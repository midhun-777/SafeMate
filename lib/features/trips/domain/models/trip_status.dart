/// Deterministic lifecycle status and state machine for SafeMate trips.
/// Universal Engineering Rule #11: Deterministic state machines, no arbitrary client mutations.
library;

/// Deterministic journey lifecycle status.
enum TripStatus {
  draft('draft', 'Draft', 'Unpublished journey draft, visible only to you.'),
  published('published', 'Published', 'Active journey discoverable for companion matching.'),
  paused('paused', 'Paused', 'Temporarily paused from new companion discoveries.'),
  cancelled('cancelled', 'Cancelled', 'Journey cancelled. Historical record preserved.'),
  completed('completed', 'Completed', 'Journey completed successfully.');

  final String code;
  final String label;
  final String description;

  const TripStatus(this.code, this.label, this.description);

  /// Validates if this status can deterministically transition to [target].
  bool canTransitionTo(TripStatus target) {
    if (this == target) return false;

    switch (this) {
      case TripStatus.draft:
        return target == TripStatus.published || target == TripStatus.cancelled;
      case TripStatus.published:
        return target == TripStatus.paused ||
            target == TripStatus.cancelled ||
            target == TripStatus.completed;
      case TripStatus.paused:
        return target == TripStatus.published ||
            target == TripStatus.cancelled;
      case TripStatus.cancelled:
      case TripStatus.completed:
        return false; // Terminal states
    }
  }

  static TripStatus fromString(String value) => fromCode(value);

  static TripStatus fromCode(String? code) {
    if (code == 'active') {
      return TripStatus.published;
    }
    for (final status in TripStatus.values) {
      if (status.code == code) return status;
    }
    return TripStatus.draft;
  }
}
