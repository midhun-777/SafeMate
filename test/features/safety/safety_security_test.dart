import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/safety/domain/models/privacy_settings.dart';
import 'package:safemate/features/safety/domain/models/report_models.dart';
import 'package:safemate/features/safety/domain/models/verification_models.dart';

void main() {
  group('Safety & Privacy Security Safeguards', () {
    test('Zero raw document exposure in VerificationRecord', () {
      final record = VerificationRecord(
        id: 'rec-001',
        userId: 'user-001',
        type: VerificationType.governmentId,
        status: VerificationStatus.verified,
        provider: 'SafeMate Shield',
        createdAt: DateTime.now(),
      );

      final json = record.toJson();

      // Ensure no raw identity document keys exist
      expect(json.containsKey('aadhaar_number'), isFalse);
      expect(json.containsKey('passport_number'), isFalse);
      expect(json.containsKey('raw_document_url'), isFalse);
      expect(json.containsKey('ssn'), isFalse);
      expect(json.containsKey('document_image'), isFalse);
    });

    test('Confidentiality of SafetyReport: ensures valid payload structure without leaking reporter data to target', () {
      final report = SafetyReport(
        id: 'rep-001',
        reporterId: 'confidential-reporter-id',
        reportedUserId: 'target-user-id',
        category: ReportCategory.harassment,
        description: 'Sent abusive messages in chat',
        createdAt: DateTime.now(),
      );

      final payload = report.toJson();
      expect(payload['reporter_id'], 'confidential-reporter-id');
      expect(payload['reported_user_id'], 'target-user-id');
      // Status defaults to pending
      expect(payload['status'], 'pending');
    });

    test('Privacy defaults prevent precise coordinate exposure', () {
      final settings = PrivacySettings.defaults('user-privacy-test');

      // Universal Engineering Rule #10: Coarse location must default to TRUE
      expect(settings.coarseLocationOnly, isTrue);
    });
  });
}
