import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safemate/core/database/database_exceptions.dart';
import 'package:safemate/core/database/database_models.dart';
import 'package:safemate/core/database/local_data_policy.dart';
import 'package:safemate/core/database/local_database.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/sync/conflict_models.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';

void main() {
  sqfliteFfiInit();

  group('Phase 12.4.1 Conflict Domain Model & Versioning Tests', () {
    late LocalDatabase localDb;
    late LocalDatabaseService dbService;

    setUp(() async {
      localDb = LocalDatabase();
      await localDb.open(
        databaseFactory: databaseFactoryFfi,
        dbName: 'version_meta_test_${DateTime.now().microsecondsSinceEpoch}.db',
      );

      dbService = LocalDatabaseService();
      await dbService.init(
        databaseFactory: databaseFactoryFfi,
        dbName: 'service_meta_test_${DateTime.now().microsecondsSinceEpoch}.db',
      );
    });

    tearDown(() async {
      if (localDb.isOpen) await localDb.close();
      if (dbService.isInitialized) await dbService.database.close();
    });

    // 1. Version Metadata Tests
    test('EntityVersionMetadata retains base, revision, and server version', () {
      final meta = EntityVersionMetadata(
        baseServerVersion: 3,
        localRevision: 2,
        lastSyncedServerVersion: 3,
        lastSyncedAt: DateTime(2026, 9, 17, 12, 0),
      );

      expect(meta.baseServerVersion, 3);
      expect(meta.localRevision, 2);
      expect(meta.lastSyncedServerVersion, 3);
      expect(meta.lastSyncedAt, isNotNull);

      final map = meta.toMap();
      final restored = EntityVersionMetadata.fromMap(map);
      expect(restored.baseServerVersion, 3);
      expect(restored.localRevision, 2);
      expect(restored.lastSyncedServerVersion, 3);
    });

    // 2. Server Version Authority: local revision must never override server version
    test('local revision does not modify server authority version', () {
      final trip = Trip(
        id: 'trip_v_01',
        userId: 'user_alice',
        origin: 'Berlin',
        destination: 'Munich',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 5),
        version: 5,
      );

      final localRecord = LocalTripRecord.fromDomain(
        trip,
        baseServerVersion: 5,
        localRevision: 3,
      );

      expect(localRecord.serverVersion, 5);
      expect(localRecord.baseServerVersion, 5);
      expect(localRecord.localRevision, 3);

      final map = localRecord.toMap();
      expect(map['server_version'], 5);
      expect(map['base_server_version'], 5);
      expect(map['local_revision'], 3);
    });

    test('UserProfile version metadata is preserved in LocalProfileRecord', () {
      final profile = UserProfile(
        id: 'user_prof_01',
        displayName: 'Alice Traveler',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        version: 4,
      );

      final record = LocalProfileRecord.fromDomain(
        profile,
        baseServerVersion: 4,
        localRevision: 1,
      );

      expect(record.serverVersion, 4);
      expect(record.baseServerVersion, 4);
      expect(record.localRevision, 1);
    });

    // 3. Stale Base Detection Primitives
    test('stale base primitive flags conflict when baseServerVersion < currentServerVersion', () {
      const localBaseVersion = 2;
      const remoteServerVersion = 3;

      final conflictType = (localBaseVersion < remoteServerVersion)
          ? ConflictType.staleBase
          : ConflictType.concurrentUpdate;

      expect(conflictType, ConflictType.staleBase);

      final conflict = SyncConflict(
        conflictId: 'conf_001',
        operationId: 'op_001',
        userId: 'user_bob',
        entityType: 'trip',
        entityId: 'trip_100',
        conflictType: conflictType,
        baseServerVersion: localBaseVersion,
        serverVersion: remoteServerVersion,
        localRevision: 1,
        localAction: 'update',
        serverAction: 'update',
        localTimestamp: DateTime.now(),
        serverTimestamp: DateTime.now(),
        conflictingFields: ['destination', 'budget'],
        detectedAt: DateTime.now(),
      );

      expect(conflict.conflictType, ConflictType.staleBase);
      expect(conflict.resolutionState, ConflictResolutionState.detected);
      expect(conflict.baseServerVersion, 2);
      expect(conflict.serverVersion, 3);
    });

    // 4. User Isolation in SyncConflict
    test('SyncConflict enforces valid userId and prevents empty owner', () {
      expect(
        () => SyncConflict(
          conflictId: 'conf_invalid',
          operationId: 'op_invalid',
          userId: '', // Invalid empty userId
          entityType: 'trip',
          entityId: 'trip_invalid',
          conflictType: ConflictType.concurrentUpdate,
          localAction: 'update',
          localTimestamp: DateTime.now(),
          detectedAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    // 5. Authoritative Profile Field Protection (Rule #3)
    test('LocalDataPolicy blocks client mutation of trust_score and authoritative fields', () {
      final maliciousPayload = {
        'display_name': 'Hacker',
        'trust_score': 100, // Prohibited client mutation
      };

      expect(
        () => LocalDataPolicy.assertNoAuthoritativeProfileFieldMutation(maliciousPayload),
        throwsA(isA<DatabasePolicyViolationException>()),
      );

      final safePayload = {
        'display_name': 'Legitimate Traveler',
        'bio': 'Exploring the mountains',
      };

      expect(
        () => LocalDataPolicy.assertNoAuthoritativeProfileFieldMutation(safePayload),
        returnsNormally,
      );
    });

    // 6. Itinerary Version Metadata Retention
    test('LocalItineraryRecord stores and retrieves server version and local revision', () async {
      final itinerary = LocalItineraryRecord(
        id: 'itin_001',
        tripId: 'trip_101',
        userId: 'user_alice',
        title: 'Alpine Tour',
        daysJson: '[{"day":1,"activity":"Hike"}]',
        serverVersion: 2,
        baseServerVersion: 2,
        localRevision: 1,
        updatedAt: DateTime.now(),
      );

      await dbService.saveItinerary(
        itinerary,
        baseServerVersion: 2,
        localRevision: 1,
      );

      final retrieved = await dbService.getItinerary('trip_101');
      expect(retrieved, isNotNull);
      expect(retrieved!.serverVersion, 2);
      expect(retrieved.baseServerVersion, 2);
      expect(retrieved.localRevision, 1);
      expect(retrieved.title, 'Alpine Tour');
    });

    // 7. Sync Queue Harmonization: Authoritative sync_queue supports versioning
    test('SyncRecord stores base_server_version and local_revision in harmonized queue', () async {
      final record = SyncRecord(
        operationId: 'op_sync_v2_001',
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_200',
        action: 'update',
        payload: {'destination': 'Zurich', 'version': 4},
        status: 'pending',
        createdAt: DateTime.now(),
        baseServerVersion: 4,
        localRevision: 2,
      );

      await dbService.enqueueSyncRecord(record);

      final pending = await dbService.getPendingSyncRecords('user_alice');
      expect(pending.isNotEmpty, isTrue);
      final stored = pending.firstWhere((r) => r.operationId == 'op_sync_v2_001');
      expect(stored.baseServerVersion, 4);
      expect(stored.localRevision, 2);
      expect(stored.entityType, 'trip');
    });

    // 8. Privacy Policy Enforcement: SyncConflict strips Category C / Sensitive keys
    test('SyncConflict sanitizes metadata and strips Category C and credential fields', () {
      final dirtyMetadata = {
        'comment': 'User modified budget',
        'auth_token': 'secret-jwt-token-12345',
        'password': 'plain_password',
        'aadhaar_number': '1234-5678-9012',
        'raw_gps_lat': 12.9716,
        'exact_gps_long': 77.5946,
        'secret_code': 'emergency-key',
      };

      final conflict = SyncConflict(
        conflictId: 'conf_sanitize_01',
        operationId: 'op_sanitize_01',
        userId: 'user_carol',
        entityType: 'trip',
        entityId: 'trip_300',
        conflictType: ConflictType.concurrentUpdate,
        localAction: 'update',
        localTimestamp: DateTime.now(),
        detectedAt: DateTime.now(),
        sanitizedMetadata: dirtyMetadata,
      );

      expect(conflict.sanitizedMetadata.containsKey('comment'), isTrue);
      expect(conflict.sanitizedMetadata.containsKey('auth_token'), isFalse);
      expect(conflict.sanitizedMetadata.containsKey('password'), isFalse);
      expect(conflict.sanitizedMetadata.containsKey('aadhaar_number'), isFalse);
      expect(conflict.sanitizedMetadata.containsKey('raw_gps_lat'), isFalse);
      expect(conflict.sanitizedMetadata.containsKey('exact_gps_long'), isFalse);
      expect(conflict.sanitizedMetadata.containsKey('secret_code'), isFalse);
    });
  });
}
