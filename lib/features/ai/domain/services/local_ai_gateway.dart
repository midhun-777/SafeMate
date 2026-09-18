/// SafeMate Local Edge AI Gateway & Device Capability Engine.
/// Universal Engineering Rule #11: Offline AI is advisory, never authoritative.
/// Universal Engineering Rule #24: Explicit fallback; never fake local LLM execution.
library;

import '../models/ai_models.dart';
import 'ai_context_builder.dart';
import 'ai_gateway.dart';

/// Device hardware capability tiers for on-device AI.
enum DeviceAiTier {
  /// Tier A: High-End (>= 6GB RAM, arm64-v8a). Feasible for quantized Gemma 2B.
  tierA,

  /// Tier B: Mid-Range (4-6GB RAM). Heavy memory pressure; thermal/battery throttled.
  tierB,

  /// Tier C: Low-End or Unsupported (< 4GB RAM). Deterministic offline fallback only.
  tierC,
}

/// Offline Edge AI Gateway providing deterministic offline journey assistance.
class LocalAiGateway implements AiGateway {
  final DeviceAiTier deviceTier;

  const LocalAiGateway({
    this.deviceTier = DeviceAiTier.tierC,
  });

  @override
  Future<bool> checkAvailability() async => true;

  @override
  Future<AiResponse> execute(AiRequest request) async {
    // 1. Security & Privacy Guard: Validate input data against denylist
    if (AiJourneyContextBuilder.containsSensitiveData(request.context)) {
      throw const AiException(
        kind: AiErrorKind.policyViolation,
        message: 'Security Violation: Prohibited sensitive data detected in local AI request.',
        canRetry: false,
      );
    }

    // 2. Consequential Action Block: Offline AI has zero authority over safety or dispatch
    final userPrompt = request.userPrompt.toLowerCase();
    if (userPrompt.contains('emergency') ||
        userPrompt.contains('police') ||
        userPrompt.contains('activate safetrip') ||
        userPrompt.contains('suspend user') ||
        userPrompt.contains('change trust')) {
      throw const AiException(
        kind: AiErrorKind.policyViolation,
        message: 'Forbidden: Consequential safety and account actions cannot be executed offline.',
        canRetry: false,
      );
    }

    final destination = request.context['destination'] as String? ?? 'your destination';
    final duration = request.context['duration_days'] as int? ?? 3;

    // 3. Generate deterministic offline advice based on feature type
    switch (request.feature) {
      case AiFeatureType.itinerary:
      case AiFeatureType.adaptivePlanning:
        return _generateOfflineItinerary(destination, duration);

      case AiFeatureType.safetyAssist:
        return _generateOfflineSafetyTips(destination);

      case AiFeatureType.companionCoord:
        return _generateOfflineCoordination();

      case AiFeatureType.copilot:
      default:
        return AiResponse(
          content: 'You are currently offline. SafeMate is providing verified offline guidance for $destination. '
              'Connect to the internet to access live Gemini Copilot assistance.',
          model: 'safemate-edge-deterministic-1.0',
          isFallback: true,
          latencyMs: 15,
        );
    }
  }

  AiResponse _generateOfflineItinerary(String destination, int duration) {
    final items = <Map<String, dynamic>>[];
    for (int i = 1; i <= duration && i <= 3; i++) {
      items.add({
        'day': i,
        'title': 'Explore $destination — Highlights',
        'activities': [
          'Visit historic city center and cultural landmarks',
          'Local food tasting at central market',
          'Scenic walking trail and companion photo stops',
        ],
      });
    }

    return AiResponse(
      content: 'Here is an offline suggested itinerary for $destination.',
      structuredData: {
        'type': 'itinerary_proposal',
        'items': items,
        'notes': 'Offline generated proposal. Review and apply when ready.',
      },
      model: 'safemate-edge-deterministic-1.0',
      isFallback: true,
      latencyMs: 10,
    );
  }

  AiResponse _generateOfflineSafetyTips(String destination) {
    return AiResponse(
      content: 'Offline Safety Preparation for $destination:\n'
          '1. Confirm your emergency contacts and local embassy numbers.\n'
          '2. Download offline maps and keep your device battery above 40%.\n'
          '3. Agree on daylight meeting points with your companions.\n'
          '4. Keep check-in schedules consistent even when connectivity drops.',
      model: 'safemate-edge-deterministic-1.0',
      isFallback: true,
      latencyMs: 10,
    );
  }

  AiResponse _generateOfflineCoordination() {
    return AiResponse(
      content: 'Offline Companion Suggestion: "Hey! Signal is weak right now. Let us stick to our agreed itinerary and meet at the central entrance at the scheduled time."',
      model: 'safemate-edge-deterministic-1.0',
      isFallback: true,
      latencyMs: 10,
    );
  }
}
