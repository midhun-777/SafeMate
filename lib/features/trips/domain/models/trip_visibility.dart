/// Privacy visibility controls for SafeMate trips.
/// Universal Engineering Rule #7: Selective privacy controls, no accidental leakage.
library;

enum TripVisibility {
  visibleForMatching(
    'visible_for_matching',
    'Visible for Matching',
    'Verified companions matching your route can discover this journey.',
  ),
  private(
    'private',
    'Private Journey',
    'Visible only to you. Not discoverable in companion searches.',
  ),
  paused(
    'paused',
    'Paused',
    'Temporarily hidden from search until you choose to resume.',
  );

  final String code;
  final String label;
  final String description;

  const TripVisibility(this.code, this.label, this.description);

  static TripVisibility fromCode(String? code) {
    for (final vis in TripVisibility.values) {
      if (vis.code == code) return vis;
    }
    return TripVisibility.visibleForMatching;
  }
}
