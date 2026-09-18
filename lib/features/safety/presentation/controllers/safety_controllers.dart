/// SafeMate Safety & Trust State Management.
/// Universal Engineering Rule #6: Strict domain boundaries.
/// Universal Engineering Rule #11: Safety is a core product capability.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/supabase_safety_repository.dart';
import '../../domain/models/privacy_settings.dart';
import '../../domain/models/report_models.dart';
import '../../domain/models/safety_contact.dart';
import '../../domain/models/trust_models.dart';
import '../../domain/models/verification_models.dart';
import '../../domain/repositories/safety_repository.dart';

/// Provider for SafetyRepository.
final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  return SupabaseSafetyRepository();
});

// =============================================================================
// 1. VERIFICATION CONTROLLER
// =============================================================================

class VerificationState {
  final VerificationRecord? phoneVerification;
  final VerificationRecord? identityVerification;
  final List<VerificationRecord> history;
  final bool isLoading;
  final String? errorMessage;

  const VerificationState({
    this.phoneVerification,
    this.identityVerification,
    this.history = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  VerificationState copyWith({
    VerificationRecord? phoneVerification,
    VerificationRecord? identityVerification,
    List<VerificationRecord>? history,
    bool? isLoading,
    String? errorMessage,
  }) {
    return VerificationState(
      phoneVerification: phoneVerification ?? this.phoneVerification,
      identityVerification: identityVerification ?? this.identityVerification,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class VerificationController extends StateNotifier<VerificationState> {
  final SafetyRepository repository;
  final AnalyticsService analytics;
  final String? userId;

  VerificationController({
    required this.repository,
    required this.analytics,
    required this.userId,
  }) : super(const VerificationState()) {
    if (userId != null) {
      loadStatus();
    }
  }

  Future<void> loadStatus() async {
    final uid = userId;
    if (uid == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final phone = await repository.getLatestVerification(uid, VerificationType.phone);
      final idVer = await repository.getLatestVerification(uid, VerificationType.governmentId) ??
          await repository.getLatestVerification(uid, VerificationType.composite);
      final history = await repository.getVerificationHistory(uid);

      state = state.copyWith(
        phoneVerification: phone,
        identityVerification: idVer,
        history: history,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load verification status: $e',
      );
    }
  }

  Future<VerificationRecord?> startVerification(VerificationType type) async {
    final uid = userId;
    if (uid == null) return null;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await analytics.logEvent('verification_started', parameters: {
        'verification_type': type.toDbValue(),
      });

      final record = await repository.requestVerification(
        userId: uid,
        type: type,
        provider: 'SafeMate Trust Shield',
      );

      await loadStatus();
      return record;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Verification request failed: $e',
      );
      return null;
    }
  }

  Future<bool> completeVerification({
    required String recordId,
    required bool approved,
    String? failureReason,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await repository.submitVerification(
        recordId: recordId,
        approved: approved,
        failureReason: failureReason,
      );

      await analytics.logEvent('verification_completed', parameters: {
        'record_id': recordId,
        'approved': approved,
      });

      await loadStatus();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to complete verification: $e',
      );
      return false;
    }
  }
}

final verificationControllerProvider =
    StateNotifierProvider<VerificationController, VerificationState>((ref) {
  final repo = ref.watch(safetyRepositoryProvider);
  final analytics = ref.watch(analyticsServiceProvider);
  final authState = ref.watch(authControllerProvider);
  final userId = authState.profile?.id ?? authState.session?.userId;

  return VerificationController(
    repository: repo,
    analytics: analytics,
    userId: userId,
  );
});

// =============================================================================
// 2. TRUSTED CONTACTS CONTROLLER
// =============================================================================

class TrustedContactsState {
  final List<SafetyContact> contacts;
  final bool isLoading;
  final String? errorMessage;

  const TrustedContactsState({
    this.contacts = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  TrustedContactsState copyWith({
    List<SafetyContact>? contacts,
    bool? isLoading,
    String? errorMessage,
  }) {
    return TrustedContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class TrustedContactsController extends StateNotifier<TrustedContactsState> {
  final SafetyRepository repository;
  final AnalyticsService analytics;
  final String? userId;

  TrustedContactsController({
    required this.repository,
    required this.analytics,
    required this.userId,
  }) : super(const TrustedContactsState()) {
    if (userId != null) {
      loadContacts();
    }
  }

  Future<void> loadContacts() async {
    final uid = userId;
    if (uid == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await repository.getSafetyContacts(uid);
      state = state.copyWith(contacts: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load safety contacts: $e',
      );
    }
  }

  Future<bool> addContact({
    required String contactName,
    required String phoneNumber,
    String? email,
    required String relationship,
    bool notifyOnTripStart = true,
  }) async {
    final uid = userId;
    if (uid == null) return false;

    // Strict rule: maximum 5 trusted contacts per traveler
    if (state.contacts.length >= 5) {
      state = state.copyWith(
        errorMessage: 'Maximum of 5 trusted safety contacts allowed.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final newContact = SafetyContact(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: uid,
        contactName: contactName.trim(),
        phoneNumber: phoneNumber.trim(),
        email: email?.trim(),
        relationship: relationship.trim(),
        notifyOnTripStart: notifyOnTripStart,
        createdAt: DateTime.now(),
      );

      await repository.addSafetyContact(newContact);
      await analytics.logEvent('safety_contact_added');
      await loadContacts();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to add safety contact: $e',
      );
      return false;
    }
  }

  Future<bool> updateContact(SafetyContact contact) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await repository.updateSafetyContact(contact);
      await loadContacts();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update safety contact: $e',
      );
      return false;
    }
  }

  Future<bool> deleteContact(String contactId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await repository.deleteSafetyContact(contactId);
      await analytics.logEvent('safety_contact_removed');
      await loadContacts();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to delete safety contact: $e',
      );
      return false;
    }
  }
}

