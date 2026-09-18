import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/mesh/domain/models/mesh_packet.dart';
import 'package:safemate/features/mesh/domain/services/mesh_protocol_service.dart';

void main() {
  group('Phase 12.15 - 12.17 MeshProtocolService Tests', () {
    late MeshProtocolService meshService;
    const sharedKey = 'companion_super_secret_shared_key_123';

    setUp(() {
      meshService = MeshProtocolService();
    });

    tearDown(() {
      meshService.dispose();
    });

    test('Creates authenticated packet and processes successfully with matching key', () {
      final MeshPacket packet = meshService.createPacket(
        messageId: 'msg_mesh_001',
        senderId: 'user_alice',
        recipientId: 'user_bob',
        sequenceNumber: 1,
        payload: 'Meet at the train platform',
        companionSharedKey: sharedKey,
      );

      final status = meshService.processIncomingPacket(packet, sharedKey);
      expect(status, MeshDeliveryStatus.receivedByPeer);
    });

    test('Rejects packet with invalid cryptographic signature', () {
      final MeshPacket packet = meshService.createPacket(
        messageId: 'msg_mesh_002',
        senderId: 'user_alice',
        recipientId: 'user_bob',
        sequenceNumber: 1,
        payload: 'Meet at cafe',
        companionSharedKey: sharedKey,
      );

      // Processing with wrong companion key
      final status = meshService.processIncomingPacket(packet, 'wrong_key');
      expect(status, MeshDeliveryStatus.rejected);
    });

    test('Replay Protection: Rejects duplicate message ID', () {
      final MeshPacket packet = meshService.createPacket(
        messageId: 'msg_mesh_replay',
        senderId: 'user_alice',
        recipientId: 'user_bob',
        sequenceNumber: 1,
        payload: 'Message 1',
        companionSharedKey: sharedKey,
      );

      final firstPass = meshService.processIncomingPacket(packet, sharedKey);
      expect(firstPass, MeshDeliveryStatus.receivedByPeer);

      // Second replay attempt with identical packet
      final replayPass = meshService.processIncomingPacket(packet, sharedKey);
      expect(replayPass, MeshDeliveryStatus.rejected);
    });

    test('Sequence Regression Protection: Rejects lower or equal sequence numbers', () {
      final MeshPacket packet1 = meshService.createPacket(
        messageId: 'msg_mesh_seq_1',
        senderId: 'user_alice',
        recipientId: 'user_bob',
        sequenceNumber: 5,
        payload: 'Seq 5',
        companionSharedKey: sharedKey,
      );
      meshService.processIncomingPacket(packet1, sharedKey);

      // Packet with regression in sequence number (e.g. 4 <= 5)
      final MeshPacket packet2 = meshService.createPacket(
        messageId: 'msg_mesh_seq_2',
        senderId: 'user_alice',
        recipientId: 'user_bob',
        sequenceNumber: 4,
        payload: 'Seq 4 (regression)',
        companionSharedKey: sharedKey,
      );
      final status = meshService.processIncomingPacket(packet2, sharedKey);
      expect(status, MeshDeliveryStatus.rejected);
    });

    test('Rejects emergency panic claims or simulated police dispatch', () {
      final MeshPacket packet = meshService.createPacket(
        messageId: 'msg_mesh_emergency',
        senderId: 'user_alice',
        recipientId: 'user_bob',
        sequenceNumber: 1,
        payload: '911 DISPATCHED to your location immediately',
        companionSharedKey: sharedKey,
      );

      final status = meshService.processIncomingPacket(packet, sharedKey);
      expect(status, MeshDeliveryStatus.rejected);
    });

    test('Duty cycling toggle starts and stops timer cleanly', () {
      meshService.startDutyCycledDiscovery();
      expect(meshService.isDutyCycleActive, isTrue);

      meshService.stopDiscovery();
      expect(meshService.isDutyCycleActive, isFalse);
    });
  });
}
