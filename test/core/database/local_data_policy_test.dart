import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/database/local_data_policy.dart';

void main() {
  group('Phase 12.2 LocalDataPolicy Tests', () {
    test('Classifies Category A and Category B entities correctly', () {
      expect(
        LocalDataPolicy.classifyEntity('trip_summary'),
        DataClassificationCategory.categoryA,
      );
      expect(
        LocalDataPolicy.classifyEntity('packing_checklist'),
        DataClassificationCategory.categoryA,
      );
      expect(
        LocalDataPolicy.classifyEntity('chat_message'),
        DataClassificationCategory.categoryB,
      );
      expect(
        LocalDataPolicy.classifyEntity('safetrip_state'),
        DataClassificationCategory.categoryB,
      );
      expect(
        LocalDataPolicy.classifyEntity('arbitrary_unclassified'),
        DataClassificationCategory.categoryC,
      );
    });

    test('Permits valid operational data without prohibited fields', () {
      final safeData = {
        'destination': 'Kyoto',
        'start_date': '2026-10-01',
        'notes': 'Pack warm clothes',
      };

      expect(
        () => LocalDataPolicy.assertSafeForLocalPersistence(safeData, entityName: 'Trip'),
        returnsNormally,
      );
    });

    test('Throws ArgumentError on prohibited Category C fields', () {
      final badAadhaar = {'aadhaar': '1234-5678-9012', 'destination': 'Goa'};
      expect(
        () => LocalDataPolicy.assertSafeForLocalPersistence(badAadhaar),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('LocalDataPolicy Violation'),
        )),
      );

      final badPassport = {'passport': 'A12345678', 'user_id': 'u1'};
      expect(
        () => LocalDataPolicy.assertSafeForLocalPersistence(badPassport),
        throwsA(isA<ArgumentError>()),
      );

      final badToken = {'auth_token': 'secret-jwt', 'user_id': 'u1'};
      expect(
        () => LocalDataPolicy.assertSafeForLocalPersistence(badToken),
        throwsA(isA<ArgumentError>()),
      );

      final badGps = {'raw_gps_trail': [12.9, 77.5]};
      expect(
        () => LocalDataPolicy.assertSafeForLocalPersistence(badGps),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
