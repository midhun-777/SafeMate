/// Curated purposes for SafeMate travel journeys.
library;

enum TripPurpose {
  vacation('vacation', '🏖 Vacation', 'Leisure, sightseeing, and unwinding'),
  weekendTrip('weekend_trip', '🎒 Weekend Getaway', 'Short escape over 2-3 days'),
  adventure('adventure', '🏔 Adventure & Trek', 'Hiking, outdoors, and active exploration'),
  exploration('exploration', '🗺 Exploration', 'Discovering new cities, culture, and sights'),
  work('work', '💻 Work / Workation', 'Remote work combined with travel'),
  study('study', '🎓 Study / Academic', 'University, workshops, or educational trips'),
  familyVisit('family_visit', '🏡 Family Visit', 'Visiting relatives or hometown'),
  event('event', '🎪 Event / Festival', 'Concerts, festivals, sports, or conferences'),
  pilgrimage('pilgrimage', '🕊 Spiritual / Pilgrimage', 'Temples, holy places, or mindful journeys'),
  other('other', '✨ Other', 'Other purposeful journey');

  final String code;
  final String label;
  final String description;

  const TripPurpose(this.code, this.label, this.description);

  static TripPurpose fromCode(String? code) {
    if (code == 'leisure') return TripPurpose.vacation;
    if (code == 'workation') return TripPurpose.work;
    if (code == 'cultural') return TripPurpose.exploration;
    if (code == 'spiritual') return TripPurpose.pilgrimage;
    for (final purpose in TripPurpose.values) {
      if (purpose.code == code) return purpose;
    }
    return TripPurpose.vacation;
  }
}
