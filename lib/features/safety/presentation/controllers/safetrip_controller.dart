import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../trips/domain/models/trip.dart';
import '../../data/repositories/supabase_safetrip_repository.dart';
import '../../domain/models/safetrip_models.dart';
import '../../domain/repositories/safetrip_repository.dart';

/// Provider for SafeTripRepository.
final safeTripRepositoryProvider = Provider<SafeTripRepository>((ref) {
  return SupabaseSafeTripRepository();
});

class SafeTripState {
  final SafeTrip? currentTrip;
  final List<JourneyCheckin> checkins;
  final LocationShareSession? activeLocationSession;
  final List<Map<String, dynamic>> events;
  final bool isLoading;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const SafeTripState({
    this.currentTrip,
    this.checkins = const [],
    this.activeLocationSession,
    this.events = const [],
    this.isLoading = false,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  SafeTripState copyWith({
    SafeTrip? currentTrip,
    List<JourneyCheckin>? checkins,
    LocationShareSession? activeLocationSession,
    List<Map<String, dynamic>>? events,
    bool? isLoading,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return SafeTripState(
      currentTrip: currentTrip ?? this.currentTrip,
      checkins: checkins ?? this.checkins,
      activeLocationSession:
          activeLocationSession ?? this.activeLocationSession,
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }
}

class SafeTripController extends StateNotifier<SafeTripState> {
  final SafeTripRepository repository;
  final Ref ref;
  final _uuid = const Uuid();
  StreamSubscription<SafeTrip>? _streamSub;

  SafeTripController({required this.repository, required this.ref})
      : super(const SafeTripState());

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  String get _currentUserId {
    final authState = ref.read(authControllerProvider);
    return authState.profile?.id ?? authState.session?.userId ?? '';
  }

  /// Loads or initializes a SafeTrip for a given [trip].
  Future<void> loadOrCreateSafeTripForTrip({
    required Trip trip,
    String? companionUserId,
    String? trustedContactId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      var safeTrip = await repository.getSafeTripByTripId(trip.id);

      if (safeTrip == null) {
        // Pre-create in PREPARING status
        final now = DateTime.now();
        safeTrip = SafeTrip(
          id: _uuid.v4(),
          tripId: trip.id,
          ownerId: _currentUserId,
          companionUserId: companionUserId,
          trustedContactId: trustedContactId,
          status: SafeTripStatus.preparing,
          expectedStartTime: trip.startDate,
          expectedArrivalTime: trip.endDate,
          checkinIntervalMinutes: 60,
          gracePeriodMinutes: 15,
          locationSharingMode: LocationSharingMode.off,
          createdAt: now,
          updatedAt: now,
        );
        safeTrip = await repository.prepareSafeTrip(safeTrip);
      }

      await _subscribeAndLoad(safeTrip.id);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load SafeTrip: $e',
      );
    }
  }

  /// Loads an existing SafeTrip by its [journeyId].
  Future<void> loadSafeTrip(String journeyId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _subscribeAndLoad(journeyId);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load SafeTrip: $e',
      );
    }
  }

  Future<void> _subscribeAndLoad(String journeyId) async {
    final trip = await repository.getSafeTripById(journeyId);
    if (trip == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'SafeTrip not found',
      );
      return;
    }

    final checkins = await repository.getCheckins(journeyId);
    final activeLoc = await repository.getActiveLocationSession(journeyId);
    final events = await repository.getJourneyEvents(journeyId);

    state = state.copyWith(
      currentTrip: trip,
      checkins: checkins,
      activeLocationSession: activeLoc,
      events: events,
      isLoading: false,
    );

    // Watch realtime changes
    _streamSub?.cancel();
    _streamSub = repository.watchSafeTrip(journeyId).listen((updatedTrip) async {
      final updatedCheckins = await repository.getCheckins(journeyId);
      final updatedLoc = await repository.getActiveLocationSession(journeyId);
      final updatedEvents = await repository.getJourneyEvents(journeyId);
      state = state.copyWith(
        currentTrip: updatedTrip,
        checkins: updatedCheckins,
        activeLocationSession: updatedLoc,
        events: updatedEvents,
      );
    });
  }

