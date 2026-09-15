import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/config/app_config.dart';

void main() {
  group('AppConfig Tests', () {
    test('AppConfig provides non-empty app name and version', () {
      expect(AppConfig.appName, equals('SafeMate'));
      expect(AppConfig.appVersion, isNotEmpty);
    });

    test('AppConfig defaults to development environment without define flags', () {
      expect(AppConfig.appEnv, equals('development'));
      expect(AppConfig.isDevelopment, isTrue);
      expect(AppConfig.isProduction, isFalse);
    });

    test('Placeholder configuration is detected as not having live Supabase backend', () {
      // In tests without --dart-define, placeholder values should be detected
      expect(AppConfig.hasValidSupabaseConfig, isFalse);
    });

    test('Feature flags have sensible safety defaults', () {
      expect(AppConfig.enablePassiveSafetyAlerts, isTrue);
      expect(AppConfig.enableJourneyCopilot, isFalse);
    });
  });
}
