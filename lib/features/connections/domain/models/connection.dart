/// SafeMate Mutual Companion Connection model.
/// State machine: requested -> accepted | rejected | cancelled | blocked.
class Connection {
  final String id;
  final String requesterId;
  final String receiverId;
  final String? tripId;
  final String status;
  final DateTime? acceptedAt;
  final DateTime createdAt;

  const Connection({
    required this.id,
    required this.requesterId,
    required this.receiverId,
    this.tripId,
    this.status = 'requested',
    this.acceptedAt,
    required this.createdAt,
  });

  bool get isAccepted => status == 'accepted';
  bool get isPending => status == 'requested';
  bool get isBlocked => status == 'blocked';

  factory Connection.fromJson(Map<String, dynamic> json) {
    return Connection(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      receiverId: json['receiver_id'] as String,
      tripId: json['trip_id'] as String?,
      status: json['status'] as String? ?? 'requested',
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requester_id': requesterId,
      'receiver_id': receiverId,
      'trip_id': tripId,
      'status': status,
      'accepted_at': acceptedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
