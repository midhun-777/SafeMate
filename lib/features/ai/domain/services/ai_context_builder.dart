/// SafeMate AI Context Builder & Privacy Filtering Engine.
/// Universal Engineering Rule #10: Privacy and consent are first-class design constraints.
/// Universal Engineering Rule #11: Strict authorization check on context compilation.
library;

import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/safety/domain/models/safetrip_models.dart';
import '../models/journey_ai_context.dart';

/// Builder responsible for compiling authorized, privacy-sanitized AI journey context.
class AiJourneyContextBuilder {
  const AiJourneyContextBuilder();

  /// Explicit Allowlist of fields permitted to enter AI context.
  static const Set<String> allowlist = {
    'trip_id',
    'destination',
    'approximate_origin',
    'start_date',
    'end_date',
    'duration_days',
    'budget_tier',
    'transport_mode',
    'trip_purpose',
    'trip_styles',
    'max_companions',
    'safetrip_status',
    'location_sharing_active',
    'notes',
  };

  /// Explicit Denylist of prohibited fields that must NEVER enter AI context.
  static const Set<String> denylist = {
    'aadhaar',
    'government_id',
    'id_number',
    'passport',
    'phone',
    'phone_number',
    'email',
    'raw_address',
    'lat',
    'latitude',
    'lon',
    'longitude',
    'exact_coordinates',
    'auth_token',
    'password',
    'pin',
    'secret_code',
    'emergency_contact_name',
    'emergency_contact_phone',
    'risk_score',
    'hidden_flag',
    'moderation_notes',
  };

  /// Compiles a [JourneyAiContext] for [trip] ensuring authorization and privacy rules.
  /// Throws [StateError] if [requestingUserId] is not authorized to inspect this trip.
  JourneyAiContext buildContext({
    required Trip trip,
    SafeTrip? safeTrip,
    required String requestingUserId,
  }) {
    // 1. Authorization check: User must be owner or accepted companion
    final isOwner = trip.userId == requestingUserId;
    final isCompanion = safeTrip != null && safeTrip.companionUserId == requestingUserId;

    if (!isOwner && !isCompanion) {
      throw StateError(
        'Unauthorized AI context request: user $requestingUserId cannot access trip ${trip.id}.',
      );
    }

    // 2. Build sanitized context
    final context = JourneyAiContext.fromTrip(trip: trip, safeTrip: safeTrip);

    // 3. Verify that the serialized context contains zero denylisted keys
    final jsonMap = context.toJson();
    for (final key in jsonMap.keys) {
      if (denylist.contains(key.toLowerCase())) {
        throw StateError('Critical privacy violation: Denylisted key "$key" detected in AI context.');
      }
    }

    return context;
  }

  /// Validates an arbitrary parameter map against the denylist.
  static bool containsSensitiveData(Map<String, dynamic> data) {
    for (final key in data.keys) {
      if (denylist.contains(key.toLowerCase())) {
        return true;
      }
      final val = data[key];
      if (val is String) {
        if (_hasDirectPii(val)) return true;
      }
    }
    return false;
  }

  /// Scans free-form string for raw emails, phone numbers, or coordinates.
  static bool _hasDirectPii(String text) {
    final emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    final phoneRegex = RegExp(r'(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}');
    final coordRegex = RegExp(r'-?\d{1,3}\.\d{4,},\s*-?\d{1,3}\.\d{4,}');
    return emailRegex.hasMatch(text) || phoneRegex.hasMatch(text) || coordRegex.hasMatch(text);
  }
}
