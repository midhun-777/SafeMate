# SafeMate Local SQLite Database Architecture

## 1. Overview

The SafeMate Local Database (`LocalDatabase`) provides a persistent, deterministic, and privacy-preserving SQLite foundation for the SafeMate application. It allows offline-first reads, draft creation, and queueing of pending server mutations without requiring continuous network connectivity.

The database is built strictly on top of `sqflite` with SQLite transactional ACID guarantees.

---

## 2. Database Architecture & Directory Structure

```
lib/core/database/
├── database_exceptions.dart       # User-safe database exceptions
├── database_schema.dart           # Table names, SQL DDL schemas, version constants
├── database_migrations.dart       # Deterministic, ordered version migration runner
├── database_models.dart           # Controlled local DTOs separating domain models
├── local_data_policy.dart         # Category A, B, C classifications & table registry
├── local_database.dart            # Central LocalDatabase client with user scoping & transactions
└── local_database_service.dart    # Compatibility service layer for SafeMate repositories
```

---

## 3. Schema Versioning & Migrations

* **Current Schema Version:** `DATABASE_VERSION = 1`
* **Migration Runner:** `DatabaseMigrationRunner`
* **Strategy:** Migrations are executed in strict ascending version sequence (`v0 -> v1 -> v2...`). The database is never dropped or recreated when schemas change, ensuring travelers never lose offline itineraries, drafts, or queued messages across app upgrades.

### Registered Migrations:
* **`MigrationV1`**: Creates `local_user_scope`, `local_profiles`, `local_trips`, `local_trip_preferences`, `local_itineraries`, `local_sync_queue`, and performance/isolation indexes.

---

## 4. Local Tables Specification & Retention Policies

| Table Name | Classification | Retention Policy | Primary Key | User Scoped Column | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `local_user_scope` | Category A (Safe) | `persistUntilLogout` | `id` | `user_id` (Unique) | Active authenticated user session tracker. |
| `local_profiles` | Category B (Controlled) | `persistUntilLogout` | `id` | `user_id` (Unique) | Cached profile, display name, and verification status. |
| `local_trips` | Category A (Safe) | `persistUntilLogout` | `id` | `user_id` | User's itineraries, origins, destinations, status, and dates. |
| `local_trip_preferences` | Category A (Safe) | `persistUntilLogout` | `id` | `user_id` | Trip companion preferences (gender, smoking, budget). |
| `local_itineraries` | Category A (Safe) | `persistUntilLogout` | `id` | `user_id` | Day-by-day journey itinerary plans. |
| `local_sync_queue` | Category B (Controlled) | `persistUntilSynced` | `id` | `user_id` | Offline mutation queue waiting for network dispatch (`operation_id` unique). |
| `local_safetrips` | Category B (Controlled) | `persistUntilTripComplete` | `id` | `owner_id` | Active journey safety session state and companion linkages. |
| `local_checkins` | Category B (Controlled) | `persistUntilSynced` | `id` | `user_id` | Check-in milestones pending cloud sync. |

---

## 5. Data Classification & Policy Enforcement (Phase 12.2 Hardening)

All data stored locally must adhere to [`LocalDataPolicy`](file:///c:/Users/chand/SafeMate/lib/core/database/local_data_policy.dart):

```
                              DATA CLASSIFICATION
                                       │
    ┌──────────────────────────────────┼──────────────────────────────────┐
    ▼                                  ▼                                  ▼
CATEGORY A: SAFE LOCAL CACHE    CATEGORY B: CONTROLLED CACHE     CATEGORY C: NEVER CACHE
- Own trip details & drafts     - Confirmed companion summary    - Government IDs (Aadhaar/Pass)
- User profile & preferences    - Chat room metadata & history   - Identity document photos/blobs
- Packing checklists & notes    - Active SafeTrip status         - Auth secrets & refresh tokens
- UI preferences                - Local check-in queue           - Payment credentials / CVV
- Day-by-day itineraries        - Pending sync queue operations  - Continuous raw GPS coordinates
                                                                 - Private moderation/admin logs
```

### 5.1 Single Source of Truth Registry (`tablePolicyRegistry`)
All tables must declare an authoritative `TablePolicy` specifying:
- Safety category (`Category A`, `Category B`)
- Whether the table is user-scoped and its `userIdColumn`
- Explicit retention policy (`persistUntilLogout`, `persistUntilSynced`, `persistUntilTripComplete`)
- Strict `allowedFields` set (field-level allowlist). Any unapproved field immediately triggers `DatabasePolicyViolationException`.

### 5.2 Payload Size Limit (64 KB)
Any record or sync mutation exceeding 65,536 bytes (64 KB) is rejected with `DatabasePolicyViolationException` to avoid local storage exhaustion or denial-of-service.

### 5.3 Prohibited Category C Enforcement (Fail Closed)
- Recursive JSON inspection via `LocalDataPolicy.assertSafeForLocalPersistence`.
- Prohibits sensitive keys (`aadhaar`, `passport`, `auth_token`, `payment_credentials`, `raw_gps_trail`, etc.).
- Safe audit logging via `LocalDataPolicy.logPolicyViolation`: records violation type and table name without leaking sensitive values or query internals.

---

## 6. User Isolation & Multi-Tenant Security

### 6.1 Active User Scoping & Cross-Account Access Denial
Every query and write verifies session user scope via `LocalDatabase._assertUserScope`:
- If an active user session is bound (e.g. `user_A`), attempting to read, write, or delete data for `user_B` immediately throws `DatabaseUserScopeException`.
- Internal migrations and system fixtures execute within `LocalDatabase.runAsSystem(() async { ... })`.

### 6.2 Registry-Driven Logout & Account Switch Purge
When a user logs out or switches accounts, `LocalDatabase.clearUserScopedData(userId)` is triggered:
- Inspects `sqlite_master` and validates every table against `LocalDataPolicy.tablePolicyRegistry` (fails fast if an unregistered table exists).
- Purges all rows matching `user_id` across all registered user-scoped tables inside an ACID transaction.
- Clears the active `_currentUserId` context.

---

## 7. Storage Security & Encryption Limitations

> [!CAUTION]
> **Important Security Disclosure:** Standard mobile SQLite databases reside on device storage in application sandboxes. On rooted Android devices or jailbroken iOS devices, unencrypted SQLite files may be extracted by attackers with physical access.
> 
> Therefore:
> 1. **Zero Credentials in SQLite:** Passwords, refresh tokens, access tokens, and cryptographic keys are strictly banned from SQLite and reside only in hardware-backed secure storage (Keystore / Keychain).
> 2. **Zero Sensitive PII in SQLite:** Aadhaar, passport numbers, and document photos are never cached locally.
> 3. **SQLCipher Roadmap:** SQLCipher database encryption may be considered in future enterprise safety phases if full-disk device encryption is deemed insufficient for regulated deployments.

---

## 8. Sync Queue Foundation & Idempotency

The `local_sync_queue` table prepares the storage foundation for Phase 12.3:
* **`operation_id`:** Unique UUID v4 generated upon user action.
* **Idempotency:** A unique database constraint (`UNIQUE INDEX idx_sync_queue_op_id`) prevents duplicate mutations from being enqueued. Duplicate insertions throw `DatabaseConstraintException`.
* **Statuses:** `PENDING`, `SYNCING`, `SYNCED`, `FAILED`, `CONFLICT`, `CANCELLED`.
* **Zero Network Synchronization in Phase 12.1:** Network sync engine routines remain completely deferred to Phase 12.3.
