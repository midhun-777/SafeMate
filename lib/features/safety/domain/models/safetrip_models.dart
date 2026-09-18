import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';

/// SafeTrip deterministic lifecycle statuses.
/// Universal Engineering Rule #11 & Rule #18: Deterministic, server-authoritative state machine.
enum SafeTripStatus {
  preparing('preparing', 'Preparing', 'Journey configuration and consent gathering in progress.'),
  ready('ready', 'Ready', 'Pre-journey requirements met. Ready for traveler activation.'),
  active('active', 'Active', 'Journey in progress with scheduled check-in reminders.'),
  paused('paused', 'Paused', 'Journey temporarily paused by traveler (e.g. extended layover).'),
  arrived('arrived', 'Arrived', 'Traveler confirmed arrival at destination.'),
  completed('completed', 'Completed', 'Journey closed successfully; companion reviews unlocked.'),
  cancelled('cancelled', 'Cancelled', 'SafeTrip terminated before arrival.'),
  expired('expired', 'Expired', 'Journey exceeded expected arrival time plus configured safety buffer.');

  final String code;
  final String label;
  final String description;

  const SafeTripStatus(this.code, this.label, this.description);

  /// Validates if this status can deterministically transition to [target].
  bool canTransitionTo(SafeTripStatus target) {
    if (this == target) return false;

    switch (this) {
      case SafeTripStatus.preparing:
        return target == SafeTripStatus.ready || target == SafeTripStatus.cancelled;
      case SafeTripStatus.ready:
        return target == SafeTripStatus.active || target == SafeTripStatus.cancelled;
      case SafeTripStatus.active:
        return target == SafeTripStatus.paused ||
            target == SafeTripStatus.arrived ||
            target == SafeTripStatus.cancelled ||
            target == SafeTripStatus.expired;
      case SafeTripStatus.paused:
        return target == SafeTripStatus.active ||
            target == SafeTripStatus.cancelled ||
            target == SafeTripStatus.expired;
      case SafeTripStatus.arrived:
        return target == SafeTripStatus.completed || target == SafeTripStatus.cancelled;
      case SafeTripStatus.completed:
      case SafeTripStatus.cancelled:
      case SafeTripStatus.expired:
        return false; // Terminal states
    }
  }

  static SafeTripStatus fromCode(String? code) {
    for (final status in SafeTripStatus.values) {
      if (status.code == code) return status;
    }
    return SafeTripStatus.preparing;
  }
}

/// Check-in lifecycle states.
enum CheckinStatus {
  scheduled('scheduled', 'Scheduled'),
  completed('completed', 'Completed'),
  missed('missed', 'Missed'),
  expired('expired', 'Expired'),
  cancelled('cancelled', 'Cancelled');

  final String code;
  final String label;

  const CheckinStatus(this.code, this.label);

  bool canTransitionTo(CheckinStatus target) {
    if (this == target) return false;

    switch (this) {
      case CheckinStatus.scheduled:
        return target == CheckinStatus.completed ||
            target == CheckinStatus.missed ||
            target == CheckinStatus.cancelled;
      case CheckinStatus.missed:
        return target == CheckinStatus.completed ||
            target == CheckinStatus.expired ||
            target == CheckinStatus.cancelled;
      case CheckinStatus.completed:
      case CheckinStatus.expired:
      case CheckinStatus.cancelled:
        return false; // Terminal
    }
  }

  static CheckinStatus fromCode(String? code) {
    for (final s in CheckinStatus.values) {
      if (s.code == code) return s;
    }
    return CheckinStatus.scheduled;
  }
}

/// Privacy-first location sharing modes.
/// Phase 10 Universal Rule: Default is OFF. If enabled, APPROXIMATE (~20km geohash).
enum LocationSharingMode {
  off('off', 'Off'),
  approximate('approximate', 'Approximate (~20km area)'),
  precise('precise', 'Precise (Audit required)');

  final String code;
  final String label;

  const LocationSharingMode(this.code, this.label);

  static LocationSharingMode fromCode(String? code) {
    for (final m in LocationSharingMode.values) {
      if (m.code == code) return m;
    }
    return LocationSharingMode.off;
  }
}

/// Explicit, auditable traveler consent records.
class JourneyConsent {
  final bool shareStatusWithTrustedContact;
  final bool shareApproximateLocation;
  final bool sendCheckinReminders;
  final String consentVersion;
  final DateTime consentedAt;

  const JourneyConsent({
    required this.shareStatusWithTrustedContact,
    required this.shareApproximateLocation,
    required this.sendCheckinReminders,
    this.consentVersion = 'v1.0',
    required this.consentedAt,
  });

