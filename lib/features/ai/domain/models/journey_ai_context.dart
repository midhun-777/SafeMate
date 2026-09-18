/// Sanitized Journey AI Context Model.
/// Universal Engineering Rule #10: Privacy and consent first.
/// Enforces that only whitelisted, non-sensitive trip attributes enter the AI processing context.
library;

import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/safety/domain/models/safetrip_models.dart';

/// Whitelisted, privacy-sanitized journey context safe for AI consumption.
class JourneyAiContext {
  final String tripId;
  final String destination;
  final String approximateOrigin;
  final String startDate;
  final String endDate;
  final int durationDays;
  final String budgetTier;
  final String transportMode;
  final String tripPurpose;
  final List<String> tripStyles;
  final int maxCompanions;
  final String? safeTripStatus;
  final bool isLocationSharingActive;
  final String? sanitizedNotes;

  const JourneyAiContext({
    required this.tripId,
    required this.destination,
    required this.approximateOrigin,
    required this.startDate,
    required this.endDate,
    required this.durationDays,
    required this.budgetTier,
    required this.transportMode,
    required this.tripPurpose,
    this.tripStyles = const [],
    this.maxCompanions = 3,
    this.safeTripStatus,
    this.isLocationSharingActive = false,
    this.sanitizedNotes,
  });

  /// Factory constructing context from a [Trip] and optional [SafeTrip].
  /// Explicitly excludes any raw coordinates, email, phone numbers, or emergency contacts.
  factory JourneyAiContext.fromTrip({
    required Trip trip,
    SafeTrip? safeTrip,
  }) {
    final startStr =
        '${trip.startDate.year}-${trip.startDate.month.toString().padLeft(2, '0')}-${trip.startDate.day.toString().padLeft(2, '0')}';
    final endStr =
        '${trip.endDate.year}-${trip.endDate.month.toString().padLeft(2, '0')}-${trip.endDate.day.toString().padLeft(2, '0')}';

    return JourneyAiContext(
      tripId: trip.id,
      destination: trip.destinationCity ?? trip.destination,
      approximateOrigin: trip.originCity ?? trip.origin,
      startDate: startStr,
      endDate: endStr,
      durationDays: trip.durationDays,
      budgetTier: trip.budgetTier.label,
      transportMode: trip.transportMode.label,
      tripPurpose: trip.tripPurpose.label,
      tripStyles: List.unmodifiable(trip.tripStyles),
      maxCompanions: trip.maxCompanions,
      safeTripStatus: safeTrip?.status.label,
      isLocationSharingActive:
          safeTrip?.locationSharingMode == LocationSharingMode.approximate,
      sanitizedNotes: trip.notes != null ? _sanitizeText(trip.notes!) : null,
    );
  }

  /// Strips potential PII such as phone numbers, emails, and exact coordinates from free-form text.
  static String _sanitizeText(String input) {
    var text = input;
    // Strip emails
    text = text.replaceAll(
      RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      '[EMAIL REMOVED]',
    );
    // Strip phone numbers (10+ digits or formatted)
    text = text.replaceAll(
      RegExp(r'(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}'),
      '[PHONE REMOVED]',
    );
    // Strip lat/lon coordinates
    text = text.replaceAll(
      RegExp(r'-?\d{1,3}\.\d{4,},\s*-?\d{1,3}\.\d{4,}'),
      '[COORDINATES REMOVED]',
    );
    return text.trim();
  }

  Map<String, dynamic> toJson() => {
        'trip_id': tripId,
        'destination': destination,
        'approximate_origin': approximateOrigin,
        'start_date': startDate,
        'end_date': endDate,
        'duration_days': durationDays,
        'budget_tier': budgetTier,
        'transport_mode': transportMode,
        'trip_purpose': tripPurpose,
        'trip_styles': tripStyles,
        'max_companions': maxCompanions,
        if (safeTripStatus != null) 'safetrip_status': safeTripStatus,
        'location_sharing_active': isLocationSharingActive,
        if (sanitizedNotes != null) 'notes': sanitizedNotes,
      };
}
