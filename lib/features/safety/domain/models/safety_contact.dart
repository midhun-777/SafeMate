/// SafeMate Trusted Emergency Contact model.
/// Universal Engineering Rule #11: Safety is a core product capability.
class SafetyContact {
  final String id;
  final String userId;
  final String contactName;
  final String phoneNumber;
  final String? email;
  final String relationship;
  final bool isActive;
  final bool notifyOnTripStart;
  final DateTime createdAt;

  const SafetyContact({
    required this.id,
    required this.userId,
    required this.contactName,
    required this.phoneNumber,
    this.email,
    required this.relationship,
    this.isActive = true,
    this.notifyOnTripStart = true,
    required this.createdAt,
  });

  factory SafetyContact.fromJson(Map<String, dynamic> json) {
    return SafetyContact(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      contactName: json['contact_name'] as String,
      phoneNumber: json['phone_number'] as String,
      email: json['email'] as String?,
      relationship: json['relationship'] as String,
      isActive: json['is_active'] as bool? ?? true,
      notifyOnTripStart: json['notify_on_trip_start'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'contact_name': contactName,
      'phone_number': phoneNumber,
      'email': email,
      'relationship': relationship,
      'is_active': isActive,
      'notify_on_trip_start': notifyOnTripStart,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