  factory JourneyConsent.fromJson(Map<String, dynamic> json) {
    return JourneyConsent(
      shareStatusWithTrustedContact:
          json['share_status_with_trusted_contact'] as bool? ?? false,
      shareApproximateLocation:
          json['share_approximate_location'] as bool? ?? false,
      sendCheckinReminders: json['send_checkin_reminders'] as bool? ?? true,
      consentVersion: json['consent_version'] as String? ?? 'v1.0',
      consentedAt: json['consented_at'] != null
          ? DateTime.parse(json['consented_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'share_status_with_trusted_contact': shareStatusWithTrustedContact,
      'share_approximate_location': shareApproximateLocation,
      'send_checkin_reminders': sendCheckinReminders,
      'consent_version': consentVersion,
      'consented_at': consentedAt.toIso8601String(),
    };
  }
}

/// A deterministic check-in record for an active SafeTrip.
class JourneyCheckin {
  final String id;
  final String journeyId;
  final String userId;
  final int checkinNumber;
  final CheckinStatus status;
  final DateTime scheduledFor;
  final DateTime? completedAt;
  final String? notes;
  final String? idempotencyKey;

  const JourneyCheckin({
    required this.id,
    required this.journeyId,
    required this.userId,
    required this.checkinNumber,
    required this.status,
    required this.scheduledFor,
    this.completedAt,
    this.notes,
    this.idempotencyKey,
  });

  factory JourneyCheckin.fromJson(Map<String, dynamic> json) {
    return JourneyCheckin(
      id: json['id'] as String,
      journeyId: json['journey_id'] as String,
      userId: json['user_id'] as String,
      checkinNumber: json['checkin_number'] as int? ?? 1,
      status: CheckinStatus.fromCode(json['status'] as String?),
      scheduledFor: DateTime.parse(json['scheduled_for'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      notes: json['notes'] as String?,
      idempotencyKey: json['idempotency_key'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'journey_id': journeyId,
      'user_id': userId,
      'checkin_number': checkinNumber,
      'status': status.code,
      'scheduled_for': scheduledFor.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'notes': notes,
      'idempotency_key': idempotencyKey,
    };
  }

  JourneyCheckin markCompleted({required DateTime timestamp}) {
    return JourneyCheckin(
      id: id,
      journeyId: journeyId,
      userId: userId,
      checkinNumber: checkinNumber,
      status: CheckinStatus.completed,
      scheduledFor: scheduledFor,
      completedAt: timestamp,
      notes: notes,
      idempotencyKey: idempotencyKey,
    );
  }
}

/// Time-limited, revocable location sharing session.
class LocationShareSession {
  final String id;
  final String journeyId;
  final String userId;
  final LocationSharingMode mode;
  final String? approxGeohash;
  final DateTime startedAt;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final DateTime updatedAt;

  const LocationShareSession({
    required this.id,
    required this.journeyId,
    required this.userId,
    required this.mode,
    this.approxGeohash,
    required this.startedAt,
    required this.expiresAt,
    this.revokedAt,
    required this.updatedAt,
  });

  bool get isActive =>
      revokedAt == null && DateTime.now().isBefore(expiresAt) && mode != LocationSharingMode.off;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isRevoked => revokedAt != null;

  factory LocationShareSession.fromJson(Map<String, dynamic> json) {
    return LocationShareSession(
      id: json['id'] as String,
      journeyId: json['journey_id'] as String,
      userId: json['user_id'] as String,
      mode: LocationSharingMode.fromCode(json['mode'] as String?),
      approxGeohash: json['approx_geohash'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      revokedAt: json['revoked_at'] != null
          ? DateTime.parse(json['revoked_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'journey_id': journeyId,
      'user_id': userId,
      'mode': mode.code,
      'approx_geohash': approxGeohash,
      'started_at': startedAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'revoked_at': revokedAt?.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Primary SafeTrip entity representing an active, supervised travel journey.
class SafeTrip {
  final String id;
  final String tripId;
  final String ownerId;
  final String? companionUserId;
  final String? trustedContactId;
  final SafeTripStatus status;
  final DateTime expectedStartTime;
  final DateTime expectedArrivalTime;
  final DateTime? actualArrivalTime;
  final DateTime? completedAt;
  final int checkinIntervalMinutes;
  final int gracePeriodMinutes;
  final DateTime? lastCheckinAt;
  final DateTime? nextCheckinDeadline;
  final LocationSharingMode locationSharingMode;
  final DateTime? locationSharingExpiresAt;
  final JourneyConsent? consent;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SafeTrip({
    required this.id,
    required this.tripId,
    required this.ownerId,
    this.companionUserId,
    this.trustedContactId,
    required this.status,
    required this.expectedStartTime,
    required this.expectedArrivalTime,
    this.actualArrivalTime,
    this.completedAt,
    this.checkinIntervalMinutes = 60,
    this.gracePeriodMinutes = 15,
    this.lastCheckinAt,
    this.nextCheckinDeadline,
    this.locationSharingMode = LocationSharingMode.off,
    this.locationSharingExpiresAt,
    this.consent,
    required this.createdAt,
    required this.updatedAt,
  });

  /// True if journey is currently in progress.
  bool get isActive => status == SafeTripStatus.active;

  /// Calculate expiry timestamp (expected arrival + safety buffer minutes).
  DateTime get autoExpiryTime =>
      expectedArrivalTime.add(Duration(minutes: gracePeriodMinutes * 2));

  /// Check if the trip is currently past its auto-expiry threshold.
  bool isPastExpiry({DateTime? currentTime}) {
    final now = currentTime ?? DateTime.now();
    return now.isAfter(autoExpiryTime);
  }

  /// Copy with convenience method for deterministic transitions.
  SafeTrip copyWith({
    SafeTripStatus? status,
    String? companionUserId,
    String? trustedContactId,
    DateTime? expectedStartTime,
    DateTime? expectedArrivalTime,
    DateTime? actualArrivalTime,
    DateTime? completedAt,
    int? checkinIntervalMinutes,
    int? gracePeriodMinutes,
    DateTime? lastCheckinAt,
    DateTime? nextCheckinDeadline,
    LocationSharingMode? locationSharingMode,
    DateTime? locationSharingExpiresAt,
    JourneyConsent? consent,
    DateTime? updatedAt,
  }) {
    return SafeTrip(
      id: id,
      tripId: tripId,
      ownerId: ownerId,
      companionUserId: companionUserId ?? this.companionUserId,
      trustedContactId: trustedContactId ?? this.trustedContactId,
      status: status ?? this.status,
      expectedStartTime: expectedStartTime ?? this.expectedStartTime,
      expectedArrivalTime: expectedArrivalTime ?? this.expectedArrivalTime,
      actualArrivalTime: actualArrivalTime ?? this.actualArrivalTime,
      completedAt: completedAt ?? this.completedAt,
      checkinIntervalMinutes:
          checkinIntervalMinutes ?? this.checkinIntervalMinutes,
      gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
      lastCheckinAt: lastCheckinAt ?? this.lastCheckinAt,
      nextCheckinDeadline: nextCheckinDeadline ?? this.nextCheckinDeadline,
      locationSharingMode: locationSharingMode ?? this.locationSharingMode,
      locationSharingExpiresAt:
          locationSharingExpiresAt ?? this.locationSharingExpiresAt,
      consent: consent ?? this.consent,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory SafeTrip.fromJson(Map<String, dynamic> json) {
    return SafeTrip(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      ownerId: json['owner_id'] as String,
      companionUserId: json['companion_user_id'] as String?,
      trustedContactId: json['trusted_contact_id'] as String?,
      status: SafeTripStatus.fromCode(json['status'] as String?),
      expectedStartTime: DateTime.parse(json['expected_start_time'] as String),
      expectedArrivalTime:
          DateTime.parse(json['expected_arrival_time'] as String),
      actualArrivalTime: json['actual_arrival_time'] != null
          ? DateTime.parse(json['actual_arrival_time'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      checkinIntervalMinutes: json['checkin_interval_minutes'] as int? ?? 60,
      gracePeriodMinutes: json['grace_period_minutes'] as int? ?? 15,
      lastCheckinAt: json['last_checkin_at'] != null
          ? DateTime.parse(json['last_checkin_at'] as String)
          : null,
      nextCheckinDeadline: json['next_checkin_deadline'] != null
          ? DateTime.parse(json['next_checkin_deadline'] as String)
          : null,
      locationSharingMode: LocationSharingMode.fromCode(
        json['location_sharing_mode'] as String?,
      ),
      locationSharingExpiresAt: json['location_sharing_expires_at'] != null
          ? DateTime.parse(json['location_sharing_expires_at'] as String)
          : null,
      consent: json['consent'] != null
          ? JourneyConsent.fromJson(json['consent'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'owner_id': ownerId,
      'companion_user_id': companionUserId,
      'trusted_contact_id': trustedContactId,
      'status': status.code,
      'expected_start_time': expectedStartTime.toIso8601String(),
      'expected_arrival_time': expectedArrivalTime.toIso8601String(),
      'actual_arrival_time': actualArrivalTime?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'checkin_interval_minutes': checkinIntervalMinutes,
      'grace_period_minutes': gracePeriodMinutes,
      'last_checkin_at': lastCheckinAt?.toIso8601String(),
      'next_checkin_deadline': nextCheckinDeadline?.toIso8601String(),
      'location_sharing_mode': locationSharingMode.code,
      'location_sharing_expires_at':
          locationSharingExpiresAt?.toIso8601String(),
      'consent': consent?.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Eligibility evaluation result for initiating a SafeTrip.
class SafeTripEligibility {
  final bool isEligible;
  final String? reason;

  const SafeTripEligibility._({required this.isEligible, this.reason});

  factory SafeTripEligibility.eligible() =>
      const SafeTripEligibility._(isEligible: true);

  factory SafeTripEligibility.ineligible(String reason) =>
      SafeTripEligibility._(isEligible: false, reason: reason);

  /// Validates if a [trip] can activate SafeTrip.
  static SafeTripEligibility validateTrip({
    required Trip trip,
    required String currentUserId,
  }) {
    if (trip.userId != currentUserId) {
      return SafeTripEligibility.ineligible(
        'SafeTrip can only be activated by the journey owner.',
      );
    }
    if (trip.status != TripStatus.published) {
      return SafeTripEligibility.ineligible(
        'SafeTrip requires a published journey. Current trip status is ${trip.status.label}.',
      );
    }
    if (trip.destination.trim().isEmpty) {
      return SafeTripEligibility.ineligible(
        'A valid journey destination is required.',
      );
    }
    if (trip.startDate.isAfter(trip.endDate)) {
      return SafeTripEligibility.ineligible(
        'Journey arrival date must be after departure date.',
      );
    }
    return SafeTripEligibility.eligible();
  }
}

/// Pure domain state machine and transition orchestrator.
class SafeTripStateMachine {
  const SafeTripStateMachine._();

  /// Validates transition legality and returns updated SafeTrip or throws [StateError].
  static SafeTrip transition({
    required SafeTrip current,
    required SafeTripStatus target,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();

    if (!current.status.canTransitionTo(target)) {
      throw StateError(
        'Illegal SafeTrip transition from ${current.status.code} to ${target.code}.',
      );
    }

    switch (target) {
      case SafeTripStatus.active:
        // Transition to ACTIVE: calculate first check-in deadline
        final deadline = now.add(
          Duration(minutes: current.checkinIntervalMinutes),
        );
        return current.copyWith(
          status: SafeTripStatus.active,
          lastCheckinAt: now,
          nextCheckinDeadline: deadline,
          updatedAt: now,
        );

      case SafeTripStatus.arrived:
        // Transition to ARRIVED: record actual arrival timestamp, stop location sharing
        return current.copyWith(
          status: SafeTripStatus.arrived,
          actualArrivalTime: now,
          locationSharingMode: LocationSharingMode.off,
          locationSharingExpiresAt: now,
          updatedAt: now,
        );

      case SafeTripStatus.completed:
        // Transition to COMPLETED: record completed timestamp
        return current.copyWith(
          status: SafeTripStatus.completed,
          completedAt: now,
          updatedAt: now,
        );

      case SafeTripStatus.cancelled:
        return current.copyWith(
          status: SafeTripStatus.cancelled,
          locationSharingMode: LocationSharingMode.off,
          locationSharingExpiresAt: now,
          updatedAt: now,
        );

      case SafeTripStatus.expired:
        return current.copyWith(
          status: SafeTripStatus.expired,
          locationSharingMode: LocationSharingMode.off,
          locationSharingExpiresAt: now,
          updatedAt: now,
        );

      case SafeTripStatus.paused:
        return current.copyWith(
          status: SafeTripStatus.paused,
          updatedAt: now,
        );

      case SafeTripStatus.ready:
      case SafeTripStatus.preparing:
        return current.copyWith(
          status: target,
          updatedAt: now,
        );
    }
  }

  /// Calculates next check-in deadline from current check-in time.
  static DateTime calculateNextDeadline({
    required DateTime lastCheckinTime,
    required int intervalMinutes,
  }) {
    return lastCheckinTime.add(Duration(minutes: intervalMinutes));
  }

  /// Determines if a check-in deadline has expired beyond grace period.
  static bool isGracePeriodExceeded({
    required DateTime deadline,
    required int gracePeriodMinutes,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    return now.isAfter(deadline.add(Duration(minutes: gracePeriodMinutes)));
  }
}
