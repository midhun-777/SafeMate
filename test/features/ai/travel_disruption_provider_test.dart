import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/ai/domain/services/travel_disruption_provider.dart';

void main() {
  group('Travel Disruption Provider Abstraction', () {
    test('NoopTravelDisruptionProvider returns empty list without inventing fake delays', () async {
      const provider = NoopTravelDisruptionProvider();

      final disruptions = await provider.getDisruptionsForDestination('Paris');
      expect(disruptions, isEmpty);
    });

    test('TravelDisruption model serializes and deserializes correctly', () {
      final now = DateTime.now();
      final disruption = TravelDisruption(
        id: 'disrupt_1',
        destination: 'Zurich',
        title: 'Platform Maintenance',
        description: 'Scheduled maintenance on rail line 4.',
        severity: 'advisory',
        source: 'SBB Rail',
        reportedAt: now,
      );

      final json = disruption.toJson();
      expect(json['id'], 'disrupt_1');
      expect(json['destination'], 'Zurich');
      expect(json['severity'], 'advisory');

      final deserialized = TravelDisruption.fromJson(json);
      expect(deserialized.title, 'Platform Maintenance');
      expect(deserialized.source, 'SBB Rail');
    });
  });
}
