/// SafeMate Verification Models and Enums.
/// Universal Engineering Rule #11: Safety is a core product capability.
/// Universal Engineering Rule #10: Privacy and consent are first-class design constraints.
library;

enum VerificationStatus {
  notStarted,
  pending,
  verified,
  rejected,
  expired,
  requiresReview;

  static VerificationStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'pending':
        return VerificationStatus.pending;
      case 'verified':
        return VerificationStatus.verified;
      case 'rejected':
        return VerificationStatus.rejected;
      case 'expired':
        return VerificationStatus.expired;
      case 'requires_review':
      case 'requiresreview':
        return VerificationStatus.requiresReview;
      case 'not_started':
      case 'notstarted':
      default:
        return VerificationStatus.notStarted;
    }
  }

  String toDbValue() {
    switch (this) {
      case VerificationStatus.pending:
        return 'pending';
      case VerificationStatus.verified:
        return 'verified';
      case VerificationStatus.rejected:
        return 'rejected';
      case VerificationStatus.expired:
        return 'expired';
      case VerificationStatus.requiresReview:
        return 'requires_review';
      case VerificationStatus.notStarted:
        return 'not_started';
    }
  }

  String get displayName {
    switch (this) {
      case VerificationStatus.verified:
        return 'Verified';
      case VerificationStatus.pending:
        return 'Under Review';
      case VerificationStatus.requiresReview:
        return 'Requires Review';
      case VerificationStatus.rejected:
        return 'Unsuccessful';
      case VerificationStatus.expired:
        return 'Expired';
      case VerificationStatus.notStarted:
        return 'Not Verified';
    }
  }
}

enum VerificationType {
  phone,
  governmentId,
  selfieLiveness,
  composite;

  static VerificationType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'phone':
        return VerificationType.phone;
      case 'government_id':
      case 'governmentid':
      case 'id':
        return VerificationType.governmentId;
      case 'selfie_liveness':
      case 'selfie':
        return VerificationType.selfieLiveness;
      case 'composite':
      default:
        return VerificationType.composite;
    }
  }

  String toDbValue() {
    switch (this) {
      case VerificationType.phone:
        return 'phone';
      case VerificationType.governmentId:
        return 'government_id';
      case VerificationType.selfieLiveness:
        return 'selfie_liveness';
      case VerificationType.composite:
        return 'composite';
    }
  }

  String get displayName {
    switch (this) {
      case VerificationType.phone:
        return 'Phone Number';
      case VerificationType.governmentId:
        return 'Government ID';
      case VerificationType.selfieLiveness:
        return 'Selfie & Liveness';
      case VerificationType.composite:
        return 'Identity Verification';
    }
  }
}

/// Audit record for verification attempts. Raw sensitive documents are NEVER stored.
class VerificationRecord {
  final String id;
  final String userId;
  final VerificationType type;
  final VerificationStatus status;
  final String? provider;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const VerificationRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    this.provider,
    this.failureReason,
    required this.createdAt,
    this.expiresAt,
  });

  factory VerificationRecord.fromJson(Map<String, dynamic> json) {
    return VerificationRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: VerificationType.fromString(json['verification_type'] as String?),
      status: VerificationStatus.fromString(json['status'] as String?),
      provider: json['provider'] as String?,
      failureReason: json['failure_reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'verification_type': type.toDbValue(),
      'status': status.toDbValue(),
      'provider': provider,
      'failure_reason': failureReason,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }
}
