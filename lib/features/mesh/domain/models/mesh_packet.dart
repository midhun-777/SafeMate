/// SafeMate Mesh Protocol Packet Definition.
/// Universal Engineering Rule #6: Cryptographic signatures and replay defense.
/// Universal Engineering Rule #18: Zero emergency claims in mesh networking.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart' if (dart.library.io) 'package:crypto/crypto.dart';

/// Cryptographically signed packet for experimental peer-to-peer companion mesh relay.
class MeshPacket {
  final String messageId;
  final String senderId;
  final String recipientId;
  final int sequenceNumber;
  final DateTime timestamp;
  final int ttlSeconds;
  final String payload;
  final String signature;

  const MeshPacket({
    required this.messageId,
    required this.senderId,
    required this.recipientId,
    required this.sequenceNumber,
    required this.timestamp,
    this.ttlSeconds = 300, // 5 minutes default TTL
    required this.payload,
    required this.signature,
  });

  bool get isExpired {
    return DateTime.now().difference(timestamp).inSeconds > ttlSeconds;
  }

  Map<String, dynamic> toMap() {
    return {
      'message_id': messageId,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'sequence_number': sequenceNumber,
      'timestamp': timestamp.toIso8601String(),
      'ttl_seconds': ttlSeconds,
      'payload': payload,
      'signature': signature,
    };
  }

  factory MeshPacket.fromMap(Map<String, dynamic> map) {
    return MeshPacket(
      messageId: map['message_id'] as String,
      senderId: map['sender_id'] as String,
      recipientId: map['recipient_id'] as String,
      sequenceNumber: (map['sequence_number'] as num).toInt(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      ttlSeconds: (map['ttl_seconds'] as num?)?.toInt() ?? 300,
      payload: map['payload'] as String,
      signature: map['signature'] as String,
    );
  }

  /// Verifies packet signature with companion shared secret.
  static bool verifySignature(MeshPacket packet, String sharedKey) {
    final rawData = '${packet.messageId}:${packet.senderId}:${packet.recipientId}:${packet.sequenceNumber}:${packet.timestamp.toIso8601String()}:${packet.payload}';
    final expectedSignature = generateSignature(rawData, sharedKey);
    return expectedSignature == packet.signature;
  }

  /// Computes HMAC-SHA256 signature for mesh data.
  static String generateSignature(String data, String sharedKey) {
    final keyBytes = utf8.encode(sharedKey);
    final dataBytes = utf8.encode(data);
    final hmac = Hmac(sha256, keyBytes);
    return hmac.convert(dataBytes).toString();
  }
}
