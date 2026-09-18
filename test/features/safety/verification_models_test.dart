import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/safety/domain/models/verification_models.dart';

void main() {
  group('Verification Models and Enums', () {
    test('VerificationStatus parsing and conversion', () {
      expect(VerificationStatus.fromString('verified'), VerificationStatus.verified);
      expect(VerificationStatus.fromString('pending'), VerificationStatus.pending);
      expect(VerificationStatus.fromString('rejected'), VerificationStatus.rejected);
      expect(VerificationStatus.fromString('expired'), VerificationStatus.expired);
      expect(VerificationStatus.fromString('requires_review'), VerificationStatus.requiresReview);
      expect(VerificationStatus.fromString('unknown'), VerificationStatus.notStarted);
      expect(VerificationStatus.fromString(null), VerificationStatus.notStarted);

      expect(VerificationStatus.verified.toDbValue(), 'verified');
      expect(VerificationStatus.requiresReview.toDbValue(), 'requires_review');
      expect(VerificationStatus.verified.displayName, 'Verified');
    });

    test('VerificationType parsing and conversion', () {
      expect(VerificationType.fromString('phone'), VerificationType.phone);
      expect(VerificationType.fromString('government_id'), VerificationType.governmentId);
      expect(VerificationType.fromString('selfie_liveness'), VerificationType.selfieLiveness);
      expect(VerificationType.fromString('composite'), VerificationType.composite);
      expect(VerificationType.fromString(null), VerificationType.composite);

      expect(VerificationType.phone.toDbValue(), 'phone');
      expect(VerificationType.governmentId.displayName, 'Government ID');
    });

    test('VerificationRecord serialization and deserialization', () {
      final now = DateTime.now();
      final record = VerificationRecord(
        id: 'rec-123',
        userId: 'user-456',
        type: VerificationType.governmentId,
        status: VerificationStatus.verified,
        provider: 'SafeMate Shield',
        failureReason: null,
        createdAt: now,
        expiresAt: now.add(const Duration(days: 365)),
      );

      final json = record.toJson();
      expect(json['id'], 'rec-123');
      expect(json['user_id'], 'user-456');
      expect(json['verification_type'], 'government_id');
      expect(json['status'], 'verified');

      final reconstructed = VerificationRecord.fromJson(json);
      expect(reconstructed.id, record.id);
      expect(reconstructed.userId, record.userId);
      expect(reconstructed.type, VerificationType.governmentId);
      expect(reconstructed.status, VerificationStatus.verified);
      expect(reconstructed.provider, 'SafeMate Shield');
    });
  });
}
