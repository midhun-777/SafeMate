import 'package:safemate/features/profile/domain/models/profile_visibility.dart';

/// User privacy preferences and safety disclosure controls.
/// Universal Engineering Rule #10: Privacy and consent are first-class design constraints.
class PrivacySettings {
  final String userId;
  final ProfileVisibility profileVisibility;
  final bool showTripsPublicly;
  final bool coarseLocationOnly;
  final bool showOnlinePresence;
  final bool allowCompanionRequests;
  final DateTime updatedAt;

  const PrivacySettings({
    required this.userId,
    this.profileVisibility = ProfileVisibility.publicToMatches,
    this.showTripsPublicly = true,
    this.coarseLocationOnly = true,
    this.showOnlinePresence = true,
    this.allowCompanionRequests = true,
    required this.updatedAt,
  });

  factory PrivacySettings.defaults(String userId) {
    return PrivacySettings(
      userId: userId,
      profileVisibility: ProfileVisibility.publicToMatches,
      showTripsPublicly: true,
      coarseLocationOnly: true, // Always default to privacy-preserving coarse geohash
      showOnlinePresence: true,
      allowCompanionRequests: true,
      updatedAt: DateTime.now(),
    );
  }

  factory PrivacySettings.fromJson(Map<String, dynamic> json) {
    return PrivacySettings(
      userId: json['user_id'] as String,
      profileVisibility: ProfileVisibility.fromCode(json['profile_visibility'] as String?),
      showTripsPublicly: json['show_trips_publicly'] as bool? ?? true,
      coarseLocationOnly: json['coarse_location_only'] as bool? ?? true,
      showOnlinePresence: json['show_online_presence'] as bool? ?? true,
      allowCompanionRequests: json['allow_companion_requests'] as bool? ?? true,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'profile_visibility': profileVisibility.code,
      'show_trips_publicly': showTripsPublicly,
      'coarse_location_only': coarseLocationOnly,
      'show_online_presence': showOnlinePresence,
      'allow_companion_requests': allowCompanionRequests,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PrivacySettings copyWith({
    ProfileVisibility? profileVisibility,
    bool? showTripsPublicly,
    bool? coarseLocationOnly,
    bool? showOnlinePresence,
    bool? allowCompanionRequests,
    DateTime? updatedAt,
  }) {
    return PrivacySettings(
      userId: userId,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      showTripsPublicly: showTripsPublicly ?? this.showTripsPublicly,
      coarseLocationOnly: coarseLocationOnly ?? this.coarseLocationOnly,
      showOnlinePresence: showOnlinePresence ?? this.showOnlinePresence,
      allowCompanionRequests: allowCompanionRequests ?? this.allowCompanionRequests,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
