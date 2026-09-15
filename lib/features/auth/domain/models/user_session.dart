/// SafeMate User Session model.
/// Separates authentication identity from application profile (Universal Engineering Rule #10 & #13).
class UserSession {
  final String userId;
  final String email;
  final String? phone;
  final String role; // 'user', 'moderator', 'admin'
  final bool isSuspended;
  final DateTime createdAt;

  const UserSession({
    required this.userId,
    required this.email,
    this.phone,
    this.role = 'user',
    this.isSuspended = false,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin' || role == 'moderator';

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      userId: json['id'] as String,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'user',
      isSuspended: json['is_suspended'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': userId,
      'email': email,
      'phone': phone,
      'role': role,
      'is_suspended': isSuspended,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
