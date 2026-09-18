import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/database/database_exceptions.dart';
import 'package:safemate/core/database/local_data_policy.dart';

void main() {
  group('Phase 12.2 Category C Hard Block Tests (12.2.9)', () {
    test('strictly rejects Category C fields at persistence validation', () {
      final prohibitedExamples = [
        {'id': '1', 'aadhaar': '9999-8888-7777'},
        {'id': '2', 'passport': 'K1234567'},
        {'id': '3', 'government_id': 'GOV-IND-88'},
        {'id': '4', 'auth_token': 'eyJh...'},
        {'id': '5', 'refresh_token': 'rfr_99...'},
        {'id': '6', 'password': 'super_secret'},
        {'id': '7', 'payment_credentials': {'card': '4111'}},
        {'id': '8', 'raw_gps_trail': [{'lat': 12.9, 'lng': 77.5}]},
        {'id': '9', 'continuous_gps': true},
        {'id': '10', 'moderation_notes': 'Suspicious flag'},
        {'id': '11', 'document_image_bytes': [0, 1, 2, 3]},
      ];

      for (final payload in prohibitedExamples) {
        expect(
          () => LocalDataPolicy.assertSafeForLocalPersistence(payload, entityName: 'SecurityAuditTest'),
          throwsA(isA<DatabasePolicyViolationException>()),
          reason: 'Payload containing ${payload.keys.last} must throw DatabasePolicyViolationException',
        );
      }
    });

    test('recursively detects prohibited keys in deeply nested data structures', () {
      final nestedPayload = {
        'trip': {
          'destination': 'Paris',
          'metadata': {
            'security': {
              'auth_token': 'leaked_secret_token',
            },
          },
        },
      };

      expect(
        () => LocalDataPolicy.assertSafeForLocalPersistence(nestedPayload, entityName: 'DeepNestingTest'),
        throwsA(isA<DatabasePolicyViolationException>()),
      );
    });
  });
}
