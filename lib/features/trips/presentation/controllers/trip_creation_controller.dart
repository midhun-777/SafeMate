/// Controller managing multi-step trip creation, companion preferences, and draft autosaving.
/// Universal Engineering Rule #11: Deterministic state machine.
/// Universal Engineering Rule #13: Calm, visual, one meaningful concept at a time.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safemate/core/errors/app_exception.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:safemate/features/profile/domain/models/travel_personality.dart';
import 'package:safemate/features/profile/domain/models/travel_preferences.dart';
import '../../data/repositories/supabase_trip_repository.dart';
import '../../domain/models/trip_budget.dart';
import '../../domain/models/trip_preferences.dart';
import '../../domain/models/trip_purpose.dart';
import '../../domain/models/trip_status.dart';
import '../../domain/models/trip_transport.dart';
import '../../domain/models/trip_visibility.dart';
import '../../domain/repositories/trip_repository.dart';
import 'trip_creation_state.dart';

/// Provider for TripRepository.
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return SupabaseTripRepository();
});

/// Riverpod StateNotifierProvider for TripCreationController.
final tripCreationControllerProvider =
    StateNotifierProvider<TripCreationController, TripCreationState>((ref) {
  final repository = ref.watch(tripRepositoryProvider);
  final authState = ref.watch(authControllerProvider);
  final userId = authState.session?.userId ?? 'dev_user_placeholder';
  return TripCreationController(repository, userId);
});

class TripCreationController extends StateNotifier<TripCreationState> {
  final TripRepository _repository;
  final String _userId;
  final Future<void> Function()? onTripSaved;

  TripCreationController(
    this._repository,
    this._userId, {
    this.onTripSaved,
  }) : super(TripCreationState.initial(_userId));

  void reset() {
    state = TripCreationState.initial(_userId);
  }

  Future<void> loadTrip(String tripId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final trip = await _repository.getTrip(tripId);
      if (trip != null) {
        state = state.copyWith(
          trip: trip,
          preferences: trip.preferences ?? TripPreferences.empty(trip.id),
          hasSetDates: true,
          isLoading: false,
          isDirty: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Journey not found.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load journey details.',
      );
    }
  }

  // --- Step 0: Origin & Destination ---

  void setOrigin(String origin, {String? city, String? country}) {
    state = state.copyWith(
      trip: state.trip.copyWith(
        origin: origin,
        originCity: city ?? origin.split(',').first.trim(),
        originCountry: country,
      ),
      isDirty: true,
      clearError: true,
    );
  }

  void setDestination(String destination, {String? city, String? country}) {
    final destCity = city ?? destination.split(',').first.trim();
    state = state.copyWith(
      trip: state.trip.copyWith(
        destination: destination,
        destinationCity: destCity,
        destinationCountry: country,
        title: state.trip.title.isEmpty ? 'Trip to $destCity' : state.trip.title,
      ),
      isDirty: true,
      clearError: true,
    );
  }

  void setTitle(String title) {
    state = state.copyWith(
      trip: state.trip.copyWith(title: title),
      isDirty: true,
    );
  }

  // --- Step 1: Dates ---

  void setDateRange(DateTime start, DateTime end) {
    state = state.copyWith(
      trip: state.trip.copyWith(startDate: start, endDate: end),
      hasSetDates: true,
      isDirty: true,
      clearError: true,
    );
  }

  // --- Step 2: Transport & Budget ---

  void setTransportMode(TripTransport mode) {
    state = state.copyWith(
      trip: state.trip.copyWith(transportMode: mode),
      isDirty: true,
    );
  }

  void setBudgetTier(TripBudgetTier tier) {
    state = state.copyWith(
      trip: state.trip.copyWith(budgetTier: tier),
      isDirty: true,
    );
  }

  void setEstimatedBudget(double? budget) {
    state = state.copyWith(
      trip: state.trip.copyWith(estimatedBudget: budget),
      isDirty: true,
    );
  }

  // --- Step 3: Trip Style & Purpose ---

  void setTripPurpose(TripPurpose purpose) {
    state = state.copyWith(
      trip: state.trip.copyWith(tripPurpose: purpose),
      isDirty: true,
    );
  }

  void toggleTripStyle(String styleCode) {
    final current = List<String>.from(state.trip.tripStyles);
    if (current.contains(styleCode)) {
      current.remove(styleCode);
    } else {
      current.add(styleCode);
    }
    state = state.copyWith(
      trip: state.trip.copyWith(tripStyles: current),
      isDirty: true,
    );
  }

  // --- Step 4: Companion Preferences ---

  void setCompanionPace(TravelPace pace) {
    state = state.copyWith(
      preferences: state.preferences.copyWith(travelPace: pace),
      isDirty: true,
    );
  }

  void setCompanionBudget(TripBudgetTier tier) {
    state = state.copyWith(
      preferences: state.preferences.copyWith(budgetTier: tier),
      isDirty: true,
    );
  }

  void setCompanionAccommodation(AccommodationStyle acc) {
    state = state.copyWith(
      preferences: state.preferences.copyWith(accommodationPreference: acc),
      isDirty: true,
    );
  }

