/// SafeMate Chat Domain Models for Phase 8 Realtime Communication.
/// Universal Engineering Rule #6: Strict domain boundaries, privacy-safe identity.
library;

enum MessageDeliveryStatus {
  pending,
  sent,
  delivered,
  read,
  failed;

  static MessageDeliveryStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'sent':
        return MessageDeliveryStatus.sent;
      case 'delivered':
        return MessageDeliveryStatus.delivered;
      case 'read':
        return MessageDeliveryStatus.read;
      case 'failed':
        return MessageDeliveryStatus.failed;
      case 'pending':
      case 'sending':
      default:
        return MessageDeliveryStatus.pending;
    }
  }

  String get dbValue {
    switch (this) {
      case MessageDeliveryStatus.pending:
        return 'pending';
      case MessageDeliveryStatus.sent:
        return 'sent';
      case MessageDeliveryStatus.delivered:
        return 'delivered';
      case MessageDeliveryStatus.read:
        return 'read';
      case MessageDeliveryStatus.failed:
        return 'failed';
    }
  }
}

enum MessageType {
  text;

  static MessageType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'text':
      default:
        return MessageType.text;
    }
  }
}

/// Represents a secure message within a chat room.
class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String clientMessageId;
  final MessageType messageType;
  final String content;
  final MessageDeliveryStatus deliveryStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.clientMessageId,
    this.messageType = MessageType.text,
    required this.content,
    this.deliveryStatus = MessageDeliveryStatus.pending,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  /// Alias for content
  String get body => content;

  bool get isDeleted => deletedAt != null;
  bool get isPending => deliveryStatus == MessageDeliveryStatus.pending;
  bool get isSent => deliveryStatus == MessageDeliveryStatus.sent;
  bool get isDelivered => deliveryStatus == MessageDeliveryStatus.delivered;
  bool get isRead => deliveryStatus == MessageDeliveryStatus.read;
  bool get isFailed => deliveryStatus == MessageDeliveryStatus.failed;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      senderId: json['sender_id'] as String,
      clientMessageId: (json['client_message_id'] ?? json['id']) as String,
      messageType: MessageType.fromString(json['message_type'] as String? ?? 'text'),
      content: json['content'] as String? ?? '',
      deliveryStatus: MessageDeliveryStatus.fromString(json['status'] as String? ?? 'sent'),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'sender_id': senderId,
      'client_message_id': clientMessageId,
      'message_type': 'text',
      'content': content,
      'status': deliveryStatus.dbValue,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? clientMessageId,
    MessageType? messageType,
    String? content,
    MessageDeliveryStatus? deliveryStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}

/// 1:1 Chat room associated with an accepted connection.
class ChatRoom {
  final String id;
  final String connectionId;
  final String roomType;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastMessageAt;

  const ChatRoom({
    required this.id,
    required this.connectionId,
    this.roomType = 'direct',
    this.status = 'active',
    required this.createdAt,
    this.updatedAt,
    this.lastMessageAt,
  });

  bool get isActive => status == 'active';

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] as String,
      connectionId: json['connection_id'] as String,
      roomType: json['room_type'] as String? ?? 'direct',
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'connection_id': connectionId,
      'room_type': roomType,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'last_message_at': lastMessageAt?.toIso8601String(),
    };
  }
}

/// Member of a chat room with read marker.
class ChatMember {
  final String id;
  final String roomId;
  final String userId;
  final String role;
  final DateTime lastReadAt;
  final bool isActive;
  final DateTime createdAt;

  const ChatMember({
    required this.id,
    required this.roomId,
    required this.userId,
    this.role = 'member',
    required this.lastReadAt,
    this.isActive = true,
    required this.createdAt,
  });

  factory ChatMember.fromJson(Map<String, dynamic> json) {
    return ChatMember(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'member',
      lastReadAt: json['last_read_at'] != null
          ? DateTime.parse(json['last_read_at'] as String)
          : DateTime.now(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'user_id': userId,
      'role': role,
      'last_read_at': lastReadAt.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
