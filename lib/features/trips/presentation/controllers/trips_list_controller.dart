/// Controller managing user's journey list, tab filtering, and direct lifecycle actions.
/// Universal Engineering Rule #11: Deterministic state machine and safe cancellation.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safemate/core/errors/app_exception.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_controller.dart';
import '../../domain/models/trip_status.dart';
import '../../domain/repositories/trip_repository.dart';
import 'trip_creation_controller.dart';
import 'trips_list_state.dart';

/// Riverpod StateNotifierProvider for TripsListController.
final tripsListControllerProvider =
    StateNotifierProvider<TripsListController, TripsListState>((ref) {
  final repository = ref.watch(tripRepositoryProvider);
  final authState = ref.watch(authControllerProvider);
  final userId = authState.session?.userId ?? 'dev_user_placeholder';
  return TripsListController(repository, userId);
});

class TripsListController extends StateNotifier<TripsListState> {
  final TripRepository _repository;
  final String _userId;

  TripsListController(this._repository, this._userId)
      : super(const TripsListState()) {
    if (_userId.isNotEmpty) {
      loadTrips();
    }
  }

  void setTab(TripListTab tab) {
    state = state.copyWith(activeTab: tab, clearError: true, clearSuccess: true);
  }

  Future<void> loadTrips() async {
    if (_userId.isEmpty) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final trips = await _repository.getUserTrips(_userId);
      state = state.copyWith(
        trips: trips,
        isLoading: false,
      );
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load journeys. Please check your connection.',
      );
    }
  }

  Future<bool> pauseTrip(String tripId) async {
    return _transitionStatus(tripId, TripStatus.paused, 'Journey paused.');
  }

  Future<bool> resumeTrip(String tripId) async {
    return _transitionStatus(
      tripId,
      TripStatus.published,
      'Journey resumed and discoverable for companion matching.',
    );
  }

  Future<bool> cancelTrip(String tripId, {String? reason}) async {
    return _transitionStatus(
      tripId,
      TripStatus.cancelled,
      'Journey cancelled safely. Historical record preserved.',
      reason: reason,
    );
  }

  Future<bool> completeTrip(String tripId) async {
    return _transitionStatus(
      tripId,
      TripStatus.completed,
      'Congratulations on completing your journey!',
    );
  }

  Future<bool> deleteDraft(String tripId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.deleteDraftTrip(tripId: tripId, userId: _userId);
      final updatedTrips = state.trips.where((t) => t.id != tripId).toList();
      state = state.copyWith(
        trips: updatedTrips,
        isLoading: false,
        successMessage: 'Draft journey deleted.',
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to delete draft.',
      );
      return false;
    }
  }

  Future<bool> _transitionStatus(
    String tripId,
    TripStatus targetStatus,
    String successMsg, {
    String? reason,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _repository.transitionTripStatus(
        tripId: tripId,
        userId: _userId,
        newStatus: targetStatus,
        reason: reason,
      );

      final updatedTrips = state.trips.map((t) {
        return t.id == updated.id ? updated : t;
      }).toList();

      state = state.copyWith(
        trips: updatedTrips,
        isLoading: false,
        successMessage: successMsg,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update journey status.',
      );
      return false;
    }
  }

  void clearMessage() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}
