/// SafeMate core Trip entity.
/// Represents a traveler's specific planned journey.
/// Universal Engineering Rule #11: Deterministic lifecycle and rigorous date validation.
library;

import '../../../../core/utils/geohash_helper.dart';
import 'trip_budget.dart';
import 'trip_preferences.dart';
import 'trip_purpose.dart';
import 'trip_status.dart';
import 'trip_transport.dart';
import 'trip_visibility.dart';

class Trip {
  final String id;
  final String userId;
  final String title;
  final String origin;
  final String? originCity;
  final String? originCountry;
  final String? originGeohash;
  final String destination;
  final String? destinationCity;
  final String? destinationCountry;
  final String? destinationGeohash;
  final DateTime startDate;
  final DateTime endDate;
  final TripBudgetTier budgetTier;
  final double? estimatedBudget;
  final String currency;
  final TripTransport transportMode;
  final TripPurpose tripPurpose;
  final List<String> tripStyles;
  final TripStatus status;
  final TripVisibility visibility;
  final int maxCompanions;
  final TripPreferences? preferences;
  final String? notes;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  Trip({
    required this.id,
    required this.userId,
    this.title = '',
    required this.origin,
    this.originCity,
    this.originCountry,
    this.originGeohash,
    required this.destination,
    this.destinationCity,
    this.destinationCountry,
    this.destinationGeohash,
    required this.startDate,
    required this.endDate,
    this.budgetTier = TripBudgetTier.flexible,
    this.estimatedBudget,
    this.currency = 'USD',
    this.transportMode = TripTransport.flexible,
    this.tripPurpose = TripPurpose.vacation,
    this.tripStyles = const [],
    this.status = TripStatus.draft,
    this.visibility = TripVisibility.visibleForMatching,
    this.maxCompanions = 3,
    this.preferences,
    this.notes,
    this.version = 1,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Constructor that automatically derives geohashes from coordinates.
  Trip.withCoordinates({
    required this.id,
    required this.userId,
    this.title = '',
    required this.origin,
    this.originCity,
    this.originCountry,
    required this.destination,
    this.destinationCity,
    this.destinationCountry,
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    required this.startDate,
    required this.endDate,
    this.budgetTier = TripBudgetTier.flexible,
    this.estimatedBudget,
    this.currency = 'USD',
    this.transportMode = TripTransport.flexible,
    this.tripPurpose = TripPurpose.vacation,
    this.tripStyles = const [],
    this.status = TripStatus.draft,
    this.visibility = TripVisibility.visibleForMatching,
    this.maxCompanions = 3,
    this.preferences,
    this.notes,
    this.version = 1,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : originGeohash = GeohashHelper.encode(originLat, originLon, precision: 6),
        destinationGeohash = GeohashHelper.encode(destLat, destLon, precision: 6),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Factory for creating an initial empty trip draft for [userId].
  factory Trip.newDraft(String userId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final inAWeek = today.add(const Duration(days: 7));
    return Trip(
      id: '',
      userId: userId,
      title: '',
      origin: '',
      destination: '',
      startDate: today,
      endDate: inAWeek,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Calculates total calendar days of the journey (inclusive).
  int get durationDays {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final diff = end.difference(start).inDays;
    return diff < 0 ? 0 : diff + 1;
  }

  /// Duration string label (e.g. "4 days", "1 day").
  String get durationLabel {
    final days = durationDays;
    return days == 1 ? '1 day' : '$days days';
  }

  bool get isDraft => status == TripStatus.draft;
  bool get isPublished => status == TripStatus.published;
  bool get isPaused => status == TripStatus.paused;
  bool get isCancelled => status == TripStatus.cancelled;
  bool get isCompleted => status == TripStatus.completed;

  /// Whether this trip is currently active or upcoming in the future.
  bool get isUpcoming {
    if (isCancelled || isCompleted || isDraft) return false;
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final tripEndDate = DateTime(endDate.year, endDate.month, endDate.day);
    return !tripEndDate.isBefore(todayDateOnly);
  }

  /// Whether this trip has completed or concluded in the past.
  bool get isPast {
    if (isCompleted) return true;
    if (isDraft || isCancelled) return false;
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final tripEndDate = DateTime(endDate.year, endDate.month, endDate.day);
    return tripEndDate.isBefore(todayDateOnly);
  }

  /// Comprehensive domain validation for journey attributes.
  List<String> validate({bool isPublishing = false}) {
    final errors = <String>[];

    if (origin.trim().isEmpty) {
      errors.add('Starting point (origin) is required.');
    }
    if (destination.trim().isEmpty) {
      errors.add('Destination is required.');
    }

    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    if (end.isBefore(start)) {
      errors.add('Return date cannot be earlier than departure date.');
    }
    if (end.difference(start).inDays > 365) {
      errors.add('Trip duration cannot exceed 365 days.');
    }

    if (isPublishing) {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      if (end.isBefore(todayDate)) {
        errors.add('Cannot publish a journey that has already concluded in the past.');
      }
    }

    if (estimatedBudget != null && estimatedBudget! < 0) {
      errors.add('Estimated budget cannot be negative.');
    }

    if (maxCompanions < 1 || maxCompanions > 10) {
      errors.add('Maximum companions must be between 1 and 10.');
    }

    return errors;
  }

  Trip copyWith({
    String? id,
    String? userId,
    String? title,
    String? origin,
    String? originCity,
    String? originCountry,
    String? originGeohash,
    String? destination,
    String? destinationCity,
    String? destinationCountry,
    String? destinationGeohash,
    DateTime? startDate,
    DateTime? endDate,
    TripBudgetTier? budgetTier,
    double? estimatedBudget,
    String? currency,
    TripTransport? transportMode,
    TripPurpose? tripPurpose,
    List<String>? tripStyles,
    TripStatus? status,
    TripVisibility? visibility,
    int? maxCompanions,
    TripPreferences? preferences,
    String? notes,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      origin: origin ?? this.origin,
      originCity: originCity ?? this.originCity,
      originCountry: originCountry ?? this.originCountry,
      originGeohash: originGeohash ?? this.originGeohash,
      destination: destination ?? this.destination,
      destinationCity: destinationCity ?? this.destinationCity,
      destinationCountry: destinationCountry ?? this.destinationCountry,
      destinationGeohash: destinationGeohash ?? this.destinationGeohash,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budgetTier: budgetTier ?? this.budgetTier,
      estimatedBudget: estimatedBudget ?? this.estimatedBudget,
      currency: currency ?? this.currency,
      transportMode: transportMode ?? this.transportMode,
      tripPurpose: tripPurpose ?? this.tripPurpose,
      tripStyles: tripStyles ?? this.tripStyles,
      status: status ?? this.status,
      visibility: visibility ?? this.visibility,
      maxCompanions: maxCompanions ?? this.maxCompanions,
      preferences: preferences ?? this.preferences,
      notes: notes ?? this.notes,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    final startStr =
        '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final endStr =
        '${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'title': title.trim().isNotEmpty ? title.trim() : 'Trip to $destination',
      'origin': origin,
      'origin_city': originCity,
      'origin_country': originCountry,
      'origin_geohash': originGeohash,
      'destination': destination,
      'destination_city': destinationCity,
      'destination_country': destinationCountry,
      'destination_geohash': destinationGeohash,
      'start_date': startStr,
      'end_date': endStr,
      'budget_tier': budgetTier.code,
      'estimated_budget': estimatedBudget,
      'currency': currency,
      'transport_mode': transportMode.code,
      'trip_purpose': tripPurpose.code,
      'trip_styles': tripStyles,
      'status': status.code,
      'visibility': visibility.code,
      'max_companions': maxCompanions,
      'version': version,
      if (notes != null) 'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json, {TripPreferences? preferences}) {
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val is String) return DateTime.parse(val);
      return DateTime.now();
    }

    return Trip(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      origin: json['origin'] as String? ?? '',
      originCity: json['origin_city'] as String?,
      originCountry: json['origin_country'] as String?,
      originGeohash: json['origin_geohash'] as String?,
      destination: json['destination'] as String? ?? '',
      destinationCity: json['destination_city'] as String?,
      destinationCountry: json['destination_country'] as String?,
      destinationGeohash: json['destination_geohash'] as String?,
      startDate: parseDate(json['start_date']),
      endDate: parseDate(json['end_date']),
      budgetTier: TripBudgetTier.fromCode(json['budget_tier'] as String?),
      estimatedBudget: json['estimated_budget'] != null
          ? (json['estimated_budget'] as num).toDouble()
          : null,
      currency: json['currency'] as String? ?? 'USD',
      transportMode: TripTransport.fromCode(json['transport_mode'] as String?),
      tripPurpose: TripPurpose.fromCode(json['trip_purpose'] as String?),
      tripStyles: (json['trip_styles'] as List<dynamic>?)?.cast<String>() ?? const [],
      status: TripStatus.fromCode(json['status'] as String?),
      visibility: TripVisibility.fromCode(json['visibility'] as String?),
      maxCompanions: json['max_companions'] as int? ?? 3,
      preferences: preferences,
      notes: json['notes'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: json['created_at'] != null ? parseDate(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? parseDate(json['updated_at']) : DateTime.now(),
    );
  }
}
