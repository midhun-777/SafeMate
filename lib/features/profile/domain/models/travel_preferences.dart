import 'travel_personality.dart';

/// Represents 3-state data quality for matching criteria.
/// Universal Engineering Rule #6: Differentiate between SELECTED, NOT_SELECTED, and NOT_SPECIFIED.
enum PreferenceStatus {
  selected,
  notSelected,
  notSpecified;

  bool get isSelected => this == PreferenceStatus.selected;
  bool get isNotSelected => this == PreferenceStatus.notSelected;
  bool get isNotSpecified => this == PreferenceStatus.notSpecified;
}

/// Budget tiers for travel companion matching.
enum BudgetTier {
  budget('backpacker', 'Budget / Backpacker', 'Hostels, local transport, street eats, saving funds.'),
  moderate('moderate', 'Moderate', 'Boutique stays, mix of cafes & transit, balanced spending.'),
  comfortable('luxury', 'Comfortable', 'Hotels, private cabs, premium experiences.'),
  flexible('flexible', 'Flexible Budget', 'Adapts budget depending on the trip and companion.'),
  notSpecified('not_specified', 'Not Specified', 'No budget preference specified.');

  final String code;
  final String label;
  final String description;

  const BudgetTier(this.code, this.label, this.description);

  static BudgetTier fromCode(String? code) {
    for (final tier in BudgetTier.values) {
      if (tier.code == code) return tier;
    }
    return BudgetTier.flexible;
  }
}

/// Accommodation preference.
enum AccommodationStyle {
  hostel('hostel', 'Hostel', 'Social atmosphere, shared dorms or private rooms.'),
  hotel('hotel', 'Hotel', 'Quiet comfort, private rooms, and amenities.'),
  homestay('homestay', 'Homestay / Airbnb', 'Local immersion, residential feel.'),
  flexible('flexible', 'Flexible', 'Open to any clean and safe lodging.'),
  notSpecified('not_specified', 'Not Specified', 'No preference indicated.');

  final String code;
  final String label;
  final String description;

  const AccommodationStyle(this.code, this.label, this.description);

  static AccommodationStyle fromCode(String? code) {
    for (final style in AccommodationStyle.values) {
      if (style.code == code) return style;
    }
    return AccommodationStyle.flexible;
  }
}

/// Social dynamic preference.
enum SocialPreference {
  mostlySolo('introvert', 'Mostly Independent', 'Values independent time with occasional meetups.'),
  smallGroup('ambivert', 'Small Group', 'Enjoys traveling in a close pair or group of 3-4.'),
  social('extrovert', 'Social & Outgoing', 'Loves making friends, group activities, and chats.'),
  flexible('flexible', 'Flexible', 'Adapts comfortably to solo time or group energy.');

  final String code;
  final String label;
  final String description;

  const SocialPreference(this.code, this.label, this.description);

  static SocialPreference fromCode(String? code) {
    for (final pref in SocialPreference.values) {
      if (pref.code == code) return pref;
    }
    return SocialPreference.flexible;
  }
}

