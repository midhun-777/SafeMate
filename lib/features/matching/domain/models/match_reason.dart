/// Explainable match reasons and transparent mismatch notes.
/// Universal Engineering Rule #6: Explainable outputs, no hidden formulas or insulting language.
library;

/// Distinct categorization of match explanations.
enum MatchReasonType {
  sameDestination('Same Destination', '🎯'),
  routeOverlap('Route Overlap', '📍'),
  dateOverlap('Date Overlap', '📅'),
  sameTransport('Transit Alignment', '🚆'),
  similarBudget('Similar Budget', '💰'),
  samePurpose('Shared Purpose', '🗺'),
  sharedInterests('Shared Interests', '✨'),
  similarTravelStyle('Pace & Style Alignment', '🎒'),
  similarSchedule('Schedule Harmony', '⏰'),
  preferenceAlignment('Companion Criteria Alignment', '🤝');

  final String label;
  final String icon;
  const MatchReasonType(this.label, this.icon);
}

/// A structured, positive or neutral reason contributing to a strong match.
class MatchReason {
  final MatchReasonType type;
  final String title;
  final String explanation;
  final bool isPositive;
  final String? supportingValue;

  const MatchReason({
    required this.type,
    required this.title,
    required this.explanation,
    this.isPositive = true,
    this.supportingValue,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'title': title,
        'explanation': explanation,
        'is_positive': isPositive,
        'supporting_value': supportingValue,
      };

  factory MatchReason.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'sameDestination';
    final type = MatchReasonType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => MatchReasonType.sameDestination,
    );
    return MatchReason(
      type: type,
      title: json['title'] as String? ?? type.label,
      explanation: json['explanation'] as String? ?? '',
      isPositive: json['is_positive'] as bool? ?? true,
      supportingValue: json['supporting_value'] as String?,
    );
  }
}

/// A respectful note explaining a dimension where traveler criteria differ.
class MismatchExplanation {
  final String dimension;
  final String note;

  const MismatchExplanation({
    required this.dimension,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'dimension': dimension,
        'note': note,
      };

  factory MismatchExplanation.fromJson(Map<String, dynamic> json) =>
      MismatchExplanation(
        dimension: json['dimension'] as String? ?? 'Preference',
        note: json['note'] as String? ?? '',
      );
}
