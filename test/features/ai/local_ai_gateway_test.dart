import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/ai/domain/models/ai_models.dart';
import 'package:safemate/features/ai/domain/services/local_ai_gateway.dart';

void main() {
  group('Phase 12.10 LocalAiGateway Tests', () {
    const gateway = LocalAiGateway(deviceTier: DeviceAiTier.tierC);

    test('Generates deterministic offline itinerary proposal', () async {
      const request = AiRequest(
        feature: AiFeatureType.itinerary,
        systemPrompt: 'You are SafeMate Copilot.',
        userPrompt: 'Suggest places to visit',
        context: {
          'destination': 'Kyoto',
          'duration_days': 3,
        },
      );

      final response = await gateway.execute(request);
      expect(response.isFallback, isTrue);
      expect(response.model, 'safemate-edge-deterministic-1.0');
      expect(response.structuredData, isNotNull);
      expect(response.structuredData!['type'], 'itinerary_proposal');
      expect((response.structuredData!['items'] as List).length, 3);
    });

    test('Generates deterministic offline safety guidance', () async {
      const request = AiRequest(
        feature: AiFeatureType.safetyAssist,
        systemPrompt: 'You are SafeMate Copilot.',
        userPrompt: 'Safety tips for my trip',
        context: {
          'destination': 'Munich',
        },
      );

      final response = await gateway.execute(request);
      expect(response.content, contains('Offline Safety Preparation for Munich'));
      expect(response.content, contains('offline maps'));
    });

    test('Blocks sensitive Category C data from entering local AI context', () async {
      const badRequest = AiRequest(
        feature: AiFeatureType.copilot,
        systemPrompt: 'You are SafeMate Copilot.',
        userPrompt: 'Plan my day',
        context: {
          'destination': 'London',
          'aadhaar': '1234-5678-9012', // Prohibited sensitive key
        },
      );

      expect(
        () => gateway.execute(badRequest),
        throwsA(isA<AiException>().having((e) => e.kind, 'kind', AiErrorKind.policyViolation)),
      );
    });

    test('Blocks consequential actions from being executed by offline AI', () async {
      const actionRequest = AiRequest(
        feature: AiFeatureType.copilot,
        systemPrompt: 'You are SafeMate Copilot.',
        userPrompt: 'Please activate safetrip and contact police immediately',
        context: {
          'destination': 'Tokyo',
        },
      );

      expect(
        () => gateway.execute(actionRequest),
        throwsA(isA<AiException>().having((e) => e.kind, 'kind', AiErrorKind.policyViolation)),
      );
    });
  });
}
