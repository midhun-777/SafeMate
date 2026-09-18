import '../../../profile/domain/models/profile_visibility.dart';

/// SafeMate Application Profile model.
/// Separates application-layer profile details from Supabase Auth identity (Rule #9 & #10).
class UserProfile {
  final String id;
  final String displayName;
  final String? bio;
  final String? avatarUrl;
  final String? homeCity;
  final List<String> languages;
  final List<String> travelStyles;
  final ProfileVisibility visibility;
  final int completionPercentage;
  final int trustScore;
  final int tripsCompleted;
  final double reliabilityRating;
  final bool isVerified;
  final bool isPhoneVerified;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.displayName,
    this.bio,
    this.avatarUrl,
    this.homeCity,
    this.languages = const [],
    this.travelStyles = const [],
    this.visibility = ProfileVisibility.publicToMatches,
    this.completionPercentage = 0,
    this.trustScore = 0,
    this.tripsCompleted = 0,
    this.reliabilityRating = 5.0,
    this.isVerified = false,
    this.isPhoneVerified = false,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Evaluates whether the user has completed the minimal profile requirements.
  bool get isProfileComplete =>
      displayName.trim().isNotEmpty && displayName.trim() != 'Traveler';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'Traveler',
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      homeCity: json['home_city'] as String?,
      languages: (json['languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      travelStyles: (json['travel_styles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      visibility: ProfileVisibility.fromCode(json['profile_visibility'] as String?),
      completionPercentage:
          (json['profile_completion_percentage'] as num?)?.toInt() ?? 0,
      trustScore: (json['trust_score'] as num?)?.toInt() ?? 0,
      tripsCompleted: (json['trips_completed'] as num?)?.toInt() ?? 0,
      reliabilityRating:
          (json['reliability_rating'] as num?)?.toDouble() ?? 5.0,
      isVerified: json['is_verified'] as bool? ?? false,
      isPhoneVerified: json['is_phone_verified'] as bool? ?? false,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'bio': bio,
      'avatar_url': avatarUrl,
      'home_city': homeCity,
      'languages': languages,
      'travel_styles': travelStyles,
      'profile_visibility': visibility.code,
      'profile_completion_percentage': completionPercentage,
      'trust_score': trustScore,
      'trips_completed': tripsCompleted,
      'reliability_rating': reliabilityRating,
      'is_verified': isVerified,
      'is_phone_verified': isPhoneVerified,
      'version': version,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? homeCity,
    List<String>? languages,
    List<String>? travelStyles,
    ProfileVisibility? visibility,
    int? completionPercentage,
    int? trustScore,
    int? tripsCompleted,
    double? reliabilityRating,
    bool? isVerified,
    bool? isPhoneVerified,
    int? version,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      homeCity: homeCity ?? this.homeCity,
      languages: languages ?? this.languages,
      travelStyles: travelStyles ?? this.travelStyles,
      visibility: visibility ?? this.visibility,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      trustScore: trustScore ?? this.trustScore,
      tripsCompleted: tripsCompleted ?? this.tripsCompleted,
      reliabilityRating: reliabilityRating ?? this.reliabilityRating,
      isVerified: isVerified ?? this.isVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      version: version ?? this.version,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
