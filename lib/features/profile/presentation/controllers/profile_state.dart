import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/profile/domain/models/profile_completion.dart';
import 'package:safemate/features/profile/domain/models/travel_preferences.dart';

/// Immutable state holding profile wizard data, preferences, and completion calculations.
class ProfileState {
  final UserProfile profile;
  final TravelPreferences preferences;
  final ProfileCompletion completion;
  final bool isLoading;
  final bool isSaving;
  final bool isUploadingPhoto;
  final String? errorMessage;
  final String? successMessage;
  final int currentStep;
  final bool isDirty;

  const ProfileState({
    required this.profile,
    required this.preferences,
    required this.completion,
    this.isLoading = false,
    this.isSaving = false,
    this.isUploadingPhoto = false,
    this.errorMessage,
    this.successMessage,
    this.currentStep = 0,
    this.isDirty = false,
  });

  factory ProfileState.initial(String userId) {
    final now = DateTime.now();
    final emptyProfile = UserProfile(
      id: userId,
      displayName: '',
      createdAt: now,
      updatedAt: now,
    );
    final emptyPreferences = TravelPreferences.empty(userId);
    final completion = ProfileCompletion.calculate(
      profile: emptyProfile,
      preferences: emptyPreferences,
    );

    return ProfileState(
      profile: emptyProfile,
      preferences: emptyPreferences,
      completion: completion,
      isLoading: true,
    );
  }

  ProfileState copyWith({
    UserProfile? profile,
    TravelPreferences? preferences,
    ProfileCompletion? completion,
    bool? isLoading,
    bool? isSaving,
    bool? isUploadingPhoto,
    String? errorMessage,
    String? successMessage,
    int? currentStep,
    bool? isDirty,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      preferences: preferences ?? this.preferences,
      completion: completion ?? this.completion,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isUploadingPhoto: isUploadingPhoto ?? this.isUploadingPhoto,
      errorMessage: errorMessage,
      successMessage: successMessage,
      currentStep: currentStep ?? this.currentStep,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}
