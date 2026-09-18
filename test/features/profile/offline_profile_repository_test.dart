import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/sync/sync_engine.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/profile/data/repositories/offline_first_profile_repository.dart';
import 'package:safemate/features/profile/data/repositories/supabase_profile_repository.dart';

void main() {
  sqfliteFfiInit();

  late LocalDatabaseService localDb;
  late SyncEngine syncEngine;
  late SupabaseProfileRepository remoteRepo;
  late OfflineFirstProfileRepository offlineRepo;

  setUp(() async {
    localDb = LocalDatabaseService();
    await localDb.initialize(
      databaseFactory: databaseFactoryFfi,
      dbName: 'offline_profile_repo_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    syncEngine = SyncEngine(localDb: localDb);
    remoteRepo = SupabaseProfileRepository();
    offlineRepo = OfflineFirstProfileRepository(
      remoteRepo: remoteRepo,
      localDb: localDb,
      syncEngine: syncEngine,
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await localDb.close();
  });

  group('Phase 12.3 OfflineFirstProfileRepository Tests (12.3.13)', () {
    test('Saves approved profile edits locally and preserves server verification authority', () async {
      final unverifiedProfile = UserProfile(
        id: 'user_profile_1',
        displayName: 'Sam Traveler',
        bio: 'Solo backpacker exploring Japan.',
        isVerified: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Attempt to save profile claiming isVerified = true locally
      final rogueClientProfile = unverifiedProfile.copyWith(isVerified: true);
      final saved = await offlineRepo.saveProfile(rogueClientProfile);

      // Client cannot self-promote to verified offline
      expect(saved.isVerified, isFalse, reason: 'Verification authority rests solely with server');
      expect(saved.displayName, equals('Sam Traveler'));

      // Check SQLite record
      final cached = await localDb.getProfile('user_profile_1');
      expect(cached, isNotNull);
      expect(cached!.displayName, equals('Sam Traveler'));
      expect(cached.bio, equals('Solo backpacker exploring Japan.'));
      expect(cached.isVerified, isFalse);
    });

    test('getProfile returns cached profile immediately without network delay', () async {
      final initialProfile = UserProfile(
        id: 'user_cached_profile',
        displayName: 'Elena Swift',
        bio: 'Architect & cultural traveler',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await localDb.saveProfile(initialProfile);

      final result = await offlineRepo.getProfile('user_cached_profile');
      expect(result, isNotNull);
      expect(result!.displayName, equals('Elena Swift'));
    });
  });
}
