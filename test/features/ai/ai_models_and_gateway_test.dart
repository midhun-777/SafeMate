import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/ai/data/services/gemini_ai_gateway.dart';
import 'package:safemate/features/ai/domain/models/ai_models.dart';
import 'package:safemate/features/ai/domain/services/ai_gateway.dart';

void main() {
  group('AI Domain Models & Contracts', () {
    test('AiUsage serialization and defaults', () {
      const usage = AiUsage(promptTokens: 50, completionTokens: 100, totalTokens: 150);
      expect(usage.promptTokens, 50);
      expect(usage.completionTokens, 100);
      expect(usage.totalTokens, 150);

      final json = usage.toJson();
      expect(json['prompt_tokens'], 50);
      expect(json['completion_tokens'], 100);
      expect(json['total_tokens'], 150);

      final fromJson = AiUsage.fromJson(json);
      expect(fromJson.totalTokens, 150);
    });

    test('AiResponse fallback constructor guarantees safe defaults', () {
      final fallback = AiResponse.fallback(message: 'Service down');
      expect(fallback.isFallback, isTrue);
      expect(fallback.content, 'Service down');
      expect(fallback.model, 'system-fallback');
      expect(fallback.latencyMs, 0);
    });

    test('AiException preserves kind and status code', () {
      const ex = AiException(
        kind: AiErrorKind.rateLimited,
        message: 'Rate limit hit',
        statusCode: 429,
        canRetry: false,
      );
      expect(ex.kind, AiErrorKind.rateLimited);
      expect(ex.statusCode, 429);
      expect(ex.canRetry, isFalse);
    });
  });

  group('AI Rate Limiter', () {
    test('enforces request ceiling within sliding window', () {
      final limiter = AiRateLimiter(maxRequests: 3, window: const Duration(minutes: 1));

      expect(limiter.allowRequest('user_1'), isTrue);
      expect(limiter.allowRequest('user_1'), isTrue);
      expect(limiter.allowRequest('user_1'), isTrue);

      // 4th request within window is blocked
      expect(limiter.allowRequest('user_1'), isFalse);

      // Different user is not blocked
      expect(limiter.allowRequest('user_2'), isTrue);
    });
  });

  group('GeminiAiGateway', () {
    late GeminiAiGateway gateway;

    setUp(() {
      gateway = GeminiAiGateway(isDevMode: true);
    });

    test('executes itinerary request and returns valid structured response', () async {
      const request = AiRequest(
        feature: AiFeatureType.itinerary,
        systemPrompt: 'System',
        userPrompt: 'Suggest 3 days in Tokyo',
        context: {
          'destination': 'Tokyo',
          'duration_days': 3,
          'budget_tier': 'Moderate',
        },
      );

      final response = await gateway.execute(request);
      expect(response.structuredData, isNotNull);
      expect(response.structuredData?['type'], 'itinerary_proposal');
      expect(response.structuredData?['title'], contains('Tokyo'));
      final items = response.structuredData?['items'] as List<dynamic>;
      expect(items.length, 3);
      expect(response.isFallback, isFalse);
    });

    test('executes safety assist request and returns calm safety guidance', () async {
      const request = AiRequest(
        feature: AiFeatureType.safetyAssist,
        systemPrompt: 'System',
        userPrompt: 'How does SafeTrip work?',
        context: {'destination': 'Paris'},
      );

      final response = await gateway.execute(request);
      expect(response.content, contains('SafeMate'));
      expect(response.structuredData?['type'], 'safety_guidance');
      expect(response.content, isNot(contains('POLICE CONTACTED')));
      expect(response.content, isNot(contains('DANGEROUS')));
    });

    test('executes companion coordination and provides meeting point suggestions', () async {
      const request = AiRequest(
        feature: AiFeatureType.companionCoord,
        systemPrompt: 'System',
        userPrompt: 'Where should we meet?',
        context: {'destination': 'Kyoto'},
      );

      final response = await gateway.execute(request);
      expect(response.content, contains('Kyoto'));
      expect(response.structuredData?['type'], 'companion_coordination');
    });

    test('rate limiter exhaustion throws AiException with rateLimited kind', () async {
      final strictLimiter = AiRateLimiter(maxRequests: 1);
      final strictGateway = GeminiAiGateway(rateLimiter: strictLimiter, isDevMode: true);

      const request = AiRequest(
        feature: AiFeatureType.copilot,
        systemPrompt: 'System',
        userPrompt: 'Query 1',
      );

      // First query succeeds
      await strictGateway.execute(request);

      // Second query immediately fails with rate limit
      expect(
        () => strictGateway.execute(request),
        throwsA(isA<AiException>().having((e) => e.kind, 'kind', AiErrorKind.rateLimited)),
      );
    });
  });
}
