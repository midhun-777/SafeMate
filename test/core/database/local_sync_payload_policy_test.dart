import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/database/database_exceptions.dart';
import 'package:safemate/core/database/local_data_policy.dart';

void main() {
  group('Phase 12.2 Sync Queue Privacy & Payload Size Tests (12.2.12 & 12.2.13)', () {
    test('permits valid sync queue payload for approved entities and operations', () {
      final validPayload = {
        'destination': 'Kyoto',
        'budget': 'moderate',
        'dates': ['2026-10-01', '2026-10-05'],
      };

      expect(
        () => LocalDataPolicy.validateSyncPayload('trip', 'create', validPayload),
        returnsNormally,
      );
    });

    test('rejects unapproved sync entity types', () {
      final payload = {'data': 'test'};
      expect(
        () => LocalDataPolicy.validateSyncPayload('unapproved_bank_account', 'create', payload),
        throwsA(isA<DatabasePolicyViolationException>()),
      );
    });

    test('rejects unapproved sync operation types', () {
      final payload = {'data': 'test'};
      expect(
        () => LocalDataPolicy.validateSyncPayload('trip', 'drop_database', payload),
        throwsA(isA<DatabasePolicyViolationException>()),
      );
    });

    test('rejects sync payload containing sensitive Category C fields', () {
      final toxicPayload = {
        'destination': 'Rome',
        'auth_token': 'forbidden_token_123',
      };

      expect(
        () => LocalDataPolicy.validateSyncPayload('trip', 'update', toxicPayload),
        throwsA(isA<DatabasePolicyViolationException>()),
      );
    });

    test('rejects oversized sync payload exceeding 64 KB limit', () {
      final largeString = 'A' * (LocalDataPolicy.maxPayloadSizeBytes + 100);
      final oversizedPayload = {'large_data': largeString};

      expect(
        () => LocalDataPolicy.validateSyncPayload('trip', 'create', oversizedPayload),
        throwsA(isA<DatabasePolicyViolationException>()),
      );
    });
  });
}
