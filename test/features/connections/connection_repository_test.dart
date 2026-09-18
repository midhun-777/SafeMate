import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/connections/data/repositories/supabase_connection_repository.dart';

void main() {
  group('SupabaseConnectionRepository Tests', () {
    late SupabaseConnectionRepository repo;

    setUp(() {
      repo = SupabaseConnectionRepository();
      repo.seedDevProfile('user-alex', {
        'id': 'user-alex',
        'display_name': 'Alex Rivera',
        'avatar_url': null,
        'trust_score': 85,
      });
      repo.seedDevProfile('user-sam', {
        'id': 'user-sam',
        'display_name': 'Sam Chen',
        'avatar_url': null,
        'trust_score': 90,
      });
      repo.seedDevTrip('trip-1', {
        'id': 'trip-1',
        'origin': 'Tokyo',
        'destination': 'Kyoto',
        'start_date': '2026-10-01T00:00:00.000Z',
        'end_date': '2026-10-08T00:00:00.000Z',
      });
    });

    test('send, find, and accept connection request flow', () async {
      // 1. Send request
      final conn = await repo.sendConnectionRequest(
        requesterId: 'user-alex',
        receiverId: 'user-sam',
        requesterTripId: 'trip-1',
      );

      expect(conn.id, isNotEmpty);
      expect(conn.isPending, isTrue);
      expect(conn.requesterId, equals('user-alex'));
      expect(conn.receiverId, equals('user-sam'));

      // 2. Find active request
      final active = await repo.findActiveRequestBetween(
        requesterId: 'user-alex',
        receiverId: 'user-sam',
      );
      expect(active, isNotNull);
      expect(active?.id, equals(conn.id));

      // 3. Check received requests for Sam
      final received = await repo.getPendingRequestsReceived('user-sam');
      expect(received.length, equals(1));
      expect(received.first.companionName, equals('Alex Rivera'));

      // 4. Check sent requests for Alex
      final sent = await repo.getPendingRequestsSent('user-alex');
      expect(sent.length, equals(1));
      expect(sent.first.companionName, equals('Sam Chen'));

      // 5. Accept request
      final accepted = await repo.acceptConnectionRequest(
        requestId: conn.id,
        receiverId: 'user-sam',
      );
      expect(accepted.isAccepted, isTrue);
      expect(accepted.acceptedAt, isNotNull);

      // 6. Check active connections
      final alexActive = await repo.getActiveConnections('user-alex');
      expect(alexActive.length, equals(1));
      expect(alexActive.first.isAccepted, isTrue);

      final samActive = await repo.getActiveConnections('user-sam');
      expect(samActive.length, equals(1));
      expect(samActive.first.isAccepted, isTrue);
    });

    test('decline and cancel connection request flows', () async {
      // Decline flow
      final conn1 = await repo.sendConnectionRequest(
        requesterId: 'user-alex',
        receiverId: 'user-sam',
        requesterTripId: 'trip-1',
      );
      final declined = await repo.declineConnectionRequest(
        requestId: conn1.id,
        receiverId: 'user-sam',
      );
      expect(declined.isDeclined, isTrue);

      final past = await repo.getPastConnections('user-alex');
      expect(past.length, equals(1));
      expect(past.first.isDeclined, isTrue);

      // Cancel flow (new request allowed since first is declined)
      final conn2 = await repo.sendConnectionRequest(
        requesterId: 'user-alex',
        receiverId: 'user-sam',
        requesterTripId: 'trip-1',
      );
      final cancelled = await repo.cancelConnectionRequest(
        requestId: conn2.id,
        requesterId: 'user-alex',
      );
      expect(cancelled.isCancelled, isTrue);
    });

    test('blockConnection terminates active connection and marks blocked', () async {
      final conn = await repo.sendConnectionRequest(
        requesterId: 'user-alex',
        receiverId: 'user-sam',
        requesterTripId: 'trip-1',
      );
      await repo.acceptConnectionRequest(requestId: conn.id, receiverId: 'user-sam');

      // Alex blocks Sam
      await repo.blockConnection(blockerId: 'user-alex', blockedId: 'user-sam');

      final updated = await repo.getConnection(conn.id);
      expect(updated?.isBlocked, isTrue);

      // Subsequent send request should fail
      expect(
        () => repo.sendConnectionRequest(
          requesterId: 'user-alex',
          receiverId: 'user-sam',
          requesterTripId: 'trip-1',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
