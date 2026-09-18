import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/sync/sync_engine.dart';
import 'package:safemate/core/sync/sync_status_indicator.dart';

void main() {
  group('Phase 12.3 SyncStatusIndicator Widget Tests (12.3.20 & 12.3.21)', () {
    testWidgets('Renders syncing state with progress indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SyncStatusIndicator(status: SyncEngineStatus.syncing),
          ),
        ),
      );

      expect(find.text('Syncing...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Renders offline state with saved on device message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SyncStatusIndicator(status: SyncEngineStatus.offline),
          ),
        ),
      );

      expect(find.text('Offline — saved on device'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });

    testWidgets('Sync now button triggers callback when tapped', (tester) async {
      bool syncNowTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyncStatusIndicator(
              status: SyncEngineStatus.idle,
              onSyncNow: () {
                syncNowTapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Sync now'), findsOneWidget);
      await tester.tap(find.text('Sync now'));
      await tester.pump();

      expect(syncNowTapped, isTrue);
    });

    testWidgets('Compact mode renders icon with tooltip', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SyncStatusIndicator(
              status: SyncEngineStatus.idle,
              isCompact: true,
            ),
          ),
        ),
      );

      expect(find.byType(Tooltip), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });
  });
}
