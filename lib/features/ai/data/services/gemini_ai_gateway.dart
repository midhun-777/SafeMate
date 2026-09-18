/// SafeMate Gemini & Secure Server AI Gateway Implementation.
/// Universal Engineering Rule #11: Graceful offline fallback, zero secret exposure, structured resilience.
library;

import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safemate/core/config/app_config.dart';
import '../../domain/models/ai_models.dart';
import '../../domain/services/ai_gateway.dart';

/// Production-ready AI Gateway supporting live server/provider routing with hermetic offline mock mode.
class GeminiAiGateway implements AiGateway {
  final AiRateLimiter _rateLimiter;
  final bool isDevMode;

  GeminiAiGateway({
    AiRateLimiter? rateLimiter,
    bool? isDevMode,
  })  : _rateLimiter = rateLimiter ?? AiRateLimiter(),
        isDevMode = isDevMode ?? AppConfig.isDevelopment;

  @override
  Future<bool> checkAvailability() async {
    // In production, can ping Supabase Edge Function health check.
    // In dev mode, always available via local deterministic generator.
    return true;
  }

  @override
  Future<AiResponse> execute(AiRequest request) async {
    final stopwatch = Stopwatch()..start();

    // 1. Rate Limiting Check (per-session/device)
    const clientKey = 'active_user_session';
    if (!_rateLimiter.allowRequest(clientKey)) {
      throw const AiException(
        kind: AiErrorKind.rateLimited,
        message: 'You have reached the temporary AI request limit. Please wait a few minutes.',
        statusCode: 429,
        canRetry: false,
      );
    }

    try {
      // 2. Execute query within configured timeout
      final response = await _dispatchQuery(request).timeout(
        request.timeout,
        onTimeout: () {
          throw const AiException(
            kind: AiErrorKind.timeout,
            message: 'Journey AI took too long to respond. Please try again.',
            statusCode: 408,
            canRetry: true,
          );
        },
      );

      stopwatch.stop();
      return AiResponse(
        content: response.content,
        structuredData: response.structuredData,
        usage: response.usage,
        model: response.model,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } on AiException {
      rethrow;
    } catch (e) {
      stopwatch.stop();
      // Graceful fallback for unexpected exceptions
      return AiResponse.fallback(
        message:
            'Journey AI is temporarily unavailable. Your core SafeMate trip and safety features are unaffected.',
        model: 'system-fallback',
      );
    }
  }

  /// Internal query dispatcher.
  /// In production, dispatches strictly to the secure server Edge Function without leaking secrets.
  /// If live Edge Function fails in production, NEVER falls back to local fake AI!
  Future<AiResponse> _dispatchQuery(AiRequest request) async {
    if (!isDevMode) {
      try {
        if (!AppConfig.hasValidSupabaseConfig) {
          throw const AiException(
            kind: AiErrorKind.unavailable,
            message: 'Journey AI is temporarily unavailable.',
            statusCode: 503,
            canRetry: false,
          );
        }

        final response = await Supabase.instance.client.functions.invoke(
          'journey-copilot',
          body: request.toJson(),
        );

        if (response.status != 200 || response.data == null) {
          throw AiException(
            kind: AiErrorKind.serverError,
            message: 'Journey AI is temporarily unavailable.',
            statusCode: response.status,
            canRetry: true,
          );
        }

        final data = response.data as Map<String, dynamic>;
        return AiResponse(
          content: data['content'] as String? ?? '',
          usage: data['usage'] != null
              ? AiUsage.fromJson(data['usage'] as Map<String, dynamic>)
              : const AiUsage(),
          model: data['model'] as String? ?? 'gemini-1.5-flash',
          latencyMs: 150,
        );
      } on AiException {
        rethrow;
      } catch (e) {
        // Critical: In production, NEVER fall back to local fake AI!
        throw const AiException(
          kind: AiErrorKind.unavailable,
          message: 'Journey AI is temporarily unavailable.',
          statusCode: 503,
          canRetry: true,
        );
      }
    }

    // In dev / test mode: use local deterministic generator
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return _generateDeterministicResponse(request);
  }

  /// High-fidelity deterministic generator for testing and offline environments.
  AiResponse _generateDeterministicResponse(AiRequest request) {
    final destination = request.context['destination'] as String? ?? 'your destination';
    final duration = request.context['duration_days'] as int? ?? 3;
    final budget = request.context['budget_tier'] as String? ?? 'Moderate';

    switch (request.feature) {
      case AiFeatureType.itinerary:
      case AiFeatureType.adaptivePlanning:
        final items = <Map<String, dynamic>>[];
        for (var day = 1; day <= (duration > 5 ? 5 : duration); day++) {
          items.add({
            'day': day,
            'title': 'Day $day: Explore $destination highlights',
            'morning': 'Arrival and check-in at central area; orientation walk.',
            'afternoon': 'Visit cultural landmarks and local authentic cuisine hubs.',
            'evening': 'Relaxed dinner at well-reviewed local venue; early rest.',
            'activity_type': 'sightseeing',
          });
        }

        final structured = {
          'type': 'itinerary_proposal',
          'title': '$duration-Day Suggested Itinerary for $destination ($budget)',
          'items': items,
          'disclaimer':
              'AI suggestion for planning guidance only. Please verify operating hours and transit independently.',
        };

        return AiResponse(
          content: jsonEncode(structured),
          structuredData: structured,
          usage: const AiUsage(promptTokens: 140, completionTokens: 280, totalTokens: 420),
          model: 'gemini-1.5-flash-safe',
          latencyMs: 120,
        );

      case AiFeatureType.safetyAssist:
        final structured = {
          'type': 'safety_guidance',
          'title': 'SafeMate Journey Safety Essentials',
          'tips': [
            'SafeTrip check-ins provide regular peace-of-mind updates to your companion and trusted contacts.',
            'Location sharing is approximate (~20km radius) and can be stopped at any time.',
            'Missed check-ins have a 15-minute calm grace period before gentle reminders are sent.',
            'Always keep emergency cash and local emergency numbers saved offline.',
          ],
          'emergency_support': 'Visit the Safety Center for one-tap emergency dialer handoffs.',
        };

        return AiResponse(
          content:
              'SafeMate is designed around mutual accountability and privacy.\n\n'
              '• SafeTrip check-ins keep you connected without intrusive tracking.\n'
              '• Location sharing uses coarse ~20km areas only.\n'
              '• You can confirm arrival or pause your journey at any time.',
          structuredData: structured,
          usage: const AiUsage(promptTokens: 100, completionTokens: 160, totalTokens: 260),
          model: 'gemini-1.5-flash-safe',
          latencyMs: 95,
        );

      case AiFeatureType.companionCoord:
        final structured = {
          'type': 'companion_coordination',
          'title': 'Companion Coordination Ideas',
          'meeting_point_ideas': [
            'Main entrance lobby of $destination Central Station',
            'Well-lit coffee shop near arrival terminal',
          ],
          'suggested_message':
              'Hi! Looking forward to our trip to $destination. Shall we meet at the main station entrance when we arrive?',
        };

        return AiResponse(
          content: structured['suggested_message'] as String,
          structuredData: structured,
          usage: const AiUsage(promptTokens: 110, completionTokens: 120, totalTokens: 230),
          model: 'gemini-1.5-flash-safe',
          latencyMs: 105,
        );

      case AiFeatureType.matchExplanation:
        return AiResponse(
          content:
              'You and your companion matched on key travel dimensions: shared destination ($destination), overlapping travel dates, and compatible pacing preferences.',
          usage: const AiUsage(promptTokens: 90, completionTokens: 80, totalTokens: 170),
          model: 'gemini-1.5-flash-safe',
          latencyMs: 90,
        );

      case AiFeatureType.trustExplanation:
        return AiResponse(
          content:
              'Trust profiles reflect verified identity credentials and completed trip reviews. These are historical reputation signals, not a guarantee of personal safety.',
          usage: const AiUsage(promptTokens: 80, completionTokens: 75, totalTokens: 155),
          model: 'gemini-1.5-flash-safe',
          latencyMs: 85,
        );

      case AiFeatureType.disruptionHelp:
        return AiResponse(
          content:
              'When travel delays occur, stay calm: verify updates directly with official transit ticket counters or airlines. If delayed, you can pause your SafeTrip or adjust your arrival time in the SafeTrip cockpit.',
          usage: const AiUsage(promptTokens: 95, completionTokens: 110, totalTokens: 205),
          model: 'gemini-1.5-flash-safe',
          latencyMs: 100,
        );

      case AiFeatureType.copilot:
        return AiResponse(
          content:
              'Here are some recommendations for your trip to $destination ($duration days):\n\n'
              '1. Plan buffer time between connections.\n'
              '2. Set up your SafeTrip check-ins before departure.\n'
              '3. Review our suggested meeting points with your companion.',
          usage: const AiUsage(promptTokens: 120, completionTokens: 140, totalTokens: 260),
          model: 'gemini-1.5-flash-safe',
          latencyMs: 110,
        );
    }
  }
}
