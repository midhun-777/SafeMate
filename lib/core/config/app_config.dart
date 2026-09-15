/// Application configuration loader for SafeMate.
/// Reads configuration from compile-time environment definitions (--dart-define).
/// Ensures zero secrets are hardcoded into source code.
class AppConfig {
  const AppConfig._();

  static const String appName = 'SafeMate';
  static const String appVersion = '1.0.0';

  /// Environment name: development, staging, production
  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  /// Supabase project URL
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://placeholder-safemate.supabase.co',
  );

  /// Supabase public anonymous key (governed by Row Level Security)
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'placeholder-anon-key',
  );

  /// Feature flag: Journey Copilot AI assistant
  static const bool enableJourneyCopilot = bool.fromEnvironment(
    'ENABLE_JOURNEY_COPILOT',
    defaultValue: false,
  );

  /// Feature flag: Passive safety alerts
  static const bool enablePassiveSafetyAlerts = bool.fromEnvironment(
    'ENABLE_PASSIVE_SAFETY_ALERTS',
    defaultValue: true,
  );

  static bool get isProduction => appEnv == 'production';
  static bool get isDevelopment => appEnv == 'development';

  /// Validates whether critical production configurations are configured.
  static bool get hasValidSupabaseConfig =>
      supabaseUrl.isNotEmpty &&
      supabaseUrl != 'https://placeholder-safemate.supabase.co' &&
      supabaseAnonKey.isNotEmpty &&
      supabaseAnonKey != 'placeholder-anon-key';
}
