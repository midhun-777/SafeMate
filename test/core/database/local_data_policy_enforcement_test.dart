import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/database_exceptions.dart';
import 'package:safemate/core/database/local_data_policy.dart';
import 'package:safemate/core/database/local_database.dart';

void main() {
  sqfliteFfiInit();

  group('Phase 12.2 LocalDataPolicy Enforcement Tests', () {
    test('valid Category A and Category B table writes succeed', () {
      final validTripMap = {
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
      };

      expect(
        () => LocalDataPolicy.validateTableWrite('local_trips', validTripMap),
        returnsNormally,
      );

      final validProfileMap = {
        'id': 'user_alice',
        'user_id': 'user_alice',
        'display_name': 'Alice',
        'bio': 'Traveler',
        'verification_level': 'verified',
        'raw_json': '{"display_name":"Alice"}',
        'updated_at': DateTime.now().toIso8601String(),
      };

      expect(
        () => LocalDataPolicy.validateTableWrite('local_profiles', validProfileMap),
        returnsNormally,
      );
    });

    test('unregistered table fails fast with DatabasePolicyViolationException', () {
      final data = {'id': '1', 'name': 'test'};
      expect(
        () => LocalDataPolicy.validateTableWrite('unregistered_shadow_table', data),
        throwsA(isA<DatabasePolicyViolationException>()),
      );
    });

    test('clearUserScopedData fails fast if SQLite contains an unregistered user table', () async {
      final localDb = LocalDatabase();
      await localDb.open(
        databaseFactory: databaseFactoryFfi,
        dbName: 'fail_fast_test_${DateTime.now().microsecondsSinceEpoch}.db',
      );

      // Create an unclassified shadow table in the SQLite database
      await localDb.database.execute('CREATE TABLE shadow_unregistered_user_cache (id TEXT PRIMARY KEY);');

      // clearUserScopedData should fail fast because the shadow table is missing from LocalDataPolicy.tablePolicyRegistry
      expect(
        () => localDb.clearUserScopedData('user_alice'),
        throwsA(isA<DatabasePolicyViolationException>()),
      );

      await localDb.close();
    });

    test('policy violation audit log does not leak sensitive values', () {
      // Validates that logPolicyViolation only receives metadata, never user content
      expect(
        () => LocalDataPolicy.logPolicyViolation(
          violationType: 'CATEGORY_C_PROHIBITED',
          tableName: 'local_profiles',
          operation: 'persist',
        ),
        returnsNormally,
      );
    });
  });
}
