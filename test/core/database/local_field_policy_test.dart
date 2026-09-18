import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/database/database_exceptions.dart';
import 'package:safemate/core/database/local_data_policy.dart';

void main() {
  group('Phase 12.2 Local Field-Level Allowlist Tests (12.2.2)', () {
    test('local_trips rejects unapproved fields even if non-sensitive', () {
      final tripWithUnapprovedField = {
        'id': 'trip_001',
        'user_id': 'user_alice',
        'destination': 'Kyoto',
        'origin': 'Tokyo',
        'start_date': DateTime.now().toIso8601String(),
        'end_date': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
        'purpose': 'culture',
        'budget': 'moderate',
        'status': 'published',
        'raw_json': '{"destination":"Kyoto"}',
        'updated_at': DateTime.now().toIso8601String(),
        'unapproved_marketing_tag': 'promo_2026', // Not in allowedFields!
      };

      expect(
        () => LocalDataPolicy.validateTableWrite('local_trips', tripWithUnapprovedField),
        throwsA(isA<DatabasePolicyViolationException>()),
      );
    });

    test('local_profiles rejects phone and email from being persisted', () {
      final profileWithPhone = {
        'id': 'user_alice',
        'user_id': 'user_alice',
        'display_name': 'Alice',
        'raw_json': '{"display_name":"Alice"}',
        'updated_at': DateTime.now().toIso8601String(),
        'phone': '+15551234567', // Prohibited from local profile cache
      };

      expect(
        () => LocalDataPolicy.validateTableWrite('local_profiles', profileWithPhone),
        throwsA(isA<DatabasePolicyViolationException>()),
      );

      final profileWithEmail = {
        'id': 'user_alice',
        'user_id': 'user_alice',
        'display_name': 'Alice',
        'raw_json': '{"display_name":"Alice"}',
        'updated_at': DateTime.now().toIso8601String(),
        'email': 'alice@example.com', // Prohibited from local profile cache
      };

      expect(
        () => LocalDataPolicy.validateTableWrite('local_profiles', profileWithEmail),
        throwsA(isA<DatabasePolicyViolationException>()),
      );
    });
  });
}
