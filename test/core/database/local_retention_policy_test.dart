import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/database/local_data_policy.dart';

void main() {
  group('Phase 12.2 Local Retention Policy Tests (12.2.8)', () {
    test('all registered tables declare an explicit retention policy', () {
      for (final entry in LocalDataPolicy.tablePolicyRegistry.entries) {
        final policy = entry.value;
        expect(
          policy.retentionPolicy,
          isNotNull,
          reason: 'Table ${entry.key} must declare an explicit LocalRetentionPolicy',
        );
        expect(
          policy.retentionPolicy,
          isNot(LocalRetentionPolicy.neverPersist),
          reason: 'Table ${entry.key} in SQLite cannot be declared as neverPersist',
        );
      }
    });

    test('sync queue tables have persistUntilSynced retention', () {
      expect(
        LocalDataPolicy.tablePolicyRegistry['local_sync_queue']?.retentionPolicy,
        LocalRetentionPolicy.persistUntilSynced,
      );
      expect(
        LocalDataPolicy.tablePolicyRegistry['sync_queue']?.retentionPolicy,
        LocalRetentionPolicy.persistUntilSynced,
      );
      expect(
        LocalDataPolicy.tablePolicyRegistry['local_checkins']?.retentionPolicy,
        LocalRetentionPolicy.persistUntilSynced,
      );
    });

    test('user content tables have persistUntilLogout retention', () {
      expect(
        LocalDataPolicy.tablePolicyRegistry['local_trips']?.retentionPolicy,
        LocalRetentionPolicy.persistUntilLogout,
      );
      expect(
        LocalDataPolicy.tablePolicyRegistry['local_profiles']?.retentionPolicy,
        LocalRetentionPolicy.persistUntilLogout,
      );
      expect(
        LocalDataPolicy.tablePolicyRegistry['local_user_scope']?.retentionPolicy,
        LocalRetentionPolicy.persistUntilLogout,
      );
    });
  });
}
