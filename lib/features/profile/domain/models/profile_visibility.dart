/// Privacy visibility options for SafeMate traveler profiles.
/// Universal Engineering Rule #7 & Phase 5 privacy foundation.
enum ProfileVisibility {
  /// Profile is discoverable by potential route and trip matches
  publicToMatches('public_to_matches', 'Public to Matches',
      'Visible to verified travelers with overlapping routes and dates.'),

  /// Profile is only visible after a companion connection request is accepted
  private('private', 'Private Connections Only',
      'Visible only to travelers you have approved as companions.'),

  /// Profile is hidden from all companion matching and search
  hidden('hidden', 'Hidden',
      'Completely hidden from discovery. Active trips are paused.');

  final String code;
  final String label;
  final String description;

  const ProfileVisibility(this.code, this.label, this.description);

  static ProfileVisibility fromCode(String? code) {
    switch (code) {
      case 'private':
        return ProfileVisibility.private;
      case 'hidden':
        return ProfileVisibility.hidden;
      case 'public_to_matches':
      default:
        return ProfileVisibility.publicToMatches;
    }
  }
}
