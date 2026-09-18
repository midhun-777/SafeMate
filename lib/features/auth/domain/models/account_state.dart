/// High-level account lifecycle states for SafeMate users.
/// Universal Engineering Rule #11: Account States. Server authorization is authoritative.
enum AccountState {
  /// User created account but has not yet confirmed or finished preliminary steps
  newUser,

  /// User is authenticated, but core profile attributes (e.g. display name) are absent
  profileIncomplete,

  /// User is fully authenticated and ready for trip creation and companion matching
  profileComplete,

  /// Account temporarily suspended by moderation/admin actions
  suspended,

  /// Account permanently blocked or deactivated
  blocked;

  bool get isActive => this == profileComplete || this == profileIncomplete;
  bool get isRestricted => this == suspended || this == blocked;
}
