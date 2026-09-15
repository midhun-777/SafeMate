import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// Supabase client manager for SafeMate.
/// Universal Engineering Rule #7: Only anon key used on client. Service-role keys never bundled.
class SupabaseService {
  SupabaseService._();

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// Initializes the Supabase client singleton.
  /// If running in development with placeholder keys, logs a diagnostic warning
  /// and skips network connection to allow offline testing.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    if (!AppConfig.hasValidSupabaseConfig) {
      debugPrint(
        '[SafeMate Supabase] Warning: Running with development placeholder credentials. '
        'Configure SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define or .env for live backend connectivity.',
      );
      _isInitialized = true;
      return;
    }
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
        realtimeClientOptions: const RealtimeClientOptions(
          eventsPerSecond: 10,
        ),
      );
      _isInitialized = true;
      debugPrint('[SafeMate Supabase] Initialized successfully.');
    } catch (e, stack) {
      debugPrint('[SafeMate Supabase] Initialization error: $e\n$stack');
      rethrow;
    }
  }

  /// Safe accessor for SupabaseClient.
  /// Returns null if initialized with placeholder credentials.
  static SupabaseClient? get client {
    if (!AppConfig.hasValidSupabaseConfig) {
      return null;
    }
    return Supabase.instance.client;
  }
}
