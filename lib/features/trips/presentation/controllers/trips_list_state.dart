/// Immutable state representing user journey collection and tab filtering.
library;

import '../../domain/models/trip.dart';

enum TripListTab {
  upcoming('Upcoming'),
  drafts('Drafts'),
  past('Past'),
  cancelled('Cancelled');

  final String label;
  const TripListTab(this.label);
}

class TripsListState {
  final List<Trip> trips;
  final TripListTab activeTab;
  TripListTab get currentTab => activeTab;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const TripsListState({
    this.trips = const [],
    this.activeTab = TripListTab.upcoming,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  List<Trip> get upcomingTrips =>
      trips.where((t) => t.isUpcoming).toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));

  List<Trip> get draftTrips =>
      trips.where((t) => t.isDraft).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  List<Trip> get pastTrips =>
      trips.where((t) => t.isPast).toList()
        ..sort((a, b) => b.endDate.compareTo(a.endDate));

  List<Trip> get cancelledTrips =>
      trips.where((t) => t.isCancelled).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  List<Trip> get currentTabTrips {
    switch (activeTab) {
      case TripListTab.upcoming:
        return upcomingTrips;
      case TripListTab.drafts:
        return draftTrips;
      case TripListTab.past:
        return pastTrips;
      case TripListTab.cancelled:
        return cancelledTrips;
    }
  }

  TripsListState copyWith({
    List<Trip>? trips,
    TripListTab? activeTab,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return TripsListState(
      trips: trips ?? this.trips,
      activeTab: activeTab ?? this.activeTab,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}
