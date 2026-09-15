import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/config/app_config.dart';
import 'package:safemate/features/auth/domain/models/user_session.dart';

void main() {
  group('Security Baseline Tests', () {
    test('AppConfig does not expose service-role key or private secrets', () {
      // Rule #7: Service credentials must never be in client code
      expect(AppConfig.supabaseAnonKey, isNot(contains('service_role')));
      expect(AppConfig.supabaseAnonKey, isNot(contains('secret')));
    });

    test('UserSession model does not serialize sensitive authentication credentials', () {
      final session = UserSession(
        userId: 'test-user-id',
        email: 'traveler@example.com',
        role: 'user',
        createdAt: DateTime.now(),
      );

      final json = session.toJson();

      // Ensure no password, secret tokens, or internal security fields are in user session JSON
      expect(json.containsKey('password'), isFalse);
      expect(json.containsKey('password_hash'), isFalse);
      expect(json.containsKey('service_role'), isFalse);
    });
  });
}
