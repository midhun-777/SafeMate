/// SafeMate Connection View Model for presentation lists.
/// Universal Engineering Rule #6: Privacy-safe companion preview.
library;

import 'connection.dart';

class ConnectionItem {
  final Connection connection;
  final String companionUserId;
  final String companionName;
  final String? companionAvatarUrl;
  final int trustScore;
  final String destination;
  final String origin;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? compatibilityScore;
  final String? latestMessagePreview;
  final DateTime? latestMessageTime;
  final int unreadCount;
  final String? roomId;

  const ConnectionItem({
    required this.connection,
    required this.companionUserId,
    required this.companionName,
    this.companionAvatarUrl,
    required this.trustScore,
    required this.destination,
    required this.origin,
    this.startDate,
    this.endDate,
    this.compatibilityScore,
    this.latestMessagePreview,
    this.latestMessageTime,
    this.unreadCount = 0,
    this.roomId,
  });

  String get connectionId => connection.id;
  ConnectionRequestStatus get status => connection.requestStatus;
  bool get isPending => connection.isPending;
  bool get isAccepted => connection.isAccepted;
  bool get isDeclined => connection.isDeclined;
  bool get isCancelled => connection.isCancelled;
  bool get isBlocked => connection.isBlocked;
}
