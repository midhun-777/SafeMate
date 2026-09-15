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
    });

    test('Connection JSON serialization handles null acceptedAt', () {
      final conn = Connection(
        id: 'conn-3',
        requesterId: 'user-a',
        receiverId: 'user-b',
        tripId: 'trip-100',
        status: 'requested',
        createdAt: DateTime(2026, 9, 15),
      );

      final json = conn.toJson();
      final fromJson = Connection.fromJson(json);

      expect(fromJson.id, equals(conn.id));
      expect(fromJson.requesterId, equals(conn.requesterId));
      expect(fromJson.receiverId, equals(conn.receiverId));
      expect(fromJson.tripId, equals(conn.tripId));
      expect(fromJson.status, equals('requested'));
      expect(fromJson.acceptedAt, isNull);
    });
  });
}
