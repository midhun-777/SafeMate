/// SafeMate Journey Copilot Controller.
/// Universal Engineering Rule #11: AI never mutates user trip data without explicit user confirmation.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safemate/core/services/analytics_service.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:safemate/features/trips/domain/repositories/trip_repository.dart';
import 'package:safemate/features/trips/presentation/controllers/trip_creation_controller.dart';
import 'package:safemate/features/safety/domain/repositories/safetrip_repository.dart';
import 'package:safemate/features/safety/presentation/controllers/safetrip_controller.dart';
import '../../data/services/gemini_ai_gateway.dart';
import '../../domain/models/ai_models.dart';
import '../../domain/services/ai_context_builder.dart';
import '../../domain/services/ai_gateway.dart';
import '../../domain/services/ai_response_validator.dart';

/// Provider for the AI Gateway.
final aiGatewayProvider = Provider<AiGateway>((ref) {
  return GeminiAiGateway();
});

/// Provider for AI Response Validator.
final aiResponseValidatorProvider = Provider<AiResponseValidator>((ref) {
  return const AiResponseValidator();
});

/// Individual message model for the Copilot chat history.
class CopilotMessage {
  final String id;
  final bool isUser;
  final String text;
  final Map<String, dynamic>? structuredData;
  final bool isProposal;
  final DateTime timestamp;

  const CopilotMessage({
    required this.id,
    required this.isUser,
    required this.text,
    this.structuredData,
    this.isProposal = false,
    required this.timestamp,
  });
}

/// State for the Journey Copilot assistant.
class JourneyCopilotState {
  final bool isLoading;
  final List<CopilotMessage> messages;
  final Map<String, dynamic>? activeProposal;
  final String? errorMessage;
  final AiUsage usage;

  const JourneyCopilotState({
    this.isLoading = false,
    this.messages = const [],
    this.activeProposal,
    this.errorMessage,
    this.usage = const AiUsage(),
  });

  JourneyCopilotState copyWith({
    bool? isLoading,
    List<CopilotMessage>? messages,
    Map<String, dynamic>? activeProposal,
    bool clearProposal = false,
    String? errorMessage,
    bool clearError = false,
    AiUsage? usage,
  }) {
    return JourneyCopilotState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      activeProposal: clearProposal ? null : (activeProposal ?? this.activeProposal),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      usage: usage ?? this.usage,
    );
  }
}

/// Controller managing AI Journey Copilot interactions for a specific [tripId].
class JourneyCopilotController extends StateNotifier<JourneyCopilotState> {
  final String tripId;
  final Ref _ref;
  final AiGateway _gateway;
  final AiResponseValidator _validator;
  final TripRepository _tripRepo;
  final SafeTripRepository _safeTripRepo;
  final AnalyticsService _analytics;

  JourneyCopilotController({
    required this.tripId,
    required Ref ref,
  })  : _ref = ref,
        _gateway = ref.read(aiGatewayProvider),
        _validator = ref.read(aiResponseValidatorProvider),
        _tripRepo = ref.read(tripRepositoryProvider),
        _safeTripRepo = ref.read(safeTripRepositoryProvider),
        _analytics = ref.read(analyticsServiceProvider),
        super(const JourneyCopilotState()) {
    _initWelcome();
  }

