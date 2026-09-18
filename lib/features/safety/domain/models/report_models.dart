/// Safety Reporting and Moderation Models.
/// Universal Engineering Rule #11: Safety is a core product capability.
/// Universal Engineering Rule #10: Privacy and consent are first-class design constraints.
library;

enum ReportCategory {
  harassment,
  inappropriateContent,
  scamOrFraud,
  fakeProfile,
  noShow,
  safetyThreat,
  other;

  static ReportCategory fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'harassment':
        return ReportCategory.harassment;
      case 'inappropriate_content':
      case 'inappropriatecontent':
        return ReportCategory.inappropriateContent;
      case 'scam_or_fraud':
      case 'scam':
      case 'fraud':
        return ReportCategory.scamOrFraud;
      case 'fake_profile':
      case 'fakeprofile':
        return ReportCategory.fakeProfile;
      case 'no_show':
      case 'noshow':
        return ReportCategory.noShow;
      case 'safety_threat':
      case 'safetythreat':
      case 'threat':
        return ReportCategory.safetyThreat;
      case 'other':
      default:
        return ReportCategory.other;
    }
  }

  String toDbValue() {
    switch (this) {
      case ReportCategory.harassment:
        return 'harassment';
      case ReportCategory.inappropriateContent:
        return 'inappropriate_content';
      case ReportCategory.scamOrFraud:
        return 'scam_or_fraud';
      case ReportCategory.fakeProfile:
        return 'fake_profile';
      case ReportCategory.noShow:
        return 'no_show';
      case ReportCategory.safetyThreat:
        return 'safety_threat';
      case ReportCategory.other:
        return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case ReportCategory.harassment:
        return 'Harassment or Bullying';
      case ReportCategory.inappropriateContent:
        return 'Inappropriate Content or Messages';
      case ReportCategory.scamOrFraud:
        return 'Scam, Fraud, or Money Request';
      case ReportCategory.fakeProfile:
        return 'Fake Profile or Impersonation';
      case ReportCategory.noShow:
        return 'No-show without Notice';
      case ReportCategory.safetyThreat:
        return 'Safety Threat or Aggressive Behavior';
      case ReportCategory.other:
        return 'Other Safety Concern';
    }
  }
}

enum ModerationStatus {
  pending,
  underReview,
  resolved,
  dismissed;

  static ModerationStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'under_review':
      case 'investigating':
        return ModerationStatus.underReview;
      case 'resolved':
        return ModerationStatus.resolved;
      case 'dismissed':
        return ModerationStatus.dismissed;
      case 'pending':
      default:
        return ModerationStatus.pending;
    }
  }

  String toDbValue() {
    switch (this) {
      case ModerationStatus.underReview:
        return 'under_review';
      case ModerationStatus.resolved:
        return 'resolved';
      case ModerationStatus.dismissed:
        return 'dismissed';
      case ModerationStatus.pending:
        return 'pending';
    }
  }
}

enum ModerationActionType {
  none,
  warn,
  temporarySuspend,
  accountBan,
  restrictCommunication;

  static ModerationActionType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'warn':
        return ModerationActionType.warn;
      case 'temporary_suspend':
      case 'suspend':
        return ModerationActionType.temporarySuspend;
      case 'account_ban':
      case 'ban':
        return ModerationActionType.accountBan;
      case 'restrict_communication':
      case 'restrict':
        return ModerationActionType.restrictCommunication;
      case 'none':
      default:
        return ModerationActionType.none;
    }
  }

  String toDbValue() {
    switch (this) {
      case ModerationActionType.warn:
        return 'warn';
      case ModerationActionType.temporarySuspend:
        return 'temporary_suspend';
      case ModerationActionType.accountBan:
        return 'account_ban';
      case ModerationActionType.restrictCommunication:
        return 'restrict_communication';
      case ModerationActionType.none:
        return 'none';
    }
  }
}

class SafetyReport {
  final String id;
  final String reporterId;
  final String reportedUserId;
  final String contextType; // 'chat', 'trip', 'profile', 'connection'
  final String? contextId;
  final ReportCategory category;
  final String description;
  final ModerationStatus status;
  final DateTime createdAt;

  const SafetyReport({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    this.contextType = 'profile',
    this.contextId,
    required this.category,
    required this.description,
    this.status = ModerationStatus.pending,
    required this.createdAt,
  });

  factory SafetyReport.fromJson(Map<String, dynamic> json) {
    return SafetyReport(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String,
      reportedUserId: json['reported_user_id'] as String,
      contextType: json['context_type'] as String? ?? 'profile',
      contextId: json['context_id'] as String?,
      category: ReportCategory.fromString(
        (json['category'] ?? json['reason']) as String?,
      ),
      description: (json['description'] ?? json['details'] ?? '') as String,
      status: ModerationStatus.fromString(json['status'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporter_id': reporterId,
      'reported_user_id': reportedUserId,
      'context_type': contextType,
      if (contextId != null) 'context_id': contextId,
      'category': category.toDbValue(),
      'reason': category.toDbValue(),
      'description': description,
      'details': description,
      'status': status.toDbValue(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
