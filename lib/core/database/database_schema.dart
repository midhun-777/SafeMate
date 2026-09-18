/// SafeMate Database Schema Definitions and Version Constants.
/// Universal Engineering Rule #6: Strict schema validation.
/// Universal Engineering Rule #10: Multi-user isolation through explicit user_id indexing.
library;

class DatabaseSchema {
  DatabaseSchema._();

  /// Current SQLite Schema Version.
  static const int currentVersion = 2;

  // Table Names
  static const String tableUserScope = 'local_user_scope';
  static const String tableProfiles = 'local_profiles';
  static const String tableTrips = 'local_trips';
  static const String tableTripPreferences = 'local_trip_preferences';
  static const String tableItineraries = 'local_itineraries';
  static const String tableSyncQueue = 'sync_queue';

  // Compatible Table Names for existing Phase 12 modules
  static const String tableLegacySyncQueue = 'sync_queue';
  static const String tableLocalSyncQueue = 'local_sync_queue';
  static const String tableChatMessages = 'local_chat_messages';
  static const String tableSafeTrips = 'local_safetrips';
  static const String tableCheckins = 'local_checkins';

  // 1. User Scope Table Definition
  static const String createUserScopeTable = '''
    CREATE TABLE $tableUserScope (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL UNIQUE,
      is_active INTEGER NOT NULL DEFAULT 1,
      last_switched_at TEXT NOT NULL
    )
  ''';

  // 2. Profiles Table Definition
  static const String createProfilesTable = '''
    CREATE TABLE $tableProfiles (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL UNIQUE,
      display_name TEXT NOT NULL,
      bio TEXT,
      verification_level TEXT NOT NULL DEFAULT 'unverified',
      server_version INTEGER NOT NULL DEFAULT 1,
      base_server_version INTEGER NOT NULL DEFAULT 1,
      local_revision INTEGER NOT NULL DEFAULT 0,
      raw_json TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      last_synced_at TEXT
    )
  ''';

  // 3. Trips Table Definition
  static const String createTripsTable = '''
    CREATE TABLE $tableTrips (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      destination TEXT NOT NULL,
      origin TEXT NOT NULL,
      start_date TEXT NOT NULL,
      end_date TEXT NOT NULL,
      purpose TEXT NOT NULL,
      budget TEXT NOT NULL,
      status TEXT NOT NULL,
      server_version INTEGER NOT NULL DEFAULT 1,
      base_server_version INTEGER NOT NULL DEFAULT 1,
      local_revision INTEGER NOT NULL DEFAULT 0,
      raw_json TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      last_synced_at TEXT
    )
  ''';

