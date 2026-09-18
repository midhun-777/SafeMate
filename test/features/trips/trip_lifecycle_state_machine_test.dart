import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/trips/domain/models/trip_status.dart';

void main() {
  group('TripStatus Lifecycle State Machine Tests', () {
    test('DRAFT state transitions', () {
      expect(TripStatus.draft.canTransitionTo(TripStatus.published), isTrue);
      expect(TripStatus.draft.canTransitionTo(TripStatus.cancelled), isTrue);
      expect(TripStatus.draft.canTransitionTo(TripStatus.draft), isFalse);
      expect(TripStatus.draft.canTransitionTo(TripStatus.paused), isFalse);
      expect(TripStatus.draft.canTransitionTo(TripStatus.completed), isFalse);
    });

    test('PUBLISHED state transitions', () {
      expect(TripStatus.published.canTransitionTo(TripStatus.paused), isTrue);
      expect(TripStatus.published.canTransitionTo(TripStatus.cancelled), isTrue);
      expect(TripStatus.published.canTransitionTo(TripStatus.completed), isTrue);
      expect(TripStatus.published.canTransitionTo(TripStatus.published), isFalse);
      expect(TripStatus.published.canTransitionTo(TripStatus.draft), isFalse);
    });

    test('PAUSED state transitions', () {
      expect(TripStatus.paused.canTransitionTo(TripStatus.published), isTrue);
      expect(TripStatus.paused.canTransitionTo(TripStatus.cancelled), isTrue);
      expect(TripStatus.paused.canTransitionTo(TripStatus.paused), isFalse);
      expect(TripStatus.paused.canTransitionTo(TripStatus.completed), isFalse);
      expect(TripStatus.paused.canTransitionTo(TripStatus.draft), isFalse);
    });

    test('CANCELLED is a terminal state', () {
      for (final target in TripStatus.values) {
        expect(TripStatus.cancelled.canTransitionTo(target), isFalse);
      }
    });

    test('COMPLETED is a terminal state', () {
      for (final target in TripStatus.values) {
        expect(TripStatus.completed.canTransitionTo(target), isFalse);
      }
    });

    test('fromCode maps correctly and falls back safely', () {
      expect(TripStatus.fromCode('draft'), equals(TripStatus.draft));
      expect(TripStatus.fromCode('published'), equals(TripStatus.published));
      expect(TripStatus.fromCode('paused'), equals(TripStatus.paused));
      expect(TripStatus.fromCode('cancelled'), equals(TripStatus.cancelled));
      expect(TripStatus.fromCode('completed'), equals(TripStatus.completed));
      expect(TripStatus.fromCode('planned'), equals(TripStatus.draft));
      expect(TripStatus.fromCode('unknown_state'), equals(TripStatus.draft));
      expect(TripStatus.fromCode(null), equals(TripStatus.draft));
    });
  });
}