  void setCompanionSocial(SocialPreference social) {
    state = state.copyWith(
      preferences: state.preferences.copyWith(socialEnergy: social),
      isDirty: true,
    );
  }

  void toggleCompanionTransport(String transport) {
    final current = List<String>.from(state.preferences.preferredTransport);
    if (current.contains(transport)) {
      current.remove(transport);
    } else {
      current.add(transport);
    }
    state = state.copyWith(
      preferences: state.preferences.copyWith(preferredTransport: current),
      isDirty: true,
    );
  }

  void toggleCompanionActivity(String activity) {
    final current = List<String>.from(state.preferences.activityInterests);
    if (current.contains(activity)) {
      current.remove(activity);
    } else {
      current.add(activity);
    }
    state = state.copyWith(
      preferences: state.preferences.copyWith(activityInterests: current),
      isDirty: true,
    );
  }

  void toggleCompanionDiet(String diet) {
    final current = List<String>.from(state.preferences.dietaryPreferences);
    if (current.contains(diet)) {
      current.remove(diet);
    } else {
      current.add(diet);
    }
    state = state.copyWith(
      preferences: state.preferences.copyWith(dietaryPreferences: current),
      isDirty: true,
    );
  }

  void setCompanionSchedule(ScheduleStyle schedule) {
    state = state.copyWith(
      preferences: state.preferences.copyWith(schedulePreference: schedule),
      isDirty: true,
    );
  }

  void setCompanionGender(String gender) {
    state = state.copyWith(
      preferences: state.preferences.copyWith(preferredGender: gender),
      isDirty: true,
    );
  }

  void setCompanionAgeRange(int? min, int? max) {
    state = state.copyWith(
      preferences: state.preferences.copyWith(ageMin: min, ageMax: max),
      isDirty: true,
    );
  }

  void setCompanionNotes(String notes) {
    state = state.copyWith(
      preferences: state.preferences.copyWith(notes: notes),
      isDirty: true,
    );
  }

  // --- Step 5: Privacy & Visibility ---

  void setVisibility(TripVisibility visibility) {
    state = state.copyWith(
      trip: state.trip.copyWith(visibility: visibility),
      isDirty: true,
    );
  }

  void setMaxCompanions(int count) {
    state = state.copyWith(
      trip: state.trip.copyWith(maxCompanions: count),
      isDirty: true,
    );
  }

  // --- Wizard Step Navigation ---

  bool validateCurrentStep() {
    switch (state.currentStep) {
      case 0:
        if (state.trip.destination.trim().isEmpty) {
          state = state.copyWith(errorMessage: 'Please enter a destination.');
          return false;
        }
        if (state.trip.origin.trim().isEmpty) {
          state = state.copyWith(errorMessage: 'Please enter your starting location.');
          return false;
        }
        return true;
      case 1:
        if (!state.hasSetDates) {
          state = state.copyWith(errorMessage: 'Please select your journey dates.');
          return false;
        }
        if (state.trip.endDate.isBefore(state.trip.startDate)) {
          state = state.copyWith(errorMessage: 'End date cannot be before start date.');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  bool nextStep() {
    if (!validateCurrentStep()) return false;
    if (state.currentStep < 6) {
      state = state.copyWith(
        currentStep: state.currentStep + 1,
        clearError: true,
      );
      return true;
    }
    return false;
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(
        currentStep: state.currentStep - 1,
        clearError: true,
      );
    }
  }

  void setStep(int step) {
    if (step >= 0 && step <= 6) {
      state = state.copyWith(currentStep: step, clearError: true);
    }
  }

  // --- Draft Saving & Publishing ---

  Future<bool> saveDraft() async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final saved = await _repository.saveDraft(
        state.trip.copyWith(status: TripStatus.draft),
        preferences: state.preferences,
      );
      state = state.copyWith(
        trip: saved,
        preferences: saved.preferences ?? state.preferences,
        isSaving: false,
        isDirty: false,
        successMessage: 'Journey draft saved safely.',
      );
      await onTripSaved?.call();
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save draft. Please check your connection.',
      );
      return false;
    }
  }

  Future<bool> publishTrip() async {
    final validationErrors = state.trip.validate(isPublishing: true);
    if (validationErrors.isNotEmpty) {
      state = state.copyWith(errorMessage: validationErrors.first);
      return false;
    }

    state = state.copyWith(isPublishing: true, clearError: true);
    try {
      final publishedTrip = state.trip.copyWith(
        status: TripStatus.published,
        title: state.trip.title.trim().isNotEmpty
            ? state.trip.title.trim()
            : 'Trip to ${state.trip.destination}',
      );

      final saved = state.trip.id.isEmpty
          ? await _repository.createTrip(publishedTrip, preferences: state.preferences)
          : await _repository.updateTrip(publishedTrip, preferences: state.preferences);

      state = state.copyWith(
        trip: saved,
        preferences: saved.preferences ?? state.preferences,
        isPublishing: false,
        isDirty: false,
        successMessage: 'Journey published! Now discoverable for companion matching.',
      );
      await onTripSaved?.call();
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isPublishing: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isPublishing: false,
        errorMessage: 'Failed to publish journey. Please check your connection.',
      );
      return false;
    }
  }

  void clearMessage() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

