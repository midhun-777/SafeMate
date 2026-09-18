/// Supabase implementation of SafetyRepository.
/// Universal Engineering Rule #7: Strict server-side enforcement.
/// Universal Engineering Rule #11: Safety is a core product capability.
/// Supports offline development mode and live Supabase PostgREST & RPCs.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/models/privacy_settings.dart';
import '../../domain/models/report_models.dart';
import '../../domain/models/safety_contact.dart';
import '../../domain/models/trust_models.dart';
import '../../domain/models/verification_models.dart';
import '../../domain/repositories/safety_repository.dart';

class SupabaseSafetyRepository implements SafetyRepository {
  final sb.SupabaseClient? client;
  final _uuid = const Uuid();

  // In-memory development storage for offline mode and tests
  final Map<String, List<VerificationRecord>> _devVerifications = {};
  final Map<String, List<SafetyContact>> _devContacts = {};
  final Map<String, PrivacySettings> _devPrivacySettings = {};
  final List<SafetyReport> _devReports = [];
  final Set<String> _devBlocks = {}; // formatted as "blockerId:blockedUserId"
  final Map<String, List<CompanionReview>> _devReviews = {}; // revieweeId -> reviews

  SupabaseSafetyRepository({this.client});

  sb.SupabaseClient? get _activeClient =>
      client ?? (AppConfig.hasValidSupabaseConfig ? sb.Supabase.instance.client : null);

  // ---------------------------------------------------------------------------
  // VERIFICATION
  // ---------------------------------------------------------------------------