  /// Server-authoritative, idempotent activation of SafeTrip.
  Future<bool> activateSafeTrip({required JourneyConsent consent}) async {
    final current = state.currentTrip;
    if (current == null) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final idempotencyKey = 'act-${current.id}-${DateTime.now().millisecondsSinceEpoch}';
      final activated = await repository.activateSafeTrip(
        journeyId: current.id,
        idempotencyKey: idempotencyKey,
        consent: consent,
      );

      ref.read(analyticsServiceProvider).logEvent( 'safetrip_activated',
        parameters: {
          'journey_id': activated.id,
          'sharing_status': consent.shareStatusWithTrustedContact,
          'sharing_loc': consent.shareApproximateLocation,
        },
      );

      final checkins = await repository.getCheckins(current.id);
      final events = await repository.getJourneyEvents(current.id);

      state = state.copyWith(
        currentTrip: activated,
        checkins: checkins,
        events: events,
        isLoading: false,
        actionSuccessMessage: 'SafeTrip activated. Travel safer together!',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Activation error: $e',
      );
      return false;
    }
  }

  /// Records traveler check-in ("I'm OK").
  Future<bool> recordCheckin({String? notes}) async {
    final current = state.currentTrip;
    if (current == null) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final idempotencyKey =
          'chk-${current.id}-${DateTime.now().millisecondsSinceEpoch ~/ 60000}';
      final checkin = await repository.recordCheckin(
        journeyId: current.id,
        userId: _currentUserId,
        idempotencyKey: idempotencyKey,
        notes: notes,
      );

      ref.read(analyticsServiceProvider).logEvent( 'safetrip_checkin_completed',
        parameters: {
          'journey_id': current.id,
          'checkin_number': checkin.checkinNumber,
        },
      );

      final updatedTrip = await repository.getSafeTripById(current.id);
      final checkins = await repository.getCheckins(current.id);
      final events = await repository.getJourneyEvents(current.id);

      state = state.copyWith(
        currentTrip: updatedTrip,
        checkins: checkins,
        events: events,
        isLoading: false,
        actionSuccessMessage: '✓ You are marked safe for this check-in.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Check-in error: $e',
      );
      return false;
    }
  }

  /// Traveler confirms arrival at destination.
  Future<bool> confirmArrival() async {
    final current = state.currentTrip;
    if (current == null) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final idempotencyKey = 'arr-${current.id}';
      final arrived = await repository.confirmArrival(
        journeyId: current.id,
        idempotencyKey: idempotencyKey,
      );

      ref.read(analyticsServiceProvider).logEvent( 'safetrip_arrival_confirmed',
        parameters: {'journey_id': current.id},
      );

      final events = await repository.getJourneyEvents(current.id);

      state = state.copyWith(
        currentTrip: arrived,
        activeLocationSession: null,
        events: events,
        isLoading: false,
        actionSuccessMessage: 'Arrival confirmed safely!',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Arrival confirmation error: $e',
      );
      return false;
    }
  }

  /// Final journey completion after arrival.
  Future<bool> completeJourney() async {
    final current = state.currentTrip;
    if (current == null) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final idempotencyKey = 'comp-${current.id}';
      final completed = await repository.completeSafeTrip(
        journeyId: current.id,
        idempotencyKey: idempotencyKey,
      );

      ref.read(analyticsServiceProvider).logEvent( 'safetrip_completed',
        parameters: {'journey_id': current.id},
      );

      final events = await repository.getJourneyEvents(current.id);

      state = state.copyWith(
        currentTrip: completed,
        events: events,
        isLoading: false,
        actionSuccessMessage: 'SafeTrip journey completed.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Completion error: $e',
      );
      return false;
    }
  }

  /// Starts or updates temporary approximate location sharing.
  Future<bool> startLocationSharing({
    required LocationSharingMode mode,
    required Duration duration,
    String? approxGeohash,
  }) async {
    final current = state.currentTrip;
    if (current == null) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final session = await repository.startLocationSharing(
        journeyId: current.id,
        userId: _currentUserId,
        mode: mode,
        duration: duration,
        approxGeohash: approxGeohash ?? 'approx-area',
      );

      ref.read(analyticsServiceProvider).logEvent( 'location_sharing_started',
        parameters: {
          'journey_id': current.id,
          'mode': mode.code,
        },
      );

      final updatedTrip = await repository.getSafeTripById(current.id);
      final events = await repository.getJourneyEvents(current.id);

      state = state.copyWith(
        currentTrip: updatedTrip,
        activeLocationSession: session,
        events: events,
        isLoading: false,
        actionSuccessMessage: 'Approximate location sharing active.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to start location sharing: $e',
      );
      return false;
    }
  }

  /// Immediately revokes location sharing.
  Future<void> stopLocationSharing() async {
    final current = state.currentTrip;
    if (current == null) return;

    try {
      await repository.stopLocationSharing(
        journeyId: current.id,
        userId: _currentUserId,
      );

      ref.read(analyticsServiceProvider).logEvent( 'location_sharing_stopped',
        parameters: {'journey_id': current.id},
      );

      final updatedTrip = await repository.getSafeTripById(current.id);
      final events = await repository.getJourneyEvents(current.id);

      state = state.copyWith(
        currentTrip: updatedTrip,
        activeLocationSession: null,
        events: events,
        actionSuccessMessage: 'Location sharing stopped.',
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to stop location sharing: $e',
      );
    }
  }

  /// Cancels SafeTrip journey.
  Future<bool> cancelJourney(String reason) async {
    final current = state.currentTrip;
    if (current == null) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cancelled = await repository.cancelSafeTrip(
        current.id,
        reason: reason,
      );

      final events = await repository.getJourneyEvents(current.id);

      state = state.copyWith(
        currentTrip: cancelled,
        activeLocationSession: null,
        events: events,
        isLoading: false,
        actionSuccessMessage: 'SafeTrip cancelled.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Cancel error: $e',
      );
      return false;
    }
  }
}

final safeTripControllerProvider =
    StateNotifierProvider<SafeTripController, SafeTripState>((ref) {
  final repo = ref.watch(safeTripRepositoryProvider);
  return SafeTripController(repository: repo, ref: ref);
});
