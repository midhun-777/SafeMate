/// SafeMate Travel Disruption Provider Abstraction.
/// Universal Engineering Rule #11: Zero fake functionality. Never fabricate live transit or weather status.
library;

/// Structured record of an externally verified travel disruption.
class TravelDisruption {
  final String id;
  final String destination;
  final String title;
  final String description;
  final String severity; // info, advisory, warning
  final String source;
  final DateTime reportedAt;

  const TravelDisruption({
    required this.id,
    required this.destination,
    required this.title,
    required this.description,
    this.severity = 'info',
    required this.source,
    required this.reportedAt,
  });

  factory TravelDisruption.fromJson(Map<String, dynamic> json) {
    return TravelDisruption(
      id: json['id'] as String,
      destination: json['destination'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      severity: json['severity'] as String? ?? 'info',
      source: json['source'] as String? ?? 'Transit Authority',
      reportedAt: DateTime.parse(json['reported_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'destination': destination,
        'title': title,
        'description': description,
        'severity': severity,
        'source': source,
        'reported_at': reportedAt.toIso8601String(),
      };
}

/// Abstract provider interface for real-time travel disruption feeds.
abstract class TravelDisruptionProvider {
  /// Fetches verified disruptions for [destination].
  Future<List<TravelDisruption>> getDisruptionsForDestination(String destination);
}

/// No-op reference implementation when external API feeds are not connected.
/// Guaranteed to never fabricate false or speculative disruption warnings.
class NoopTravelDisruptionProvider implements TravelDisruptionProvider {
  const NoopTravelDisruptionProvider();

  @override
  Future<List<TravelDisruption>> getDisruptionsForDestination(String destination) async {
    // Return empty list; does not fabricate fake transit disruptions.
    return const [];
  }
}