/// TravelPreferences domain entity.
/// Stores structured preference data for companion discovery and route compatibility.
class TravelPreferences {
  final String id;
  final String userId;
  final TravelPace travelPace;
  final BudgetTier budgetTier;
  final List<String> preferredTransport;
  final AccommodationStyle accommodationPreference;
  final String smokingPreference;
  final SocialPreference socialEnergy;
  final List<String> dietaryPreferences;
  final List<String> activityInterests;
  final PlanningStyle planningStyle;
  final ScheduleStyle schedulePreference;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TravelPreferences({
    required this.id,
    required this.userId,
    this.travelPace = TravelPace.flexible,
    this.budgetTier = BudgetTier.notSpecified,
    this.preferredTransport = const [],
    this.accommodationPreference = AccommodationStyle.flexible,
    this.smokingPreference = 'non_smoker',
    this.socialEnergy = SocialPreference.flexible,
    this.dietaryPreferences = const [],
    this.activityInterests = const [],
    this.planningStyle = PlanningStyle.flexible,
    this.schedulePreference = ScheduleStyle.flexible,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory for a newly initialized empty preferences record.
  factory TravelPreferences.empty(String userId) {
    final now = DateTime.now();
    return TravelPreferences(
      id: '',
      userId: userId,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Evaluates preference status for an activity interest:
  /// - `notSpecified` if user has not chosen any activity interests
  /// - `selected` if interest is in user's list
  /// - `notSelected` if user selected some interests but omitted this one
  PreferenceStatus getActivityStatus(String interest) {
    if (activityInterests.isEmpty) return PreferenceStatus.notSpecified;
    return activityInterests.contains(interest)
        ? PreferenceStatus.selected
        : PreferenceStatus.notSelected;
  }

  /// Evaluates preference status for a transport mode.
  PreferenceStatus getTransportStatus(String transport) {
    if (preferredTransport.isEmpty) return PreferenceStatus.notSpecified;
    return preferredTransport.contains(transport)
        ? PreferenceStatus.selected
        : PreferenceStatus.notSelected;
  }

  /// Evaluates preference status for dietary options.
  PreferenceStatus getDietaryStatus(String diet) {
    if (dietaryPreferences.isEmpty) return PreferenceStatus.notSpecified;
    return dietaryPreferences.contains(diet)
        ? PreferenceStatus.selected
        : PreferenceStatus.notSelected;
  }

  factory TravelPreferences.fromJson(Map<String, dynamic> json) {
    return TravelPreferences(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      travelPace: TravelPace.fromCode(json['travel_pace'] as String?),
      budgetTier: BudgetTier.fromCode(json['budget_tier'] as String?),
      preferredTransport: (json['preferred_transport'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      accommodationPreference: AccommodationStyle.fromCode(
          json['accommodation_preference'] as String?),
      smokingPreference: json['smoking_preference'] as String? ?? 'non_smoker',
      socialEnergy: SocialPreference.fromCode(json['social_energy'] as String?),
      dietaryPreferences: (json['dietary_preferences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      activityInterests: (json['activity_interests'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      planningStyle: PlanningStyle.fromCode(json['planning_style'] as String?),
      schedulePreference:
          ScheduleStyle.fromCode(json['schedule_preference'] as String?),
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
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'travel_pace': travelPace.code,
      'budget_tier': budgetTier.code,
      'preferred_transport': preferredTransport,
      'accommodation_preference': accommodationPreference.code,
      'smoking_preference': smokingPreference,
      'social_energy': socialEnergy.code,
      'dietary_preferences': dietaryPreferences,
      'activity_interests': activityInterests,
      'planning_style': planningStyle.code,
      'schedule_preference': schedulePreference.code,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  TravelPreferences copyWith({
    String? id,
    String? userId,
    TravelPace? travelPace,
    BudgetTier? budgetTier,
    List<String>? preferredTransport,
    AccommodationStyle? accommodationPreference,
    String? smokingPreference,
    SocialPreference? socialEnergy,
    List<String>? dietaryPreferences,
    List<String>? activityInterests,
    PlanningStyle? planningStyle,
    ScheduleStyle? schedulePreference,
    DateTime? updatedAt,
  }) {
    return TravelPreferences(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      travelPace: travelPace ?? this.travelPace,
      budgetTier: budgetTier ?? this.budgetTier,
      preferredTransport: preferredTransport ?? this.preferredTransport,
      accommodationPreference:
          accommodationPreference ?? this.accommodationPreference,
      smokingPreference: smokingPreference ?? this.smokingPreference,
      socialEnergy: socialEnergy ?? this.socialEnergy,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      activityInterests: activityInterests ?? this.activityInterests,
      planningStyle: planningStyle ?? this.planningStyle,
      schedulePreference: schedulePreference ?? this.schedulePreference,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
