/// SafeMate Mutual Companion Connection model.
/// Universal Engineering Rule #6: Strict domain boundaries, privacy-safe identity.
/// State machine: pending (requested) -> accepted | declined (rejected) | cancelled | blocked.
library;

enum ConnectionRequestStatus {
  pending,
  accepted,
  declined,
  cancelled,
  blocked;

  static ConnectionRequestStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return ConnectionRequestStatus.accepted;
      case 'declined':
      case 'rejected':
        return ConnectionRequestStatus.declined;
      case 'cancelled':
      case 'canceled':
        return ConnectionRequestStatus.cancelled;
      case 'blocked':
        return ConnectionRequestStatus.blocked;
      case 'pending':
      case 'requested':
      default:
        return ConnectionRequestStatus.pending;
    }
  }

  String get dbValue {
    switch (this) {
      case ConnectionRequestStatus.accepted:
        return 'accepted';
      case ConnectionRequestStatus.declined:
        return 'declined';
      case ConnectionRequestStatus.cancelled:
        return 'cancelled';
      case ConnectionRequestStatus.blocked:
        return 'blocked';
      case ConnectionRequestStatus.pending:
        return 'pending';
    }
  }
}

class Connection {
  final String id;
  final String requesterId;
  final String receiverId;
  final String? tripId;
  final String? requesterTripId;
  final String? recipientTripId;
  final String status;
  final DateTime? acceptedAt;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Connection({
    required this.id,
    required this.requesterId,
    required this.receiverId,
    this.tripId,
    this.requesterTripId,
    this.recipientTripId,
    this.status = 'pending',
    this.acceptedAt,
    this.respondedAt,
    required this.createdAt,
    this.updatedAt,
  });

  ConnectionRequestStatus get requestStatus =>
      ConnectionRequestStatus.fromString(status);

  bool get isAccepted => requestStatus == ConnectionRequestStatus.accepted;
  bool get isPending => requestStatus == ConnectionRequestStatus.pending;
  bool get isDeclined => requestStatus == ConnectionRequestStatus.declined;
  bool get isCancelled => requestStatus == ConnectionRequestStatus.cancelled;
  bool get isBlocked => requestStatus == ConnectionRequestStatus.blocked;

  /// Normalized user pair key ensuring A+B and B+A are compared identically.
  String get normalizedPairKey {
    final list = [requesterId, receiverId]..sort();
    return '${list[0]}_${list[1]}';
  }

  factory Connection.fromJson(Map<String, dynamic> json) {
    return Connection(
      id: json['id'] as String,
      requesterId: (json['requester_id'] ?? json['requester_user_id']) as String,
      receiverId: (json['receiver_id'] ?? json['recipient_user_id']) as String,
      tripId: (json['trip_id'] ?? json['requester_trip_id']) as String?,
      requesterTripId: (json['requester_trip_id'] ?? json['trip_id']) as String?,
      recipientTripId: json['recipient_trip_id'] as String?,
      status: json['status'] as String? ?? 'pending',
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requester_id': requesterId,
      'receiver_id': receiverId,
      'trip_id': tripId ?? requesterTripId,
      'requester_trip_id': requesterTripId ?? tripId,
      'recipient_trip_id': recipientTripId,
      'status': status,
      'accepted_at': acceptedAt?.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Connection copyWith({
    String? id,
    String? requesterId,
    String? receiverId,
    String? tripId,
    String? requesterTripId,
    String? recipientTripId,
    String? status,
    DateTime? acceptedAt,
    DateTime? respondedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Connection(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      receiverId: receiverId ?? this.receiverId,
      tripId: tripId ?? this.tripId,
      requesterTripId: requesterTripId ?? this.requesterTripId,
      recipientTripId: recipientTripId ?? this.recipientTripId,
      status: status ?? this.status,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      respondedAt: respondedAt ?? this.respondedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
