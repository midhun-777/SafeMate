/// Models and visual definitions for SafeMate Travel Personality.
/// Universal Engineering Rule #18: Human, calm, clear, no superficial personality diagnoses.
library;

/// Curated trip styles / vibes for traveler discovery.
enum TripVibe {
  relaxed('relaxed', '🌿 Relaxed', 'Leisurely pace, taking in moments and scenery.'),
  adventure('adventure', '🏔 Adventure', 'Treks, active exploration, and outdoor quests.'),
  exploreAll('explore_everything', '🗺 Explore Everything', 'Seeing the major sights, history, and hidden gems.'),
  foodCulture('food_culture', '🍜 Food & Culture', 'Local cuisine, street food, markets, and traditions.'),
  social('social', '🎉 Social', 'Meeting fellow travelers, group dinners, and events.'),
  peaceful('peaceful', '🌅 Peaceful', 'Quiet spots, nature immersion, reading, and wellness.');

  final String code;
  final String label;
  final String description;

  const TripVibe(this.code, this.label, this.description);

  static TripVibe? fromCode(String code) {
    for (final vibe in TripVibe.values) {
      if (vibe.code == code) return vibe;
    }
    return null;
  }
}

/// Travel Pace representing speed and density of travel days.
enum TravelPace {
  slow('slow', 'Slow & Relaxed', 'Unrushed days, staying longer in each spot.'),
  moderate('moderate', 'Balanced Pace', 'A healthy mix of planned sights and downtime.'),
  fast('fast', 'Fast & Packed', 'Action-packed itineraries, covering lots of ground.'),
  flexible('flexible', 'Flexible', 'Happy to adapt pace to companions and route.');

  final String code;
  final String label;
  final String description;

  const TravelPace(this.code, this.label, this.description);

  static TravelPace fromCode(String? code) {
    for (final pace in TravelPace.values) {
      if (pace.code == code) return pace;
    }
    return TravelPace.flexible;
  }
}

/// Daily schedule preference.
enum ScheduleStyle {
  earlyBird('early_bird', 'Early Bird', 'Morning starts, sunrise viewpoints, quiet hours.'),
  nightOwl('night_owl', 'Night Owl', 'Later mornings, evenings, dinner spots, and night walks.'),
  flexible('flexible', 'Flexible Schedule', 'Adapts naturally to the destination.'),
  notSpecified('not_specified', 'Not Specified', 'No strong preference indicated.');

  final String code;
  final String label;
  final String description;

  const ScheduleStyle(this.code, this.label, this.description);

  static ScheduleStyle fromCode(String? code) {
    for (final style in ScheduleStyle.values) {
      if (style.code == code) return style;
    }
    return ScheduleStyle.flexible;
  }
}

/// Planning style for trips.
enum PlanningStyle {
  structured('structured', 'Structured & Planned', 'Reservations and clear itinerary planned ahead.'),
  spontaneous('spontaneous', 'Spontaneous & Free', 'Deciding day-by-day based on mood and weather.'),
  flexible('flexible', 'Balanced & Flexible', 'Key highlights booked, rest left open to explore.'),
  notSpecified('not_specified', 'Not Specified', 'No preference specified.');

  final String code;
  final String label;
  final String description;

  const PlanningStyle(this.code, this.label, this.description);

  static PlanningStyle fromCode(String? code) {
    for (final style in PlanningStyle.values) {
      if (style.code == code) return style;
    }
    return PlanningStyle.flexible;
  }
}
