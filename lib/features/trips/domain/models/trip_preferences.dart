/// Trip-specific companion criteria implementing the SafeMate 3-state preference model.
/// Universal Engineering Rule #11: SELECTED, NOT_SELECTED, NOT_SPECIFIED.
/// Never assume omitted criteria indicates a negative preference.
library;

import 'package:safemate/features/profile/domain/models/travel_personality.dart';
import 'package:safemate/features/profile/domain/models/travel_preferences.dart';
import 'trip_budget.dart';

class TripPreferences {
  final String id;
  final String tripId;
  final String preferredGender; // 'any', 'female_only', 'male_only'
  final int? ageMin;
  final int? ageMax;
  final bool requireVerifiedId;
  final int flexibleDatesDays;
  final TravelPace travelPace;
  final TripBudgetTier budgetTier;
  final AccommodationStyle accommodationPreference;
  final SocialPreference socialEnergy;
  final List<String> preferredTransport;
  final List<String> activityInterests;
  final List<String> dietaryPreferences;
  final ScheduleStyle schedulePreference;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  TripPreferences({
    this.id = '',
    required this.tripId,
    this.preferredGender = 'any',
    this.ageMin,
    this.ageMax,
    this.requireVerifiedId = true,
    this.flexibleDatesDays = 0,
    this.travelPace = TravelPace.flexible,
    this.budgetTier = TripBudgetTier.flexible,
    this.accommodationPreference = AccommodationStyle.flexible,
    this.socialEnergy = SocialPreference.flexible,
    this.preferredTransport = const [],
    this.activityInterests = const [],
    this.dietaryPreferences = const [],
    this.schedulePreference = ScheduleStyle.flexible,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Factory for a fresh, empty trip preference configuration.
  factory TripPreferences.empty(String tripId) {
    final now = DateTime.now();
    return TripPreferences(
      id: '',
      tripId: tripId,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Whether any meaningful companion preference has been configured.
  bool get hasPreferences =>
      activityInterests.isNotEmpty ||
      preferredTransport.isNotEmpty ||
      dietaryPreferences.isNotEmpty ||
      travelPace != TravelPace.flexible ||
      budgetTier != TripBudgetTier.flexible ||
      accommodationPreference != AccommodationStyle.flexible ||
      socialEnergy != SocialPreference.flexible ||
      notes != null;


  /// 3-state quality method for an activity interest:
  /// - `notSpecified`: user has not configured any activity criteria
  /// - `selected`: this activity is explicitly included
  /// - `notSelected`: other activities are selected, but this one is omitted
  PreferenceStatus getActivityStatus(String interest) {
    if (activityInterests.isEmpty) return PreferenceStatus.notSpecified;
    return activityInterests.contains(interest)
        ? PreferenceStatus.selected
        : PreferenceStatus.notSelected;
  }

  /// 3-state quality method for transport mode.
  PreferenceStatus getTransportStatus(String transport) {
    if (preferredTransport.isEmpty) return PreferenceStatus.notSpecified;
    return preferredTransport.contains(transport)
        ? PreferenceStatus.selected
        : PreferenceStatus.notSelected;
  }

  /// 3-state quality method for dietary requirement.
  PreferenceStatus getDietaryStatus(String diet) {
    if (dietaryPreferences.isEmpty) return PreferenceStatus.notSpecified;
    return dietaryPreferences.contains(diet)
        ? PreferenceStatus.selected
        : PreferenceStatus.notSelected;
  }

  TripPreferences copyWith({
    String? id,
    String? tripId,
    String? preferredGender,
    int? ageMin,
    int? ageMax,
    bool? requireVerifiedId,
    int? flexibleDatesDays,
    TravelPace? travelPace,
    TripBudgetTier? budgetTier,
    AccommodationStyle? accommodationPreference,
    SocialPreference? socialEnergy,
    List<String>? preferredTransport,
    List<String>? activityInterests,
    List<String>? dietaryPreferences,
    ScheduleStyle? schedulePreference,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripPreferences(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      preferredGender: preferredGender ?? this.preferredGender,
      ageMin: ageMin ?? this.ageMin,
      ageMax: ageMax ?? this.ageMax,
      requireVerifiedId: requireVerifiedId ?? this.requireVerifiedId,
      flexibleDatesDays: flexibleDatesDays ?? this.flexibleDatesDays,
      travelPace: travelPace ?? this.travelPace,
      budgetTier: budgetTier ?? this.budgetTier,
      accommodationPreference:
          accommodationPreference ?? this.accommodationPreference,
      socialEnergy: socialEnergy ?? this.socialEnergy,
      preferredTransport: preferredTransport ?? this.preferredTransport,
      activityInterests: activityInterests ?? this.activityInterests,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      schedulePreference: schedulePreference ?? this.schedulePreference,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'trip_id': tripId,
      'preferred_gender': preferredGender,
      'age_min': ageMin,
      'age_max': ageMax,
      'require_verified_id': requireVerifiedId,
      'flexible_dates_days': flexibleDatesDays,
      'travel_pace': travelPace.code,
      'budget_tier': budgetTier.code,
      'accommodation_preference': accommodationPreference.code,
      'social_energy': socialEnergy.code,
      'preferred_transport': preferredTransport,
      'activity_interests': activityInterests,
      'dietary_preferences': dietaryPreferences,
      'schedule_preference': schedulePreference.code,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TripPreferences.fromJson(Map<String, dynamic> json) {
    return TripPreferences(
      id: json['id'] as String? ?? '',
      tripId: json['trip_id'] as String? ?? '',
      preferredGender: json['preferred_gender'] as String? ?? 'any',
      ageMin: json['age_min'] as int?,
      ageMax: json['age_max'] as int?,
      requireVerifiedId: json['require_verified_id'] as bool? ?? true,
      flexibleDatesDays: json['flexible_dates_days'] as int? ?? 0,
      travelPace: TravelPace.fromCode(json['travel_pace'] as String?),
      budgetTier: TripBudgetTier.fromCode(json['budget_tier'] as String?),
      accommodationPreference: AccommodationStyle.fromCode(
          json['accommodation_preference'] as String?),
      socialEnergy:
          SocialPreference.fromCode(json['social_energy'] as String?),
      preferredTransport:
          (json['preferred_transport'] as List<dynamic>?)?.cast<String>() ??
              const [],
      activityInterests:
          (json['activity_interests'] as List<dynamic>?)?.cast<String>() ??
              const [],
      dietaryPreferences:
          (json['dietary_preferences'] as List<dynamic>?)?.cast<String>() ??
              const [],
      schedulePreference:
          ScheduleStyle.fromCode(json['schedule_preference'] as String?),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }
}