final trustedContactsControllerProvider =
    StateNotifierProvider<TrustedContactsController, TrustedContactsState>((ref) {
  final repo = ref.watch(safetyRepositoryProvider);
  final analytics = ref.watch(analyticsServiceProvider);
  final authState = ref.watch(authControllerProvider);
  final userId = authState.profile?.id ?? authState.session?.userId;

  return TrustedContactsController(
    repository: repo,
    analytics: analytics,
    userId: userId,
  );
});

// =============================================================================
// 3. PRIVACY SETTINGS CONTROLLER
// =============================================================================

class PrivacySettingsController extends StateNotifier<AsyncValue<PrivacySettings>> {
  final SafetyRepository repository;
  final AnalyticsService analytics;
  final String? userId;

  PrivacySettingsController({
    required this.repository,
    required this.analytics,
    required this.userId,
  }) : super(const AsyncValue.loading()) {
    if (userId != null) {
      loadSettings();
    }
  }

  Future<void> loadSettings() async {
    final uid = userId;
    if (uid == null) return;

    state = const AsyncValue.loading();
    try {
      final settings = await repository.getPrivacySettings(uid);
      state = AsyncValue.data(settings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> updateSettings(PrivacySettings newSettings) async {
    try {
      final updated = await repository.updatePrivacySettings(newSettings);
      state = AsyncValue.data(updated);
      await analytics.logEvent('privacy_settings_updated');
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final privacySettingsControllerProvider =
    StateNotifierProvider<PrivacySettingsController, AsyncValue<PrivacySettings>>((ref) {
  final repo = ref.watch(safetyRepositoryProvider);
  final analytics = ref.watch(analyticsServiceProvider);
  final authState = ref.watch(authControllerProvider);
  final userId = authState.profile?.id ?? authState.session?.userId;

  return PrivacySettingsController(
    repository: repo,
    analytics: analytics,
    userId: userId,
  );
});

// =============================================================================
// 4. TRUST PROFILE PROVIDER
// =============================================================================

final trustProfileProvider = FutureProvider.family<TrustProfile, String>((ref, userId) async {
  final repo = ref.watch(safetyRepositoryProvider);
  return repo.getTrustProfile(userId);
});

// =============================================================================
// 5. SAFETY REPORTING & BLOCKING CONTROLLER
// =============================================================================

class ReportController extends StateNotifier<AsyncValue<void>> {
  final SafetyRepository repository;
  final AnalyticsService analytics;

  ReportController({
    required this.repository,
    required this.analytics,
  }) : super(const AsyncValue.data(null));

  Future<bool> submitReport({
    required String reporterId,
    required String reportedUserId,
    required ReportCategory category,
    required String description,
    String contextType = 'profile',
    String? contextId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final report = SafetyReport(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        reporterId: reporterId,
        reportedUserId: reportedUserId,
        category: category,
        description: description,
        contextType: contextType,
        contextId: contextId,
        createdAt: DateTime.now(),
      );

      await repository.submitReport(report);
      await analytics.logEvent('safety_report_submitted', parameters: {
        'category': category.toDbValue(),
        'context_type': contextType,
      });

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> blockUser({
    required String blockerId,
    required String targetUserId,
    String? reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      await repository.blockUser(
        blockerId: blockerId,
        blockedUserId: targetUserId,
        reason: reason,
      );
      await analytics.logEvent('user_blocked');
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> unblockUser({
    required String blockerId,
    required String targetUserId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await repository.unblockUser(
        blockerId: blockerId,
        blockedUserId: targetUserId,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final reportControllerProvider =
    StateNotifierProvider<ReportController, AsyncValue<void>>((ref) {
  final repo = ref.watch(safetyRepositoryProvider);
  final analytics = ref.watch(analyticsServiceProvider);

  return ReportController(repository: repo, analytics: analytics);
});

// =============================================================================
// 6. COMPANION REVIEW CONTROLLER
// =============================================================================

class CompanionReviewController extends StateNotifier<AsyncValue<void>> {
  final SafetyRepository repository;
  final AnalyticsService analytics;

  CompanionReviewController({
    required this.repository,
    required this.analytics,
  }) : super(const AsyncValue.data(null));

  Future<bool> submitReview({
    required String tripId,
    required String reviewerId,
    required String revieweeId,
    required int communicationRating,
    required int punctualityRating,
    required int respectRating,
    required int planningRating,
    String? comment,
  }) async {
    state = const AsyncValue.loading();
    try {
      final review = CompanionReview(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        tripId: tripId,
        reviewerId: reviewerId,
        revieweeId: revieweeId,
        communicationRating: communicationRating,
        punctualityRating: punctualityRating,
        respectRating: respectRating,
        planningRating: planningRating,
        overallRating: (communicationRating + punctualityRating + respectRating + planningRating) / 4.0,
        comment: comment,
        createdAt: DateTime.now(),
      );

      await repository.submitCompanionReview(review);
      await analytics.logEvent('companion_review_submitted', parameters: {
        'trip_id': tripId,
        'overall_rating': review.overallRating,
      });

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final companionReviewControllerProvider =
    StateNotifierProvider<CompanionReviewController, AsyncValue<void>>((ref) {
  final repo = ref.watch(safetyRepositoryProvider);
  final analytics = ref.watch(analyticsServiceProvider);

  return CompanionReviewController(repository: repo, analytics: analytics);
});
