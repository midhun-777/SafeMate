/// Deterministic, normalized compatibility score for companion discovery.
/// Universal Engineering Rule #6: Explainable, reproducible, normalized (0–100).
library;

/// Semantic compatibility quality bands.
enum MatchQualityBand {
  excellent('Excellent Match', 'Highly aligned across destination, dates, and travel values.'),
  strong('Strong Match', 'Strong route and date alignment with compatible preferences.'),
  good('Good Match', 'Meaningful route overlap and compatible travel styles.'),
  low('Low Compatibility', 'Significant differences in itinerary or travel criteria.');

  final String label;
  final String description;
  const MatchQualityBand(this.label, this.description);

  static MatchQualityBand fromScore(int score) {
    if (score >= 90) return MatchQualityBand.excellent;
    if (score >= 75) return MatchQualityBand.strong;
    if (score >= 60) return MatchQualityBand.good;
    return MatchQualityBand.low;
  }
}

/// Breakdown of individual compatibility dimensions (each normalized 0–100).
class MatchComponentScore {
  final int routeScore;
  final int dateScore;
  final int transportScore;
  final int budgetScore;
  final int purposeScore;
  final int styleScore;
  final int preferenceScore;
  final int scheduleScore;

  const MatchComponentScore({
    required this.routeScore,
    required this.dateScore,
    required this.transportScore,
    required this.budgetScore,
    required this.purposeScore,
    required this.styleScore,
    required this.preferenceScore,
    required this.scheduleScore,
  });

  Map<String, dynamic> toJson() => {
        'route': routeScore,
        'date': dateScore,
        'transport': transportScore,
        'budget': budgetScore,
        'purpose': purposeScore,
        'style': styleScore,
        'preference': preferenceScore,
        'schedule': scheduleScore,
      };

  factory MatchComponentScore.fromJson(Map<String, dynamic> json) =>
      MatchComponentScore(
        routeScore: (json['route'] as num?)?.toInt() ?? 0,
        dateScore: (json['date'] as num?)?.toInt() ?? 0,
        transportScore: (json['transport'] as num?)?.toInt() ?? 0,
        budgetScore: (json['budget'] as num?)?.toInt() ?? 0,
        purposeScore: (json['purpose'] as num?)?.toInt() ?? 0,
        styleScore: (json['style'] as num?)?.toInt() ?? 0,
        preferenceScore: (json['preference'] as num?)?.toInt() ?? 0,
        scheduleScore: (json['schedule'] as num?)?.toInt() ?? 0,
      );
}

/// Top-level deterministic compatibility score with version metadata.
class CompatibilityScore {
  final int total;
  final MatchComponentScore components;
  final MatchQualityBand band;
  final String scoreVersion;

  static const String currentVersion = 'v1';

  // Centralized scoring weights (sum = 1.0)
  static const double weightRoute = 0.25;
  static const double weightDate = 0.20;
  static const double weightTransport = 0.10;
  static const double weightBudget = 0.10;
  static const double weightPurpose = 0.10;
  static const double weightStyle = 0.10;
  static const double weightPreference = 0.10;
  static const double weightSchedule = 0.05;

  const CompatibilityScore({
    required this.total,
    required this.components,
    required this.band,
    this.scoreVersion = currentVersion,
  });

  /// Factory calculating total from weighted component scores.
  factory CompatibilityScore.fromComponents(
    MatchComponentScore components, {
    String scoreVersion = currentVersion,
  }) {
    final rawTotal = (components.routeScore * weightRoute) +
        (components.dateScore * weightDate) +
        (components.transportScore * weightTransport) +
        (components.budgetScore * weightBudget) +
        (components.purposeScore * weightPurpose) +
        (components.styleScore * weightStyle) +
        (components.preferenceScore * weightPreference) +
        (components.scheduleScore * weightSchedule);

    final clampedTotal = rawTotal.round().clamp(0, 100);
    return CompatibilityScore(
      total: clampedTotal,
      components: components,
      band: MatchQualityBand.fromScore(clampedTotal),
      scoreVersion: scoreVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'total': total,
        'components': components.toJson(),
        'band': band.name,
        'score_version': scoreVersion,
      };

  factory CompatibilityScore.fromJson(Map<String, dynamic> json) {
    final total = (json['total'] as num?)?.toInt() ?? 0;
    final components = json['components'] != null
        ? MatchComponentScore.fromJson(json['components'] as Map<String, dynamic>)
        : const MatchComponentScore(
            routeScore: 0,
            dateScore: 0,
            transportScore: 0,
            budgetScore: 0,
            purposeScore: 0,
            styleScore: 0,
            preferenceScore: 0,
            scheduleScore: 0,
          );
    return CompatibilityScore(
      total: total,
      components: components,
      band: MatchQualityBand.fromScore(total),
      scoreVersion: json['score_version'] as String? ?? currentVersion,
    );
  }
}
