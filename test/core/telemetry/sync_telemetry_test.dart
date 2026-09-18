import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/sync/sync_error_formatter.dart';
import 'package:safemate/core/sync/sync_models.dart';
import 'package:safemate/core/telemetry/sync_telemetry.dart';

void main() {
  late SyncTelemetryService telemetry;

  setUp(() {
    telemetry = SyncTelemetryService.instance;
    telemetry.clear();
  });

  group('Phase 12.5.11 & 12.5.12 — Observability & Error Taxonomy Tests', () {
    test('PRIVACY SCRUBBING: Passwords, tokens, raw GPS, Aadhaar and chat text are stripped from telemetry', () {
      telemetry.recordEvent(
        SyncTelemetryEvent.syncStarted,
        attributes: {
          'entity_type': 'trip',
          'password': 'secret_password_123',
          'auth_token': 'eyJh...jwt',
          'bearer': 'bearer_token_xyz',
          'user_aadhaar': '1234-5678-9012',
          'latitude': 35.6762,
          'longitude': 139.6503,
          'raw_gps': 'lat=35,lng=139',
          'chat_plaintext': 'My private chat message',
          'content': 'Secret trip notes',
          'queue_depth': 4,
        },
      );

      expect(telemetry.records.length, equals(1));
      final recordedAttrs = telemetry.records.first.attributes;

      // Safe metadata preserved
      expect(recordedAttrs['entity_type'], equals('trip'));
      expect(recordedAttrs['queue_depth'], equals(4));

      // Sensitive attributes strictly scrubbed
      expect(recordedAttrs.containsKey('password'), isFalse);
      expect(recordedAttrs.containsKey('auth_token'), isFalse);
      expect(recordedAttrs.containsKey('bearer'), isFalse);
      expect(recordedAttrs.containsKey('user_aadhaar'), isFalse);
      expect(recordedAttrs.containsKey('latitude'), isFalse);
      expect(recordedAttrs.containsKey('longitude'), isFalse);
      expect(recordedAttrs.containsKey('raw_gps'), isFalse);
      expect(recordedAttrs.containsKey('chat_plaintext'), isFalse);
      expect(recordedAttrs.containsKey('content'), isFalse);
    });

    test('COARSE BUCKETING: Queue depth and duration buckets remain bounded without granular leakage', () {
      expect(bucketQueueDepth(0), equals('0'));
      expect(bucketQueueDepth(3), equals('1-5'));
      expect(bucketQueueDepth(12), equals('6-20'));
      expect(bucketQueueDepth(35), equals('21-50'));
      expect(bucketQueueDepth(100), equals('50+'));

      expect(bucketDuration(const Duration(milliseconds: 400)), equals('<1s'));
      expect(bucketDuration(const Duration(milliseconds: 2500)), equals('1-5s'));
      expect(bucketDuration(const Duration(seconds: 15)), equals('5-30s'));
      expect(bucketDuration(const Duration(minutes: 2)), equals('30s-5m'));
      expect(bucketDuration(const Duration(minutes: 10)), equals('5m+'));
    });

    test('ERROR TAXONOMY: All internal classifications map to traveler-safe messages', () {
      final offlineMsg = SyncErrorFormatter.formatUserMessage(
        const FormatException('SocketException: Connection refused'),
      );
      expect(offlineMsg, contains("You're offline"));

      final authMsg = SyncErrorFormatter.formatUserMessage(
        const FormatException('401 Unauthorized'),
      );
      expect(authMsg, contains('Please sign in again'));

      final conflictMsg = SyncErrorFormatter.formatUserMessage(
        const FormatException('409 Conflict version mismatch'),
        entityName: 'trip',
      );
      expect(conflictMsg, contains('This trip changed while you were offline'));

      final notFoundMsg = SyncErrorFormatter.formatUserMessage(
        const FormatException('404 Not Found'),
        entityName: 'profile',
      );
      expect(notFoundMsg, contains('no longer available'));
    });

    test('AUTHORITY INVARIANT: isServerConfirmedSuccess is strictly false for offline/pending state', () {
      expect(SyncErrorFormatter.isServerConfirmedSuccess(SyncStatus.pending), isFalse);
      expect(SyncErrorFormatter.isServerConfirmedSuccess(SyncStatus.syncing), isFalse);
      expect(SyncErrorFormatter.isServerConfirmedSuccess(SyncStatus.conflict), isFalse);
      expect(SyncErrorFormatter.isServerConfirmedSuccess(SyncStatus.failed), isFalse);
      expect(SyncErrorFormatter.isServerConfirmedSuccess(SyncStatus.cancelled), isFalse);

      // Only confirmed synced status returns true
      expect(SyncErrorFormatter.isServerConfirmedSuccess(SyncStatus.synced), isTrue);
    });
  });
}
