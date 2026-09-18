import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/connections/domain/models/connection.dart';

void main() {
  group('Connection Model Tests', () {
    test('Connection status flags report correct state', () {
      final requestedConn = Connection(
        id: 'conn-1',
        requesterId: 'user-1',
        receiverId: 'user-2',
        status: 'requested',
        createdAt: DateTime.now(),
      );

      expect(requestedConn.isPending, isTrue);
      expect(requestedConn.isAccepted, isFalse);
      expect(requestedConn.isBlocked, isFalse);

      final acceptedConn = Connection(
        id: 'conn-2',
        requesterId: 'user-1',
        receiverId: 'user-2',
        status: 'accepted',
        acceptedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(acceptedConn.isAccepted, isTrue);
      expect(acceptedConn.isPending, isFalse);

      final declinedConn = Connection(
        id: 'conn-3',
        requesterId: 'user-1',
        receiverId: 'user-2',
        status: 'declined',
        createdAt: DateTime.now(),
      );
      expect(declinedConn.isDeclined, isTrue);

      final cancelledConn = Connection(
        id: 'conn-4',
        requesterId: 'user-1',
        receiverId: 'user-2',
        status: 'cancelled',
        createdAt: DateTime.now(),
      );
      expect(cancelledConn.isCancelled, isTrue);

      final blockedConn = Connection(
        id: 'conn-5',
        requesterId: 'user-1',
        receiverId: 'user-2',
        status: 'blocked',
        createdAt: DateTime.now(),
      );
      expect(blockedConn.isBlocked, isTrue);
    });

    test('Connection JSON serialization handles null acceptedAt and Phase 8 fields', () {
      final conn = Connection(
        id: 'conn-3',
        requesterId: 'user-a',
        receiverId: 'user-b',
        tripId: 'trip-100',
        requesterTripId: 'trip-100',
        recipientTripId: 'trip-200',
        status: 'requested',
        createdAt: DateTime(2026, 9, 15),
      );

      final json = conn.toJson();
      final fromJson = Connection.fromJson(json);

      expect(fromJson.id, equals(conn.id));
      expect(fromJson.requesterId, equals(conn.requesterId));
      expect(fromJson.receiverId, equals(conn.receiverId));
      expect(fromJson.tripId, equals(conn.tripId));
      expect(fromJson.requesterTripId, equals('trip-100'));
      expect(fromJson.recipientTripId, equals('trip-200'));
      expect(fromJson.status, equals('requested'));
      expect(fromJson.acceptedAt, isNull);
    });

    test('normalizedPairKey is symmetric for (userA, userB) and (userB, userA)', () {
      final conn1 = Connection(
        id: 'c1',
        requesterId: 'alice',
        receiverId: 'bob',
        createdAt: DateTime.now(),
      );
      final conn2 = Connection(
        id: 'c2',
        requesterId: 'bob',
        receiverId: 'alice',
        createdAt: DateTime.now(),
      );

      expect(conn1.normalizedPairKey, equals(conn2.normalizedPairKey));
      expect(conn1.normalizedPairKey, equals('alice_bob'));
    });
  });
}
