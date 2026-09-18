import 'package:safemate/features/safety/domain/models/privacy_settings.dart';
import 'package:safemate/features/safety/domain/models/report_models.dart';
import 'package:safemate/features/safety/domain/models/safety_contact.dart';
import 'package:safemate/features/safety/domain/models/trust_models.dart';
import 'package:safemate/features/safety/domain/models/verification_models.dart';

/// Repository interface for Trust, Verification, Safety Contacts, Privacy, and Reporting.
/// Universal Engineering Rule #11: Safety is a core product capability.
abstract class SafetyRepository {
  // --- Verification ---
  Future<VerificationRecord?> getLatestVerification(
    String userId,
    VerificationType type,
  );

  Future<List<VerificationRecord>> getVerificationHistory(String userId);

  Future<VerificationRecord> requestVerification({
    required String userId,
    required VerificationType type,
    String? provider,
  });

  Future<VerificationRecord> submitVerification({
    required String recordId,
    required bool approved,
    String? failureReason,
  });

  // --- Trusted Contacts ---
  Future<List<SafetyContact>> getSafetyContacts(String userId);

  Future<SafetyContact> addSafetyContact(SafetyContact contact);

  Future<SafetyContact> updateSafetyContact(SafetyContact contact);

  Future<void> deleteSafetyContact(String contactId);

  // --- Privacy Settings ---
  Future<PrivacySettings> getPrivacySettings(String userId);

  Future<PrivacySettings> updatePrivacySettings(PrivacySettings settings);

  // --- Reporting and Blocking ---
  Future<SafetyReport> submitReport(SafetyReport report);

  Future<void> blockUser({
    required String blockerId,
    required String blockedUserId,
    String? reason,
  });

  Future<void> unblockUser({
    required String blockerId,
    required String blockedUserId,
  });

  Future<List<String>> getBlockedUserIds(String blockerId);

  // --- Companion Reviews and Trust Profile ---
  Future<CompanionReview> submitCompanionReview(CompanionReview review);

  Future<List<CompanionReview>> getReviewsForUser(String userId);

  Future<TrustProfile> getTrustProfile(String userId);
}
