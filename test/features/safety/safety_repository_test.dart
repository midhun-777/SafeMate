import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/profile/domain/models/profile_visibility.dart';
import 'package:safemate/features/safety/data/repositories/supabase_safety_repository.dart';
import 'package:safemate/features/safety/domain/models/report_models.dart';
import 'package:safemate/features/safety/domain/models/safety_contact.dart';
import 'package:safemate/features/safety/domain/models/trust_models.dart';
import 'package:safemate/features/safety/domain/models/verification_models.dart';

void main() {
  late SupabaseSafetyRepository repository;

  setUp(() {
    repository = SupabaseSafetyRepository();
  });

  group('SupabaseSafetyRepository - Verification', () {
    test('Can request and approve government ID verification', () async {
      final req = await repository.requestVerification(
        userId: 'user-1',
        type: VerificationType.governmentId,
      );

      expect(req.id, isNotEmpty);
      expect(req.status, VerificationStatus.pending);

      final approved = await repository.submitVerification(
        recordId: req.id,
        approved: true,
      );

      expect(approved.status, VerificationStatus.verified);
      expect(approved.expiresAt, isNotNull);

      final latest = await repository.getLatestVerification('user-1', VerificationType.governmentId);
      expect(latest?.status, VerificationStatus.verified);
    });

    test('Can reject verification with failure reason', () async {
      final req = await repository.requestVerification(
        userId: 'user-2',
        type: VerificationType.phone,
      );

      final rejected = await repository.submitVerification(
        recordId: req.id,
        approved: false,
        failureReason: 'Invalid code provided',
      );

      expect(rejected.status, VerificationStatus.rejected);
      expect(rejected.failureReason, 'Invalid code provided');
    });
  });

  group('SupabaseSafetyRepository - Safety Contacts', () {
    test('Manages trusted safety contacts lifecycle', () async {
      final contact = SafetyContact(
        id: 'contact-1',
        userId: 'user-1',
        contactName: 'Jane Doe',
        phoneNumber: '+1234567890',
        relationship: 'Sister',
        createdAt: DateTime.now(),
      );

      await repository.addSafetyContact(contact);
      final list = await repository.getSafetyContacts('user-1');
      expect(list.length, 1);
      expect(list.first.contactName, 'Jane Doe');

      final updated = SafetyContact(
        id: 'contact-1',
        userId: 'user-1',
        contactName: 'Jane Doe Updated',
        phoneNumber: '+1234567890',
        relationship: 'Sister',
        createdAt: DateTime.now(),
      );
      await repository.updateSafetyContact(updated);
      final listAfterUpdate = await repository.getSafetyContacts('user-1');
      expect(listAfterUpdate.first.contactName, 'Jane Doe Updated');

      await repository.deleteSafetyContact('contact-1');
      final listAfterDelete = await repository.getSafetyContacts('user-1');
      expect(listAfterDelete, isEmpty);
    });
  });

  group('SupabaseSafetyRepository - Privacy Settings', () {
    test('Fetches defaults and updates privacy settings', () async {
      final defaults = await repository.getPrivacySettings('user-abc');
      expect(defaults.profileVisibility, ProfileVisibility.publicToMatches);
      expect(defaults.coarseLocationOnly, true);

      final updated = defaults.copyWith(
        profileVisibility: ProfileVisibility.private,
      );
      await repository.updatePrivacySettings(updated);

      final current = await repository.getPrivacySettings('user-abc');
      expect(current.profileVisibility, ProfileVisibility.private);
    });
  });

  group('SupabaseSafetyRepository - Reports & Blocks', () {
    test('Submits confidential safety report and blocks user', () async {
      final report = SafetyReport(
        id: 'rep-1',
        reporterId: 'user-reporter',
        reportedUserId: 'user-bad',
        category: ReportCategory.scamOrFraud,
        description: 'Demanded advance wire payment outside app',
        createdAt: DateTime.now(),
      );

      final submitted = await repository.submitReport(report);
      expect(submitted.category, ReportCategory.scamOrFraud);

      await repository.blockUser(
        blockerId: 'user-reporter',
        blockedUserId: 'user-bad',
      );

      final blocked = await repository.getBlockedUserIds('user-reporter');
      expect(blocked, contains('user-bad'));

      await repository.unblockUser(
        blockerId: 'user-reporter',
        blockedUserId: 'user-bad',
      );

      final blockedAfter = await repository.getBlockedUserIds('user-reporter');
      expect(blockedAfter, isNot(contains('user-bad')));
    });
  });

  group('SupabaseSafetyRepository - Reviews & Trust Profile', () {
    test('Submits companion reviews and computes trust profile', () async {
      final review = CompanionReview(
        id: 'rev-1',
        tripId: 'trip-100',
        reviewerId: 'user-a',
        revieweeId: 'user-trust',
        communicationRating: 5,
        punctualityRating: 5,
        respectRating: 5,
        planningRating: 5,
        overallRating: 5.0,
        comment: 'Outstanding travel companion!',
        createdAt: DateTime.now(),
      );

      await repository.submitCompanionReview(review);
      final reviews = await repository.getReviewsForUser('user-trust');
      expect(reviews.length, 1);
      expect(reviews.first.overallRating, 5.0);

      final profile = await repository.getTrustProfile('user-trust');
      expect(profile.userId, 'user-trust');
      expect(profile.reliabilityRating, 5.0);
      expect(profile.reviewCount, 1);
      expect(profile.trustScore, greaterThan(0));
    });
  });
}