  @override
  Future<VerificationRecord?> getLatestVerification(
    String userId,
    VerificationType type,
  ) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      final records = _devVerifications[userId] ?? [];
      final matches = records.where((r) => r.type == type).toList();
      if (matches.isEmpty) return null;
      matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return matches.first;
    }

    try {
      final response = await activeClient
          .from('verification_records')
          .select()
          .eq('user_id', userId)
          .eq('verification_type', type.toDbValue())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return VerificationRecord.fromJson(response);
    } catch (e) {
      debugPrint('[SupabaseSafetyRepository] Error getting latest verification: $e');
      throw AppException('Failed to retrieve verification status: $e');
    }
  }

  @override
  Future<List<VerificationRecord>> getVerificationHistory(String userId) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      final records = _devVerifications[userId] ?? [];
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return List.unmodifiable(records);
    }

    try {
      final response = await activeClient
          .from('verification_records')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((r) => VerificationRecord.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SupabaseSafetyRepository] Error getting verification history: $e');
      throw AppException('Failed to retrieve verification history: $e');
    }
  }

  @override
  Future<VerificationRecord> requestVerification({
    required String userId,
    required VerificationType type,
    String? provider,
  }) async {
    final recordId = _uuid.v4();
    final now = DateTime.now();

    final newRecord = VerificationRecord(
      id: recordId,
      userId: userId,
      type: type,
      status: VerificationStatus.pending,
      provider: provider ?? 'SafeMate Identity Service',
      createdAt: now,
    );

    final activeClient = _activeClient;
    if (activeClient == null) {
      _devVerifications.putIfAbsent(userId, () => []).add(newRecord);
      return newRecord;
    }

    try {
      final response = await activeClient
          .from('verification_records')
          .insert(newRecord.toJson())
          .select()
          .single();

      return VerificationRecord.fromJson(response);
    } catch (e) {
      debugPrint('[SupabaseSafetyRepository] Error requesting verification: $e');
      throw AppException('Failed to initiate verification request: $e');
    }
  }

  @override
  Future<VerificationRecord> submitVerification({
    required String recordId,
    required bool approved,
    String? failureReason,
  }) async {
    final newStatus = approved ? VerificationStatus.verified : VerificationStatus.rejected;
    final expiresAt = approved ? DateTime.now().add(const Duration(days: 365)) : null;

    final activeClient = _activeClient;
    if (activeClient == null) {
      VerificationRecord? target;
      String? targetUserId;

      for (final entry in _devVerifications.entries) {
        final idx = entry.value.indexWhere((r) => r.id == recordId);
        if (idx != -1) {
          final old = entry.value[idx];
          target = VerificationRecord(
            id: old.id,
            userId: old.userId,
            type: old.type,
            status: newStatus,
            provider: old.provider,
            failureReason: failureReason,
            createdAt: old.createdAt,
            expiresAt: expiresAt,
          );
          entry.value[idx] = target;
          targetUserId = old.userId;
          break;
        }
      }

      if (target == null) {
        throw const AppException('Verification record not found in test store');
      }

      // Sync user profile verification state if approved
      if (approved && targetUserId != null) {
        // Updated in dev profile if needed
      }

      return target;
    }

    try {
      final response = await activeClient
          .from('verification_records')
          .update({
            'status': newStatus.toDbValue(),
            'failure_reason': failureReason,
            'expires_at': expiresAt?.toIso8601String(),
          })
          .eq('id', recordId)
          .select()
          .single();

      final updated = VerificationRecord.fromJson(response);

      // If approved, update users table flags via safe update
      if (approved) {
        if (updated.type == VerificationType.phone) {
          await activeClient
              .from('users')
              .update({'is_phone_verified': true})
              .eq('id', updated.userId);
        } else if (updated.type == VerificationType.governmentId ||
            updated.type == VerificationType.composite) {
          await activeClient
              .from('users')
              .update({'is_verified': true})
              .eq('id', updated.userId);
        }
      }

      return updated;
    } catch (e) {
      debugPrint('[SupabaseSafetyRepository] Error submitting verification: $e');
      throw AppException('Failed to update verification status: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // TRUSTED CONTACTS
  // ---------------------------------------------------------------------------

  @override
  Future<List<SafetyContact>> getSafetyContacts(String userId) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      return List.unmodifiable(_devContacts[userId] ?? []);
    }

    try {
      final response = await activeClient
          .from('safety_contacts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((c) => SafetyContact.fromJson(c as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SupabaseSafetyRepository] Error getting safety contacts: $e');
      throw AppException('Failed to retrieve safety contacts: $e');
    }
  }

  @override
  Future<SafetyContact> addSafetyContact(SafetyContact contact) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      _devContacts.putIfAbsent(contact.userId, () => []).add(contact);
      return contact;
    }

    try {
      final response = await activeClient
          .from('safety_contacts')
          .insert(contact.toJson())
          .select()
          .single();

      return SafetyContact.fromJson(response);
    } catch (e) {
      debugPrint('[SupabaseSafetyRepository] Error adding safety contact: $e');
      throw AppException('Failed to save safety contact: $e');
    }
  }

  @override
  Future<SafetyContact> updateSafetyContact(SafetyContact contact) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      final list = _devContacts[contact.userId] ?? [];
      final idx = list.indexWhere((c) => c.id == contact.id);
      if (idx != -1) {
        list[idx] = contact;
        return contact;
      }
      throw const AppException('Contact not found in local store');
    }

    try {
      final response = await activeClient
          .from('safety_contacts')
          .update(contact.toJson())
          .eq('id', contact.id)
          .select()
          .single();

      return SafetyContact.fromJson(response);
    } catch (e) {
      debugPrint('[SupabaseSafetyRepository] Error updating safety contact: $e');
      throw AppException('Failed to update safety contact: $e');
    }
  }

  @override
  Future<void> deleteSafetyContact(String contactId) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      for (final list in _devContacts.values) {
        list.removeWhere((c) => c.id == contactId);
      }
      return;
    }

    try {
      await activeClient.from('safety_contacts').delete().eq('id', contactId);
    } catch (e) {
      debugPrint('[SupabaseSafetyRepository] Error deleting safety contact: $e');
      throw AppException('Failed to delete safety contact: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // PRIVACY SETTINGS
  // ---------------------------------------------------------------------------

  @override
  Future<PrivacySettings> getPrivacySettings(String userId) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      return _devPrivacySettings[userId] ?? PrivacySettings.defaults(userId);
    }

    try {
      final response = await activeClient
          .from('privacy_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // Return and insert defaults
        final defaults = PrivacySettings.defaults(userId);
        try {
          await activeClient.from('privacy_settings').insert(defaults.toJson());
        } catch (_) {}
        return defaults;
      }

      return PrivacySettings.fromJson(response);
    } catch (e) {
      debugPrint('[SupabaseSafetyRepository] Error getting privacy settings: $e');
      return PrivacySettings.defaults(userId);
    }
  }

  @override
  Future<PrivacySettings> updatePrivacySettings(PrivacySettings settings) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      _devPrivacySettings[settings.userId] = settings;
      return settings;
    }

    try {
      final response = await activeClient
          .from('privacy_settings')
          .upsert(settings.toJson())
          .select()
          .single();

      return PrivacySettings.fromJson(response);
    } catch (e) {
      debugPrint('[SupabaseSafetyRepository] Error updating privacy settings: $e');
      throw AppException('Failed to update privacy settings: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // REPORTING & BLOCKING
  // ---------------------------------------------------------------------------

  @override
  Future<SafetyReport> submitReport(SafetyReport report) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      _devReports.add(report);
      return report;
    }

    try {
      final response = await activeClient
          .from('reports')
          .insert(report.toJson())
          .select()
          .single();

      return SafetyReport.fromJson(response);
    } catch (e) {
      debugPrint('[SupabaseSafetyRepository] Error submitting safety report: $e');
      throw AppException('Failed to submit report: $e');
    }
  }

  @override
  Future<void> blockUser({
    required String blockerId,
    required String blockedUserId,
    String? reason,
  }) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      _devBlocks.add('$blockerId:$blockedUserId');
      return;
    }

    try {
      await activeClient.from('blocks').upsert({
        'blocker_id': blockerId,
        'blocked_user_id': blockedUserId,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[SupabaseSafetyRepository] Error blocking user: $e');
      throw AppException('Failed to block user: $e');
    }
  }

  @override
  Future<void> unblockUser({
    required String blockerId,
    required String blockedUserId,
  }) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      _devBlocks.remove('$blockerId:$blockedUserId');
      return;
    }

    try {
      await activeClient
          .from('blocks')
          .delete()
          .eq('blocker_id', blockerId)
          .eq('blocked_user_id', blockedUserId);
    } catch (e) {
      debugPrint('[SupabaseSafetyRepository] Error unblocking user: $e');
      throw AppException('Failed to unblock user: $e');
    }
  }

  @override
  Future<List<String>> getBlockedUserIds(String blockerId) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      return _devBlocks
          .where((k) => k.startsWith('$blockerId:'))
          .map((k) => k.split(':')[1])
          .toList();
    }

    try {
      final response = await activeClient
          .from('blocks')
          .select('blocked_user_id')
          .eq('blocker_id', blockerId);

      return (response as List)
          .map((r) => r['blocked_user_id'] as String)
          .toList();
    } catch (e) {
      debugPrint('[SupabaseSafetyRepository] Error getting blocked users: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // COMPANION REVIEWS & TRUST PROFILE
  // ---------------------------------------------------------------------------

  @override
  Future<CompanionReview> submitCompanionReview(CompanionReview review) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      _devReviews.putIfAbsent(review.revieweeId, () => []).add(review);
      return review;
    }

    try {
      final response = await activeClient
          .from('reviews')
          .insert(review.toJson())
          .select()
          .single();

      return CompanionReview.fromJson(response);
    } catch (e) {
      debugPrint('[SupabaseSafetyRepository] Error submitting companion review: $e');
      throw AppException('Failed to submit review: $e');
    }
  }

  @override
  Future<List<CompanionReview>> getReviewsForUser(String userId) async {
    final activeClient = _activeClient;
    if (activeClient == null) {
      final list = _devReviews[userId] ?? [];
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return List.unmodifiable(list);
    }

    try {
      final response = await activeClient
          .from('reviews')
          .select()
          .eq('reviewee_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((r) => CompanionReview.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SupabaseSafetyRepository] Error getting reviews for user: $e');
      return [];
    }
  }

  @override
  Future<TrustProfile> getTrustProfile(String userId) async {
    final activeClient = _activeClient;

    if (activeClient == null) {
      final reviews = _devReviews[userId] ?? [];
      final hasIdVerification = (_devVerifications[userId] ?? []).any(
        (r) =>
            r.status == VerificationStatus.verified &&
            (r.type == VerificationType.governmentId ||
                r.type == VerificationType.composite),
      );
      final hasPhoneVerification = (_devVerifications[userId] ?? []).any(
        (r) =>
            r.status == VerificationStatus.verified &&
            r.type == VerificationType.phone,
      );

      double avgRating = 5.0;
      if (reviews.isNotEmpty) {
        avgRating = reviews.map((r) => r.overallRating).reduce((a, b) => a + b) /
            reviews.length;
      }

      final breakdown = TrustScoreCalculator.calculateBreakdown(
        profileCompletionPercentage: 85,
        isPhoneVerified: hasPhoneVerification,
        isIdentityVerified: hasIdVerification,
        tripsCompleted: 2,
        averageRating: avgRating,
        reviewCount: reviews.length,
      );

      final badges = <String>[];
      if (hasIdVerification) badges.add('Identity Verified');
      if (hasPhoneVerification) badges.add('Phone Verified');
      badges.add('Active Traveler');

      return TrustProfile(
        userId: userId,
        trustScore: breakdown.totalScore,
        isPhoneVerified: hasPhoneVerification,
        isIdentityVerified: hasIdVerification,
        tripsCompleted: 2,
        reliabilityRating: avgRating,
        reviewCount: reviews.length,
        breakdown: breakdown,
        badges: badges,
        recentReviews: reviews,
      );
    }

    try {
      // Fetch user row
      final userDoc = await activeClient
          .from('users')
          .select('is_verified, is_phone_verified, trips_completed, reliability_rating, completion_percentage')
          .eq('id', userId)
          .maybeSingle();

      final isIdVerified = (userDoc?['is_verified'] as bool?) ?? false;
      final isPhoneVerified = (userDoc?['is_phone_verified'] as bool?) ?? false;
      final tripsCompleted = (userDoc?['trips_completed'] as num?)?.toInt() ?? 0;
      final completionPct = (userDoc?['completion_percentage'] as num?)?.toInt() ?? 80;

      // Fetch reviews
      final reviews = await getReviewsForUser(userId);
      double avgRating = (userDoc?['reliability_rating'] as num?)?.toDouble() ?? 5.0;
      if (reviews.isNotEmpty) {
        avgRating = reviews.map((r) => r.overallRating).reduce((a, b) => a + b) /
            reviews.length;
      }

      final breakdown = TrustScoreCalculator.calculateBreakdown(
        profileCompletionPercentage: completionPct,
        isPhoneVerified: isPhoneVerified,
        isIdentityVerified: isIdVerified,
        tripsCompleted: tripsCompleted,
        averageRating: avgRating,
        reviewCount: reviews.length,
      );

      final badges = <String>[];
      if (isIdVerified) badges.add('Identity Verified');
      if (isPhoneVerified) badges.add('Phone Verified');
      if (tripsCompleted >= 3) badges.add('Experienced Traveler');
      if (avgRating >= 4.5 && reviews.isNotEmpty) badges.add('Highly Rated Companion');

      return TrustProfile(
        userId: userId,
        trustScore: breakdown.totalScore,
        isPhoneVerified: isPhoneVerified,
        isIdentityVerified: isIdVerified,
        tripsCompleted: tripsCompleted,
        reliabilityRating: avgRating,
        reviewCount: reviews.length,
        breakdown: breakdown,
        badges: badges,
        recentReviews: reviews,
      );
    } catch (e) {
      debugPrint('[SupabaseSafetyRepository] Error building trust profile: $e');
      final fallbackBreakdown = TrustScoreCalculator.calculateBreakdown(
        profileCompletionPercentage: 50,
        isPhoneVerified: false,
        isIdentityVerified: false,
        tripsCompleted: 0,
        averageRating: 5.0,
        reviewCount: 0,
      );
      return TrustProfile(
        userId: userId,
        trustScore: fallbackBreakdown.totalScore,
        isPhoneVerified: false,
        isIdentityVerified: false,
        tripsCompleted: 0,
        reliabilityRating: 5.0,
        reviewCount: 0,
        breakdown: fallbackBreakdown,
      );
    }
  }
}
