/// SafeMate Mesh Protocol Service (Experimental Prototype).
/// Universal Engineering Rule #6: Strict authentication and replay defense.
/// Universal Engineering Rule #18: Mesh does NOT provide an emergency dispatch guarantee.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/mesh_packet.dart';

/// Explicit status of a mesh message.
enum MeshDeliveryStatus {
  queued,
  receivedByPeer,
  pendingServerSync,
  rejected,
}

/// Service managing companion peer message relay, packet verification, and battery duty-cycling.
class MeshProtocolService {
  final Map<String, int> _lastSeenSequenceBySender = {};
  final Set<String> _seenMessageIds = {};
  final StreamController<MeshPacket> _incomingPacketController =
      StreamController<MeshPacket>.broadcast();

  bool _isDutyCycleActive = false;
  Timer? _dutyCycleTimer;

  Stream<MeshPacket> get incomingPackets => _incomingPacketController.stream;
  bool get isDutyCycleActive => _isDutyCycleActive;

  /// Starts duty-cycled scanning (5 seconds active scan, 30 seconds idle) to conserve battery.
  void startDutyCycledDiscovery() {
    _isDutyCycleActive = true;
    _dutyCycleTimer?.cancel();
    _dutyCycleTimer = Timer.periodic(const Duration(seconds: 35), (timer) {
      debugPrint('[SafeMate Mesh] Duty cycle active scan pulse (5s)...');
    });
  }

  /// Stops background scanning.
  void stopDiscovery() {
    _isDutyCycleActive = false;
    _dutyCycleTimer?.cancel();
    _dutyCycleTimer = null;
  }

  /// Processes an incoming raw packet received via peer transport.
  /// Validates signature, TTL, sequence monotonicity, and non-emergency invariant.
  MeshDeliveryStatus processIncomingPacket(MeshPacket packet, String companionSharedKey) {
    // 1. Emergency Payload Invariant: Mesh must NOT be used for fake emergency dispatch
    final normalized = packet.payload.toLowerCase();
    if (normalized.contains('emergency') ||
        normalized.contains('police') ||
        normalized.contains('911 dispatched') ||
        normalized.contains('evacuate')) {
      debugPrint('[SafeMate Mesh] Rejected packet containing prohibited emergency claims.');
      return MeshDeliveryStatus.rejected;
    }

    // 2. TTL Expiry Check
    if (packet.isExpired) {
      debugPrint('[SafeMate Mesh] Dropped expired packet: ${packet.messageId}');
      return MeshDeliveryStatus.rejected;
    }

    // 3. Replay Protection: Drop if already processed
    if (_seenMessageIds.contains(packet.messageId)) {
      debugPrint('[SafeMate Mesh] Replay attack detected / duplicate packet dropped: ${packet.messageId}');
      return MeshDeliveryStatus.rejected;
    }

    // 4. Monotonic Sequence Verification: Drop out-of-order or replayed sequence numbers
    final lastSeq = _lastSeenSequenceBySender[packet.senderId] ?? 0;
    if (packet.sequenceNumber <= lastSeq) {
      debugPrint('[SafeMate Mesh] Sequence regression detected for sender ${packet.senderId} ($packet.sequenceNumber <= $lastSeq). Dropping.');
      return MeshDeliveryStatus.rejected;
    }

    // 5. Cryptographic Signature Verification
    final isValid = MeshPacket.verifySignature(packet, companionSharedKey);
    if (!isValid) {
      debugPrint('[SafeMate Mesh] Signature verification failed for packet ${packet.messageId}. Dropping.');
      return MeshDeliveryStatus.rejected;
    }

    // Record sequence & ID
    _lastSeenSequenceBySender[packet.senderId] = packet.sequenceNumber;
    _seenMessageIds.add(packet.messageId);

    _incomingPacketController.add(packet);
    return MeshDeliveryStatus.receivedByPeer;
  }

  /// Packages a payload into an authenticated [MeshPacket] ready for peer transmission.
  MeshPacket createPacket({
    required String messageId,
    required String senderId,
    required String recipientId,
    required int sequenceNumber,
    required String payload,
    required String companionSharedKey,
  }) {
    final now = DateTime.now();
    final rawData = '$messageId:$senderId:$recipientId:$sequenceNumber:${now.toIso8601String()}:$payload';
    final signature = MeshPacket.generateSignature(rawData, companionSharedKey);

    return MeshPacket(
      messageId: messageId,
      senderId: senderId,
      recipientId: recipientId,
      sequenceNumber: sequenceNumber,
      timestamp: now,
      payload: payload,
      signature: signature,
    );
  }

  void dispose() {
    stopDiscovery();
    _incomingPacketController.close();
  }
}
