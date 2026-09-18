# SafeMate Local Data Classification & Policy Enforcement Specification
**Phase 12.2 Security Architecture Document**

---

## 1. Executive Summary

SafeMate is a high-assurance, privacy-centric travel companion application. The local data tier provides offline capability without sacrificing user privacy or exposing sensitive information on mobile devices.

Phase 12.2 establishes an uncompromising privacy boundary:
1. **Central Authoritative Registry (`tablePolicyRegistry`)**: Single source of truth for all SQLite tables, retention rules, and field allowlists.
2. **Category A / B / C Classification**: Clear classification determining local persistence rights.
3. **Fail-Closed Security**: Any unknown entity or table defaults to Category C and is prohibited from local persistence.
4. **Field-Level Allowlists**: Every table enforces a whitelist of allowed schema columns. Non-whitelisted or unapproved fields immediately throw `DatabasePolicyViolationException`.
5. **Hard Payload Limits (64 KB)**: Hard cap of 65,536 bytes per table record or sync queue payload.
6. **Strict Multi-User Isolation**: User-scoped queries and writes prevent any cross-account read, update, or deletion.
7. **Privacy-Preserving Audit Logs**: Policy violations are logged without exposing sensitive data values, user credentials, or raw database queries.

---

## 2. Data Classification Matrix

| Classification | Definition | Allowed in SQLite? | Retention Lifecycle | Examples |
| :--- | :--- | :---: | :--- | :--- |
| **Category A: Safe** | Non-sensitive, publicly safe, or own operational travel data | **YES** | `persistUntilLogout` | Own trip summary, destinations, origins, dates, preferences, packing lists, itineraries |
| **Category B: Controlled** | Private user data, companion summaries, or pending offline sync | **YES** | `persistUntilSynced` or `persistUntilTripComplete` | Cached profiles (name, bio), chat messages, sync queue operations, SafeTrip state, check-ins |
| **Category C: Prohibited** | High-risk credentials, identity documents, private logs, location trails | **NO** | **NEVER PERSISTED** | Aadhaar, passport numbers, document image bytes, auth tokens, passwords, payment CVV/cards, continuous raw GPS tracks, admin/moderation logs |

---

## 3. Table Policy Registry (`tablePolicyRegistry`)

| Table Name | Classification | User Scoped? | User Column | Retention Policy | Enforced Allowlists |
| :--- | :---: | :---: | :---: | :--- | :--- |
| `local_user_scope` | Category A | Yes | `user_id` | `persistUntilLogout` | `id`, `user_id`, `is_active`, `last_switched_at` |
| `local_trips` | Category A | Yes | `user_id` | `persistUntilLogout` | `id`, `user_id`, `destination`, `origin`, `start_date`, `end_date`, `purpose`, `budget`, `status`, `raw_json`, `updated_at`, `last_synced_at` |
| `local_trip_preferences` | Category A | Yes | `user_id` | `persistUntilLogout` | `id`, `trip_id`, `user_id`, `preferred_gender`, `travel_pace`, `budget_tier`, `raw_json`, `updated_at` |
| `local_itineraries` | Category A | Yes | `user_id` | `persistUntilLogout` | `id`, `trip_id`, `user_id`, `title`, `days_json`, `updated_at` |
| `local_profiles` | Category B | Yes | `user_id` | `persistUntilLogout` | `id`, `user_id`, `display_name`, `bio`, `verification_level`, `raw_json`, `updated_at`, `last_synced_at` *(Email/phone prohibited)* |
| `local_sync_queue` | Category B | Yes | `user_id` | `persistUntilSynced` | `id`, `user_id`, `operation_id`, `entity_type`, `entity_id`, `operation_type`, `payload`, `created_at`, `attempt_count`, `next_attempt_at`, `status`, `last_error` |
| `sync_queue` (legacy) | Category B | Yes | `user_id` | `persistUntilSynced` | `operation_id`, `user_id`, `entity_type`, `entity_id`, `action`, `payload_json`, `status`, `retry_count`, `last_attempt_at`, `error_message`, `created_at` |
| `local_chat_messages` | Category B | Yes | `sender_id` | `persistUntilLogout` | `id`, `room_id`, `sender_id`, `client_message_id`, `content`, `status`, `created_at` |
| `local_safetrips` | Category B | Yes | `owner_id` | `persistUntilTripComplete` | `id`, `trip_id`, `owner_id`, `companion_id`, `status`, `raw_json`, `updated_at` |
| `local_checkins` | Category B | Yes | `user_id` | `persistUntilSynced` | `id`, `journey_id`, `user_id`, `status`, `checkin_time`, `sync_status`, `raw_json` |

---

## 4. Policy Enforcement Mechanism

```
Caller (Repository / SyncEngine)
            │
            ▼
LocalDatabase Write Method (saveTrip, saveProfile, enqueueSyncOperation)
            │
            ├─► 1. User Scope Assertion (_assertUserScope)
            │      └─ If activeUserId != recordUserId -> DatabaseUserScopeException
            │
            ├─► 2. Registry Validation (LocalDataPolicy.validateTableWrite)
            │      ├─ If table not registered -> DatabasePolicyViolationException (fail fast)
            │      ├─ If payloadSize > 64 KB -> DatabasePolicyViolationException
            │      ├─ If non-allowlisted field present -> DatabasePolicyViolationException
            │      └─ If prohibited Category C field present -> DatabasePolicyViolationException
            │
            └─► 3. Atomic SQLite Transaction Execution
```

---

## 5. Violation Logging Specification

When a policy violation occurs:
```dart
LocalDataPolicy.logPolicyViolation(
  violationType: 'CROSS_ACCOUNT_ACCESS_DENIED', // or CATEGORY_C_PROHIBITED, UNAPPROVED_FIELD, etc.
  tableName: tableName,
  operation: operation,
);
```

### Safety Guarantees:
- **No PII**: Raw user names, email addresses, phone numbers, and coordinates are never logged.
- **No Raw Payloads**: Payload contents and argument maps are excluded.
- **No SQL Internals**: Stack traces or internal query statements are not written to console logs.
- Safe audit records facilitate telemetry without risk of log-scraping credential theft.
