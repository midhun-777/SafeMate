import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/database/local_data_policy.dart';

void main() {
  group('Phase 12.1 LocalDataPolicy & Classification Tests', () {
    test('classifies Category A, B, and C data categories correctly', () {
      expect(LocalDataPolicy.classifyEntity('trip_summary'), DataClassificationCategory.categoryA);
      expect(LocalDataPolicy.classifyEntity('itinerary'), DataClassificationCategory.categoryA);
      expect(LocalDataPolicy.classifyEntity('packing_checklist'), DataClassificationCategory.categoryA);

      expect(LocalDataPolicy.classifyEntity('user_profile'), DataClassificationCategory.categoryB);
      expect(LocalDataPolicy.classifyEntity('chat_message'), DataClassificationCategory.categoryB);
      expect(LocalDataPolicy.classifyEntity('safetrip_state'), DataClassificationCategory.categoryB);

      expect(LocalDataPolicy.classifyEntity('government_id_scan'), DataClassificationCategory.categoryC);
      expect(LocalDataPolicy.classifyEntity('admin_audit_logs'), DataClassificationCategory.categoryC);
    });

    test('tablePolicyRegistry covers all core SQLite tables', () {
      expect(
        LocalDataPolicy.getTablePolicy('local_user_scope'),
        DataClassificationCategory.categoryA,
      );
      expect(
        LocalDataPolicy.getTablePolicy('local_trips'),
        DataClassificationCategory.categoryA,
      );
      expect(
        LocalDataPolicy.getTablePolicy('local_profiles'),
        DataClassificationCategory.categoryB,
      );
      expect(
        LocalDataPolicy.getTablePolicy('local_sync_queue'),
        DataClassificationCategory.categoryB,
      );
    });

    test('permits operational data without prohibited fields', () {
      final safeTripData = {
        'destination': 'Kyoto',
        'origin': 'Tokyo',
        'budget': 'moderate',
        'tags': ['temple', 'autumn'],
      };

      expect(
        () => LocalDataPolicy.assertSafeForLocalPersistence(safeTripData, entityName: 'Trip'),
        returnsNormally,
      );
    });

    test('throws ArgumentError on prohibited Category C fields (including nested objects)', () {
      final prohibitedPayloads = [
        {'aadhaar': '1234-5678-9012'},
        {'passport': 'A12345678'},
        {'passport_number': 'Z98765432'},
        {'auth_token': 'secret_jwt_token'},
        {'refresh_token': 'secret_refresh_token'},
        {'password': 'mypassword123'},
        {'payment_credentials': {'card_number': '4111222233334444'}},
        {'exact_location_history': [{'lat': 35.68, 'lng': 139.76}]},
        {'moderation_notes': 'Internal ban warning'},
      ];

      for (final payload in prohibitedPayloads) {
        expect(
          () => LocalDataPolicy.assertSafeForLocalPersistence(payload, entityName: 'TestEntity'),
          throwsArgumentError,
        );
      }
    });
  });
}
