import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/database/local_database_service.dart';
import 'package:safemate/core/sync/conflict_models.dart';
import 'package:safemate/core/sync/conflict_resolution_controller.dart';
import 'package:safemate/core/sync/presentation/conflict_banner.dart';
import 'package:safemate/core/sync/presentation/conflict_review_screen.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';

class MockLocalDatabaseService extends LocalDatabaseService {
  final List<SyncRecord> records = [];

  @override
  Future<SyncRecord?> getSyncRecord(String operationId) async {
    try {
      return records.firstWhere((r) => r.operationId == operationId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> enqueueSyncRecord(SyncRecord record) async {
    records.removeWhere((r) => r.operationId == record.operationId);
    records.add(record);
  }

  @override
  Future<void> deleteSyncRecord(String operationId) async {
    records.removeWhere((r) => r.operationId == operationId);
  }

  @override
  Future<List<SyncRecord>> getConflictSyncRecords(String userId) async {
    return records.where((r) => r.userId == userId && r.status == 'conflict').toList();
  }

  @override
  Future<void> updateSyncRecordStatus(
    String operationId,
    String status, {
    int? retryCount,
    DateTime? lastAttemptAt,
    String? errorMessage,
  }) async {
    final idx = records.indexWhere((r) => r.operationId == operationId);
    if (idx != -1) {
      records[idx] = records[idx].copyWith(status: status);
    }
  }

  @override
  Future<Trip?> getTrip(String id) async => null;

  @override
  Future<void> saveTrip(Trip trip, {int? baseServerVersion, int? localRevision}) async {}

  @override
  Future<UserProfile?> getProfile(String userId) async => null;

  @override
  Future<void> saveProfile(UserProfile profile, {int? baseServerVersion, int? localRevision}) async {}
}

void main() {
  group('Phase 12.4.4 Conflict UI & Review Widget Tests', () {
    testWidgets('ConflictBanner: hides when conflict count is zero', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictBanner(
              conflictCount: 0,
              onReviewPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(Card), findsNothing);
      expect(find.text('Review'), findsNothing);
    });

    testWidgets('ConflictBanner: displays warning and triggers callback on Review', (tester) async {
      bool reviewed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictBanner(
              conflictCount: 3,
              onReviewPressed: () {
                reviewed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('3 updates require review'), findsOneWidget);
      expect(find.byIcon(Icons.sync_problem_rounded), findsOneWidget);

      await tester.tap(find.text('Review'));
      await tester.pump();

      expect(reviewed, isTrue);
    });

    testWidgets('ConflictBanner: compact mode displays count and icon', (tester) async {
      bool reviewed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictBanner(
              conflictCount: 1,
              isCompact: true,
              onReviewPressed: () {
                reviewed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('1 conflict'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      await tester.tap(find.text('1 conflict'));
      await tester.pump();

      expect(reviewed, isTrue);
    });

    testWidgets('ConflictReviewScreen: displays empty state when all conflicts resolved', (tester) async {
      final mockDb = MockLocalDatabaseService();
      final controller = ConflictResolutionController(localDb: mockDb);

      await tester.pumpWidget(
        MaterialApp(
          home: ConflictReviewScreen(
            conflicts: const [],
            userId: 'user_alice',
            controller: controller,
          ),
        ),
      );

      expect(find.text('All Caught Up!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('ConflictReviewScreen: displays standard trip conflict and exposes Keep My Changes', (tester) async {
      final mockDb = MockLocalDatabaseService();
      const opId = 'op_trip_conflict_1';
      mockDb.records.add(SyncRecord(
        operationId: opId,
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_100',
        action: 'update',
        payload: {'budget': 1500, 'title': 'Mountain Trek'},
        status: 'conflict',
        createdAt: DateTime.now(),
      ));

      final controller = ConflictResolutionController(localDb: mockDb);
      final syncConflict = SyncConflict(
        conflictId: 'conf_1',
        operationId: opId,
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_100',
        conflictType: ConflictType.concurrentUpdate,
        localAction: 'update',
        localTimestamp: DateTime.now(),
        detectedAt: DateTime.now(),
        conflictingFields: ['budget'],
      );

      final model = controller.buildPresentationModel(
        syncConflict,
        localValues: {'budget': 1500},
        serverValues: {'budget': 2000},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ConflictReviewScreen(
            conflicts: [model],
            userId: 'user_alice',
            controller: controller,
          ),
        ),
      );

      // Verify header, diff card, values
      expect(find.text('TRIP'), findsOneWidget);
      expect(find.text('Differences Detected'), findsOneWidget);
      expect(find.text('budget'), findsOneWidget);
      expect(find.text('1500'), findsOneWidget);
      expect(find.text('2000'), findsOneWidget);

      // Standard trip allows Keep My Changes
      expect(find.text('Keep My Changes'), findsOneWidget);
      expect(find.text('Use Latest Version'), findsOneWidget);

      // Tap Use Latest Version -> resolves and empties queue
      await tester.tap(find.text('Use Latest Version'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('All Caught Up!'), findsOneWidget);
      expect(mockDb.records.isEmpty, isTrue);
    });

    testWidgets('ConflictReviewScreen: Keep My Changes requeues mutation to pending', (tester) async {
      final mockDb = MockLocalDatabaseService();
      const opId = 'op_trip_conflict_2';
      mockDb.records.add(SyncRecord(
        operationId: opId,
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_200',
        action: 'update',
        payload: {'description': 'Offline edited trip plan'},
        status: 'conflict',
        createdAt: DateTime.now(),
      ));

      final controller = ConflictResolutionController(localDb: mockDb);
      final syncConflict = SyncConflict(
        conflictId: 'conf_2',
        operationId: opId,
        userId: 'user_alice',
        entityType: 'trip',
        entityId: 'trip_200',
        conflictType: ConflictType.concurrentUpdate,
        localAction: 'update',
        localTimestamp: DateTime.now(),
        detectedAt: DateTime.now(),
        conflictingFields: ['description'],
      );

      final model = controller.buildPresentationModel(
        syncConflict,
        localValues: {'description': 'Offline edited trip plan'},
        serverValues: {'description': 'Remote edited trip plan'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ConflictReviewScreen(
            conflicts: [model],
            userId: 'user_alice',
            controller: controller,
          ),
        ),
      );

      // Tap Keep My Changes
      await tester.tap(find.text('Keep My Changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('All Caught Up!'), findsOneWidget);
      expect(mockDb.records.first.status, equals('pending'));
    });

    testWidgets('ConflictReviewScreen: authoritative field conflict hides Keep My Changes and shows badge', (tester) async {
      final mockDb = MockLocalDatabaseService();
      final controller = ConflictResolutionController(localDb: mockDb);
      final authConflict = SyncConflict(
        conflictId: 'conf_profile_1',
        operationId: 'op_prof_1',
        userId: 'user_bob',
        entityType: 'profile',
        entityId: 'user_bob',
        conflictType: ConflictType.permissionChanged,
        localAction: 'update',
        localTimestamp: DateTime.now(),
        detectedAt: DateTime.now(),
        conflictingFields: ['trust_score'],
      );

      final model = controller.buildPresentationModel(
        authConflict,
        localValues: {'trust_score': 95},
        serverValues: {'trust_score': 80},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ConflictReviewScreen(
            conflicts: [model],
            userId: 'user_bob',
            controller: controller,
          ),
        ),
      );

      // Verify Server Authority badge is shown
      expect(find.text('PROFILE'), findsOneWidget);
      expect(find.text('Server Authority'), findsOneWidget);
      expect(find.text('trust score'), findsOneWidget);

      // Verify "Keep My Changes" is strictly hidden
      expect(find.text('Keep My Changes'), findsNothing);

      // Dismiss / Accept server
      expect(find.text('Dismiss'), findsOneWidget);
    });
  });
}