  void _initWelcome() {
    state = state.copyWith(
      messages: [
        CopilotMessage(
          id: 'welcome',
          isUser: false,
          text:
              'Hello! I am your SafeMate Journey Copilot. I can help you plan your itinerary, prepare for departure, adapt travel pace, or explain safety features.',
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  /// Sends a user query to the AI Gateway with authenticated, privacy-filtered context.
  Future<void> sendQuery(
    String userPrompt, {
    AiFeatureType feature = AiFeatureType.copilot,
  }) async {
    if (userPrompt.trim().isEmpty) return;

    final sanitizedPrompt = AiResponseValidator.sanitizePromptInput(userPrompt);

    // 1. Add user message to UI
    final userMsg = CopilotMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isUser: true,
      text: sanitizedPrompt,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      messages: [...state.messages, userMsg],
    );

    try {
      await _analytics.logEvent('ai_request_started', parameters: {
        'trip_id': tripId,
        'feature': feature.code,
      });

      // 2. Fetch authenticated user & trip models
      final authState = _ref.read(authControllerProvider);
      final currentUid = authState.profile?.id ?? authState.session?.userId ?? '';
      final trip = await _tripRepo.getTrip(tripId);

      if (trip == null) {
        throw StateError('Trip $tripId not found.');
      }

      final safeTrip = await _safeTripRepo.getSafeTripByTripId(tripId);

      // 3. Compile authorized, privacy-sanitized context
      const builder = AiJourneyContextBuilder();
      final context = builder.buildContext(
        trip: trip,
        safeTrip: safeTrip,
        requestingUserId: currentUid,
      );

      // 4. Dispatch query through Gateway
      final request = AiRequest(
        feature: feature,
        systemPrompt:
            'You are SafeMate Journey Copilot, a calm, intelligent travel planning assistant. '
            'Provide practical suggestions, clear itineraries, and safety guidance based strictly on the trip context. '
            'Never invent live transport delays or declare anyone dangerous. All proposals must be clear suggestions.',
        userPrompt: sanitizedPrompt,
        context: context.toJson(),
      );

      final rawResponse = await _gateway.execute(request);

      // 5. Post-process & validate response
      final validatedResponse = _validator.validateAndSanitize(rawResponse);

      final isProposal = validatedResponse.structuredData?['type'] == 'itinerary_proposal';

      final aiMsg = CopilotMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        isUser: false,
        text: isProposal
            ? 'I have prepared a suggested itinerary based on your trip details:'
            : validatedResponse.content,
        structuredData: validatedResponse.structuredData,
        isProposal: isProposal,
        timestamp: DateTime.now(),
      );

      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        messages: [...state.messages, aiMsg],
        activeProposal: isProposal ? validatedResponse.structuredData : state.activeProposal,
        usage: AiUsage(
          promptTokens: state.usage.promptTokens + validatedResponse.usage.promptTokens,
          completionTokens: state.usage.completionTokens + validatedResponse.usage.completionTokens,
          totalTokens: state.usage.totalTokens + validatedResponse.usage.totalTokens,
        ),
      );

      await _analytics.logEvent('ai_request_completed', parameters: {
        'trip_id': tripId,
        'feature': feature.code,
      });
    } on AiException catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      await _analytics.logEvent('ai_request_failed', parameters: {
        'trip_id': tripId,
        'error_kind': e.kind.code,
      });
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Journey AI is temporarily unavailable. Please try again.',
      );
    }
  }

  /// Request a structured itinerary proposal.
  Future<void> requestItinerary() {
    return sendQuery(
      'Create a day-by-day suggested itinerary for this journey.',
      feature: AiFeatureType.itinerary,
    );
  }

  /// Request adaptive planning modifications.
  Future<void> requestAdaptivePlan(String modificationPrompt) {
    return sendQuery(
      'Adapt my trip plan: $modificationPrompt',
      feature: AiFeatureType.adaptivePlanning,
    );
  }

  /// Request safety and privacy explanation.
  Future<void> requestSafetyGuidance() {
    return sendQuery(
      'Explain SafeMate safety features and check-in options for my journey.',
      feature: AiFeatureType.safetyAssist,
    );
  }

  /// Request companion coordination ideas.
  Future<void> requestCompanionCoordination() {
    return sendQuery(
      'Suggest meeting points and coordination tips for my companion.',
      feature: AiFeatureType.companionCoord,
    );
  }

  /// Explicit user action: Confirms and applies the AI-suggested itinerary proposal to trip notes.
  /// Universal Engineering Rule #11: AI never mutates trip data without explicit user action!
  Future<bool> applyActiveProposal() async {
    final proposal = state.activeProposal;
    if (proposal == null) return false;

    state = state.copyWith(isLoading: true);
    try {
      final trip = await _tripRepo.getTrip(tripId);
      if (trip == null) return false;

      // Extract formatted summary from proposal
      final title = proposal['title'] as String? ?? 'Suggested Itinerary';
      final items = proposal['items'] as List<dynamic>? ?? [];
      final buffer = StringBuffer();
      buffer.writeln('--- $title ---');
      for (final it in items) {
        if (it is Map<String, dynamic>) {
          buffer.writeln('${it['title']}:');
          buffer.writeln('• Morning: ${it['morning']}');
          buffer.writeln('• Afternoon: ${it['afternoon']}');
          buffer.writeln('• Evening: ${it['evening']}');
        }
      }

      final updatedNotes = trip.notes != null && trip.notes!.isNotEmpty
          ? '${trip.notes}\n\n${buffer.toString()}'
          : buffer.toString();

      final updatedTrip = trip.copyWith(notes: updatedNotes);
      await _tripRepo.updateTrip(updatedTrip);

      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        clearProposal: true,
        messages: [
          ...state.messages,
          CopilotMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            isUser: false,
            text: '✓ The proposed itinerary has been successfully added to your trip details.',
            timestamp: DateTime.now(),
          ),
        ],
      );

      await _analytics.logEvent('ai_proposal_applied', parameters: {'trip_id': tripId});
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to apply plan changes. Please try again.',
      );
      return false;
    }
  }

  /// Dismisses active proposal without applying.
  void dismissActiveProposal() {
    state = state.copyWith(
      clearProposal: true,
      messages: [
        ...state.messages,
        CopilotMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          isUser: false,
          text: 'Proposal kept on hold. Your existing journey plan remains unchanged.',
          timestamp: DateTime.now(),
        ),
      ],
    );
  }
}

/// Riverpod family provider for [JourneyCopilotController].
final journeyCopilotControllerProvider = StateNotifierProvider.autoDispose
    .family<JourneyCopilotController, JourneyCopilotState, String>((ref, tripId) {
  return JourneyCopilotController(tripId: tripId, ref: ref);
});
