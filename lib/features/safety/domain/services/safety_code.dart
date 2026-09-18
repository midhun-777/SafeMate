import 'dart:math';

/// Secure Meetup Verification Code generator and validator.
/// Universal Engineering Rule #11: Safety is a core product capability.
class SafetyMeetupCode {
  final String code;
  final DateTime generatedAt;
  final DateTime expiresAt;

  const SafetyMeetupCode({
    required this.code,
    required this.generatedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'generated_at': generatedAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  factory SafetyMeetupCode.fromJson(Map<String, dynamic> json) {
    return SafetyMeetupCode(
      code: json['code'] as String,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

class SafetyCodeService {
  static const int codeLength = 6;
  static const Duration defaultTtl = Duration(hours: 24);

  /// Generates a cryptographically secure 6-digit numeric meetup code.
  static SafetyMeetupCode generateCode({Duration ttl = defaultTtl}) {
    final rng = Random.secure();
    final buffer = StringBuffer();
    for (int i = 0; i < codeLength; i++) {
      buffer.write(rng.nextInt(10));
    }
    final now = DateTime.now();
    return SafetyMeetupCode(
      code: buffer.toString(),
      generatedAt: now,
      expiresAt: now.add(ttl),
    );
  }

  /// Verifies the entered code against the issued code, ensuring constant-time style check and TTL validity.
  static bool verifyCode({
    required String enteredCode,
    required SafetyMeetupCode meetupCode,
  }) {
    if (meetupCode.isExpired) {
      return false;
    }
    final cleanEntered = enteredCode.trim();
    final cleanActual = meetupCode.code.trim();

    if (cleanEntered.length != cleanActual.length) {
      return false;
    }

    int result = 0;
    for (int i = 0; i < cleanActual.length; i++) {
      result |= cleanEntered.codeUnitAt(i) ^ cleanActual.codeUnitAt(i);
    }
    return result == 0;
  }
}
