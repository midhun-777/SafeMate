import '../../../../core/utils/geohash_helper.dart';

/// Trip domain model for SafeMate.
/// Supports scalable geographic indexing via Geohashes (Universal Engineering Rule #12).
class Trip {
  final String id;
  final String userId;
  final String title;
  final String origin;
  final String destination;
  final String? originGeohash;
  final String? destinationGeohash;
  final DateTime startDate;
  final DateTime endDate;
  final double? estimatedBudget;
  final String currency;
  final String transportMode; // flight, train, road_trip, backpacking, cruise, flexible
  final String tripPurpose; // leisure, adventure, workation, cultural, spiritual, other
  final String status; // draft, planned, active, completed, cancelled
  final int maxCompanions;
  final DateTime createdAt;

  Trip({
    required this.id,
    required this.userId,
    required this.title,
    required this.origin,
    required this.destination,
    this.originGeohash,
    this.destinationGeohash,
    required this.startDate,
    required this.endDate,
    this.estimatedBudget,
    this.currency = 'USD',
    this.transportMode = 'flexible',
    this.tripPurpose = 'leisure',
    this.status = 'planned',
    this.maxCompanions = 3,
    DateTime? createdAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        assert(!endDate.isBefore(startDate), 'Trip endDate cannot precede startDate');

  /// Creates a Trip with computed geohashes from coordinates.
  factory Trip.withCoordinates({
    required String id,
    required String userId,
    required String title,
    required String origin,
    required String destination,
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    required DateTime startDate,
    required DateTime endDate,
    double? estimatedBudget,
    String currency = 'USD',
    String transportMode = 'flexible',
    String tripPurpose = 'leisure',
    String status = 'planned',
    int maxCompanions = 3,
  }) {
    return Trip(
      id: id,
      userId: userId,
      title: title,
      origin: origin,
      destination: destination,
      originGeohash: GeohashHelper.encode(originLat, originLon, precision: 6),
      destinationGeohash: GeohashHelper.encode(destLat, destLon, precision: 6),
      startDate: startDate,
      endDate: endDate,
      estimatedBudget: estimatedBudget,
      currency: currency,
      transportMode: transportMode,
      tripPurpose: tripPurpose,
      status: status,
      maxCompanions: maxCompanions,
    );
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      originGeohash: json['origin_geohash'] as String?,
      destinationGeohash: json['destination_geohash'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      estimatedBudget: (json['estimated_budget'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      transportMode: json['transport_mode'] as String? ?? 'flexible',
      tripPurpose: json['trip_purpose'] as String? ?? 'leisure',
      status: json['status'] as String? ?? 'planned',
      maxCompanions: (json['max_companions'] as num?)?.toInt() ?? 3,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'origin': origin,
      'destination': destination,
      'origin_geohash': originGeohash,
      'destination_geohash': destinationGeohash,
      'start_date': startDate.toIso8601String().split('T').first,
      'end_date': endDate.toIso8601String().split('T').first,
      'estimated_budget': estimatedBudget,
      'currency': currency,
      'transport_mode': transportMode,
      'trip_purpose': tripPurpose,
      'status': status,
      'max_companions': maxCompanions,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