  // 4. Trip Preferences Table Definition
  static const String createTripPreferencesTable = '''
    CREATE TABLE $tableTripPreferences (
      id TEXT PRIMARY KEY,
      trip_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      preferred_gender TEXT,
      travel_pace TEXT,
      budget_tier TEXT,
      server_version INTEGER NOT NULL DEFAULT 1,
      base_server_version INTEGER NOT NULL DEFAULT 1,
      local_revision INTEGER NOT NULL DEFAULT 0,
      raw_json TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  // 5. Itineraries Table Definition
  static const String createItinerariesTable = '''
    CREATE TABLE $tableItineraries (
      id TEXT PRIMARY KEY,
      trip_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      title TEXT NOT NULL,
      days_json TEXT NOT NULL,
      server_version INTEGER NOT NULL DEFAULT 1,
      base_server_version INTEGER NOT NULL DEFAULT 1,
      local_revision INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL
    )
  ''';

  // 6. Harmonized Sync Queue Table Definition (Authoritative Queue)
  static const String createSyncQueueTable = '''
    CREATE TABLE IF NOT EXISTS $tableSyncQueue (
      operation_id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      action TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      status TEXT NOT NULL,
      retry_count INTEGER DEFAULT 0,
      last_attempt_at TEXT,
      error_message TEXT,
      created_at TEXT NOT NULL,
      base_server_version INTEGER,
      local_revision INTEGER DEFAULT 1,
      id TEXT,
      operation_type TEXT,
      payload TEXT,
      attempt_count INTEGER DEFAULT 0,
      next_attempt_at TEXT,
      last_error TEXT
    )
  ''';

  // Compatibility sync queue definition
  static const String createLegacySyncQueueTable = createSyncQueueTable;

  // Compatibility table for local_sync_queue (Phase 12.1 test suite compatibility)
  static const String createLocalSyncQueueTable = '''
    CREATE TABLE IF NOT EXISTS $tableLocalSyncQueue (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      operation_id TEXT NOT NULL UNIQUE,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      operation_type TEXT NOT NULL,
      payload TEXT NOT NULL,
      created_at TEXT NOT NULL,
      attempt_count INTEGER DEFAULT 0,
      next_attempt_at TEXT,
      status TEXT NOT NULL,
      last_error TEXT,
      base_server_version INTEGER,
      local_revision INTEGER DEFAULT 1
    )
  ''';

  // Chat Messages Table
  static const String createChatMessagesTable = '''
    CREATE TABLE $tableChatMessages (
      id TEXT PRIMARY KEY,
      room_id TEXT NOT NULL,
      sender_id TEXT NOT NULL,
      client_message_id TEXT NOT NULL,
      content TEXT NOT NULL,
      status TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  ''';

  // SafeTrips Table
  static const String createSafeTripsTable = '''
    CREATE TABLE $tableSafeTrips (
      id TEXT PRIMARY KEY,
      trip_id TEXT NOT NULL,
      owner_id TEXT NOT NULL,
      companion_id TEXT,
      status TEXT NOT NULL,
      raw_json TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  // Checkins Table
  static const String createCheckinsTable = '''
    CREATE TABLE $tableCheckins (
      id TEXT PRIMARY KEY,
      journey_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      status TEXT NOT NULL,
      checkin_time TEXT NOT NULL,
      sync_status TEXT NOT NULL,
      raw_json TEXT NOT NULL
    )
  ''';

  // Index Definitions
  static const List<String> createIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_user_scope_user ON $tableUserScope(user_id);',
    'CREATE INDEX IF NOT EXISTS idx_profiles_user ON $tableProfiles(user_id);',
    'CREATE INDEX IF NOT EXISTS idx_trips_user ON $tableTrips(user_id);',
    'CREATE INDEX IF NOT EXISTS idx_trip_prefs_trip ON $tableTripPreferences(trip_id);',
    'CREATE INDEX IF NOT EXISTS idx_trip_prefs_user ON $tableTripPreferences(user_id);',
    'CREATE INDEX IF NOT EXISTS idx_itineraries_trip ON $tableItineraries(trip_id);',
    'CREATE INDEX IF NOT EXISTS idx_itineraries_user ON $tableItineraries(user_id);',
    'CREATE INDEX IF NOT EXISTS idx_sync_queue_user_status ON $tableSyncQueue(user_id, status);',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_queue_op_id ON $tableSyncQueue(operation_id);',
    // Compatibility indexes
    'CREATE INDEX IF NOT EXISTS idx_local_sync_queue_user_status ON $tableLocalSyncQueue(user_id, status);',
    'CREATE INDEX IF NOT EXISTS idx_legacy_sync_queue_user_status ON $tableLegacySyncQueue(user_id, status);',
    'CREATE INDEX IF NOT EXISTS idx_chat_room ON $tableChatMessages(room_id, created_at);',
    'CREATE INDEX IF NOT EXISTS idx_chat_client_msg ON $tableChatMessages(client_message_id);',
    'CREATE INDEX IF NOT EXISTS idx_safetrips_trip ON $tableSafeTrips(trip_id);',
    'CREATE INDEX IF NOT EXISTS idx_safetrips_owner ON $tableSafeTrips(owner_id);',
    'CREATE INDEX IF NOT EXISTS idx_checkins_journey ON $tableCheckins(journey_id);',
  ];
}
