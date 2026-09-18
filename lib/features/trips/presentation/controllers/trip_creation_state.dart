/// Immutable state holding trip wizard data, companion criteria, and validation feedback.
library;

import '../../domain/models/trip.dart';
import '../../domain/models/trip_preferences.dart';

class TripCreationState {
  final Trip trip;
  final TripPreferences preferences;
  final int currentStep;
  final bool hasSetDates;
  final bool isLoading;
  final bool isSaving;
  final bool isPublishing;
  final String? errorMessage;
  final String? successMessage;
  final bool isDirty;

  const TripCreationState({
    required this.trip,
    required this.preferences,
    this.currentStep = 0,
    this.hasSetDates = false,
    this.isLoading = false,
    this.isSaving = false,
    this.isPublishing = false,
    this.errorMessage,
    this.successMessage,
    this.isDirty = false,
  });

  factory TripCreationState.initial(String userId) {
    final draftTrip = Trip.newDraft(userId);
    final emptyPrefs = TripPreferences.empty(draftTrip.id);
    return TripCreationState(
      trip: draftTrip,
      preferences: emptyPrefs,
      hasSetDates: false,
    );
  }

  TripCreationState copyWith({
    Trip? trip,
    TripPreferences? preferences,
    int? currentStep,
    bool? hasSetDates,
    bool? isLoading,
    bool? isSaving,
    bool? isPublishing,
    String? errorMessage,
    String? successMessage,
    bool? isDirty,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return TripCreationState(
      trip: trip ?? this.trip,
      preferences: preferences ?? this.preferences,
      currentStep: currentStep ?? this.currentStep,
      hasSetDates: hasSetDates ?? this.hasSetDates,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isPublishing: isPublishing ?? this.isPublishing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      isDirty: isDirty ?? this.isDirty,
    );
  }
}
