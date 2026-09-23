import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safemate/core/errors/app_exception.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_controller.dart';
import '../../../../core/sync/conflict_resolution_controller.dart' show localDatabaseServiceProvider;
import '../../../../core/sync/sync_engine.dart' show syncEngineProvider;
import '../../data/repositories/offline_first_profile_repository.dart';
import '../../data/repositories/supabase_profile_repository.dart';
import '../../domain/models/profile_completion.dart';
import '../../domain/models/profile_visibility.dart';
import '../../domain/models/travel_personality.dart';
import '../../domain/models/travel_preferences.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_state.dart';

/// Provider for ProfileRepository.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final localDb = ref.watch(localDatabaseServiceProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return OfflineFirstProfileRepository(
    remoteRepo: SupabaseProfileRepository(),
    localDb: localDb,
    syncEngine: syncEngine,
  );
});

/// Riverpod StateNotifierProvider for ProfileController.
final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  final authState = ref.watch(authControllerProvider);
  final userId = authState.session?.userId ?? '';
  return ProfileController(
    repository,
    userId,
    onProfileSaved: () async {
      await ref.read(authControllerProvider.notifier).refreshProfile();
    },
  );
});

/// ProfileController coordinates the multi-step profile wizard, draft auto-saving,
/// and deterministic completion score calculation.
class ProfileController extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;
  final String _userId;
  final Future<void> Function()? onProfileSaved;

  ProfileController(
    this._repository,
    this._userId, {
    this.onProfileSaved,
  }) : super(ProfileState.initial(_userId)) {
    if (_userId.isNotEmpty) {
      loadProfile();
    }
  }

  /// Loads current user profile and travel preferences from storage.
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final profile = await _repository.getProfile(_userId);
      final preferences = await _repository.getTravelPreferences(_userId);

      final safeProfile = profile ??
          UserProfile(
            id: _userId,
            displayName: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      final safePreferences = preferences ?? TravelPreferences.empty(_userId);

      final completion = ProfileCompletion.calculate(
        profile: safeProfile,
        preferences: safePreferences,
      );

      state = state.copyWith(
        profile: safeProfile.copyWith(completionPercentage: completion.percentage),
        preferences: safePreferences,
        completion: completion,
        isLoading: false,
        isDirty: false,
      );
    } catch (e) {
      debugPrint('[ProfileController] Error loading profile: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load profile data. Please try again.',
      );
    }
  }

  void _recalculateCompletion() {
    final completion = ProfileCompletion.calculate(
      profile: state.profile,
      preferences: state.preferences,
    );
    state = state.copyWith(
      completion: completion,
      profile: state.profile.copyWith(completionPercentage: completion.percentage),
      isDirty: true,
      errorMessage: null,
    );
  }

  // --- Step 1: Basic Identity Updates ---

  void setDisplayName(String name) {
    state = state.copyWith(
      profile: state.profile.copyWith(displayName: name.trim()),
    );
    _recalculateCompletion();
  }

  void setBio(String bio) {
    state = state.copyWith(
      profile: state.profile.copyWith(bio: bio.trim()),
    );
    _recalculateCompletion();
  }

  void setHomeCity(String city) {
    state = state.copyWith(
      profile: state.profile.copyWith(homeCity: city.trim()),
    );
    _recalculateCompletion();
  }

  void toggleLanguage(String language) {
    final current = List<String>.from(state.profile.languages);
    if (current.contains(language)) {
      current.remove(language);
    } else {
      current.add(language);
    }
    state = state.copyWith(
      profile: state.profile.copyWith(languages: current),
    );
    _recalculateCompletion();
  }

  // --- Step 2: Travel Personality Updates ---

  void toggleTravelStyle(String style) {
    final current = List<String>.from(state.profile.travelStyles);
    if (current.contains(style)) {
      current.remove(style);
    } else {
      current.add(style);
    }
    state = state.copyWith(
      profile: state.profile.copyWith(travelStyles: current),
    );
    _recalculateCompletion();
  }

  void setTravelPace(TravelPace pace) {
    state = state.copyWith(
      preferences: state.preferences.copyWith(travelPace: pace),
    );
    _recalculateCompletion();
  }

  void setScheduleStyle(ScheduleStyle schedule) {
    state = state.copyWith(
      preferences: state.preferences.copyWith(schedulePreference: schedule),
    );
    _recalculateCompletion();
  }

  void setPlanningStyle(PlanningStyle planning) {
    state = state.copyWith(
      preferences: state.preferences.copyWith(planningStyle: planning),
    );
    _recalculateCompletion();
  }

  // --- Step 3: Travel Preferences Updates ---

  void setBudgetTier(BudgetTier budget) {
    state = state.copyWith(
      preferences: state.preferences.copyWith(budgetTier: budget),
    );
    _recalculateCompletion();
  }

  void setAccommodation(AccommodationStyle style) {
    state = state.copyWith(
      preferences: state.preferences.copyWith(accommodationPreference: style),
    );
    _recalculateCompletion();
  }

  void setSocialEnergy(SocialPreference social) {
    state = state.copyWith(
      preferences: state.preferences.copyWith(socialEnergy: social),
    );
    _recalculateCompletion();
  }

  void toggleTransport(String transport) {
    final current = List<String>.from(state.preferences.preferredTransport);
    if (current.contains(transport)) {
      current.remove(transport);
    } else {
      current.add(transport);
    }
    state = state.copyWith(
      preferences: state.preferences.copyWith(preferredTransport: current),
    );
    _recalculateCompletion();
  }

  void toggleDietary(String diet) {
    final current = List<String>.from(state.preferences.dietaryPreferences);
    if (current.contains(diet)) {
      current.remove(diet);
    } else {
      current.add(diet);
    }
    state = state.copyWith(
      preferences: state.preferences.copyWith(dietaryPreferences: current),
    );
    _recalculateCompletion();
  }

  void toggleActivityInterest(String interest) {
    final current = List<String>.from(state.preferences.activityInterests);
    if (current.contains(interest)) {
      current.remove(interest);
    } else {
      current.add(interest);
    }
    state = state.copyWith(
      preferences: state.preferences.copyWith(activityInterests: current),
    );
    _recalculateCompletion();
  }

  // --- Step 4: Privacy Settings ---

  void setVisibility(ProfileVisibility visibility) {
    state = state.copyWith(
      profile: state.profile.copyWith(visibility: visibility),
      isDirty: true,
    );
  }

  // --- Photo Upload & Removal ---

  Future<bool> uploadProfilePhoto({
    required List<int> bytes,
    required String filename,
  }) async {
    state = state.copyWith(isUploadingPhoto: true, errorMessage: null);
    try {
      final url = await _repository.uploadProfilePhoto(
        userId: _userId,
        bytes: bytes,
        filename: filename,
      );
      state = state.copyWith(
        profile: state.profile.copyWith(avatarUrl: url),
        isUploadingPhoto: false,
      );
      _recalculateCompletion();
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        isUploadingPhoto: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isUploadingPhoto: false,
        errorMessage: 'Failed to upload photo. Please check image size and format.',
      );
      return false;
    }
  }

  Future<void> removeProfilePhoto() async {
    state = state.copyWith(isUploadingPhoto: true, errorMessage: null);
    try {
      await _repository.deleteProfilePhoto(_userId);
      state = state.copyWith(
        profile: state.profile.copyWith(avatarUrl: ''),
        isUploadingPhoto: false,
      );
      _recalculateCompletion();
    } catch (e) {
      debugPrint('[ProfileController] Error deleting photo: $e');
      state = state.copyWith(isUploadingPhoto: false);
    }
  }

  // --- Wizard Navigation ---

  void setStep(int step) {
    state = state.copyWith(currentStep: step, errorMessage: null);
  }

  void nextStep() {
    if (state.currentStep < 4) {
      state = state.copyWith(
        currentStep: state.currentStep + 1,
        errorMessage: null,
      );
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(
        currentStep: state.currentStep - 1,
        errorMessage: null,
      );
    }
  }

  // --- Persistence & Completion ---

  Future<bool> saveDraft() async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await _repository.saveProfile(state.profile);
      await _repository.saveTravelPreferences(state.preferences);
      state = state.copyWith(
        isSaving: false,
        isDirty: false,
        successMessage: 'Profile draft saved safely.',
      );
      // Refresh AuthController state so AppRouter reflects updated profile
      await onProfileSaved?.call();
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save profile. Please check your connection.',
      );
      return false;
    }
  }

  Future<bool> completeProfileSetup() async {
    // Validate required minimum
    if (!state.completion.isMinimalComplete) {
      state = state.copyWith(
        errorMessage: 'Please provide a display name before completing profile setup.',
      );
      return false;
    }

    final success = await saveDraft();
    return success;
  }

  void clearMessage() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }
}
