/// Budget tier definitions for individual trips.
library;

enum TripBudgetTier {
  budget('budget', '💰 Budget-Friendly', 'Hostels, public transit, local street eats'),
  moderate('moderate', '💵 Moderate', 'Comfortable stays, balanced spending'),
  comfortable('comfortable', '💎 Comfortable', 'Upscale hotels, flights, fine dining'),
  flexible('flexible', '🔄 Flexible', 'Open to whatever fits the group flow');

  final String code;
  final String label;
  final String description;

  const TripBudgetTier(this.code, this.label, this.description);

  static TripBudgetTier fromCode(String? code) {
    if (code == 'backpacker') return TripBudgetTier.budget;
    if (code == 'luxury') return TripBudgetTier.comfortable;
    for (final tier in TripBudgetTier.values) {
      if (tier.code == code) return tier;
    }
    return TripBudgetTier.flexible;
  }
}
