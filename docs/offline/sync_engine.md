# SafeMate Synchronization Engine & Offline Architecture
**Phase 12.3 Architecture & Technical Specification**

---

## 1. Executive Overview

The SafeMate Synchronization Engine (`SyncEngine`) provides robust, resilient, and privacy-preserving eventual consistency between local SQLite storage and Supabase PostgreSQL.

### Prime Architectural Directive
> **THE LOCAL SQLITE STORE IS A TEMPORARY WORKSPACE.**  
> **THE SERVER IS THE EXCLUSIVE AUTHORITY.**

Offline local state allows travelers to create trip drafts, modify itineraries, write profile updates, and compose messages in connectivity-constrained environments (airplanes, remote mountain trails, rural transit). The synchronization engine ensures these operations are safely, idempotently, and securely transmitted to the server when connectivity returns.

---

## 2. Core Architectural Components

```
                UI Presentation Layer (Screens, Widgets & Notifiers)
                                         │
                                         ▼
                     Offline-First Repository Implementations
           (OfflineFirstTripRepository, OfflineFirstProfileRepository,
            OfflineFirstChatRepository, OfflineFirstSafeTripRepository)
                                         │
                 ┌───────────────────────┴───────────────────────┐
                 ▼                                               ▼
       Local SQLite Foundation                             SyncEngine
       - Instant cached reads (Category A/B)               - Single-flight queue worker
       - Local Chat Outbox (pending)                       - Bounded exponential backoff
       - Pending Sync Queue (`sync_queue`)                 - Error classification
                 │                                         - User-session verification
                 │                                               │
                 │                                               ▼
                 │                                     Supabase PostgreSQL / RPCs
                 │                                     - Row Level Security (RLS)
                 │                                     - Idempotent Server Mutators
                 │                                               │
                 └────────────────── Reconcile ──────────────────┘
```

---

## 3. Sync Domain Models & States

### 3.1 Operation Status (`SyncStatus`)
- `pending`: Enqueued locally, awaiting connectivity or cooldown window.
- `syncing`: Currently in-flight with an active single-flight sync worker.
- `synced`: Confirmed by server, removed from local mutation queue.
- `failed`: Failed with non-retryable error or exceeded maximum retry limit (5).
- `conflict`: Server detected state divergence; requires merge or user review.
- `cancelled`: Mutation superseded or aborted.

### 3.2 Operation Types (`SyncOperationType`)
- `create`, `update`, `delete`, `save_draft`, `send_message`, `record_checkin`.

### 3.3 Approved Sync Entity Types (`SyncEntityType`)
- `trip`, `profile`, `trip_preferences`, `itinerary`, `chat_message`, `safetrip_checkin`.
- Any unapproved entity type is rejected at enqueue time by `LocalDataPolicy.validateSyncPayload`.

---

## 4. Idempotency & Retry Architecture

### 4.1 Mutation Idempotency
- Every mutation possesses a unique `operation_id` generated upon creation.
- **Critical Rule**: When an operation retries, it **reuses the same `operation_id`**. It never generates a new identifier on retry.
- Chat messages reuse `client_message_id`.
- SafeTrip check-ins reuse `idempotencyKey`.
- Server RPCs (e.g. `send_chat_message`) verify idempotency parameters to guarantee duplicate submissions do not create duplicate records.

### 4.2 Bounded Exponential Backoff
- Base backoff formula: $2^n$ seconds + random jitter ($0-3\text{s}$), capped at 60 seconds maximum delay.
- Maximum retry limit: **5 attempts**.
- Upon exceeding 5 attempts, operations transition to `failed` and will not auto-retry in an infinite loop.

---

## 5. Error Classification & Handling

| Classification | Trigger Conditions | Engine Behavior |
| :--- | :--- | :--- |
| **`transient`** | Socket exceptions, network timeouts, failed DNS lookup, connection reset | Increments `retry_count`, calculates backoff cooldown, reschedules |
| **`rateLimited`** | HTTP 429 | Backs off and retries after delay |
| **`authentication`** | HTTP 401, expired session, revoked token | Halts queue processing immediately, sets status to `authRequired` |
| **`authorization`** | HTTP 403, Row Level Security (RLS) violation | Marks `failed`, stops retrying (prevents brute-force loops) |
| **`validation`** | Malformed data, server constraint error | Marks `failed`, records diagnostic message |
| **`conflict`** | HTTP 409, version mismatch, concurrent edit divergence | Marks `conflict`, requires merge strategy or user review |
| **`notFound`** | HTTP 404, target parent record deleted on server | Marks `failed` |
| **`permanent`** | All other fatal server errors | Marks `failed` without infinite retry |

---

## 6. Multi-Tenant Isolation & Account Switch Safety

Universal Engineering Rule #10:
1. **User Session Scope Verification**: Before processing each operation, the worker verifies:
   $$\text{operation.userId} == \text{currentActiveUserId}$$
   If mismatch is detected, the operation is skipped with a security audit log.
2. **Account Switching / Logout**:
   - The sync worker is immediately halted.
   - Any in-flight work is aborted safely.
   - `clearUserScopedData(oldUserId)` purges all Category A & B SQLite records for the departing user.
   - The sync engine resumes only for the newly authenticated user.

---

## 7. Domain-Specific Synchronization Policies

### 7.1 Trip Synchronization
- **Offline Writes**: Saved to `local_trips` immediately, enqueued as `save_draft` or `create`.
- **UI State**: Displays `"Saved on this device"` until server confirms `"Published"`.
- **Conflict Detection**: Compares `updatedAt` / version timestamps. If server record was modified concurrently after local edit base, flags conflict rather than silently overwriting.
- **Safe Delete**: Drafts deleted locally; deletion intent enqueued to remote.

### 7.2 Profile Synchronization
- **Permitted Offline Edits**: `display_name`, `bio`, travel companion preferences.
- **Strictly Server-Only**: `is_verified`, verification levels, trust scores, moderation flags, suspension states.
- **Prohibited**: Identity documents, Aadhaar, passport numbers (Category C).
- Photo uploads require live network connectivity.

### 7.3 Chat Outbox
- Messages written to `local_chat_messages` with `client_message_id` and `deliveryStatus = pending`.
- UI renders outbox messages immediately with pending indicators.
- When online, dispatches via `send_chat_message` RPC.
- Server verifies recipient has not blocked the user while offline.
- Moves to `sent` only upon server acknowledgment.
- Incoming Realtime messages matching pending `client_message_id` reconcile automatically.

### 7.4 SafeTrip Server Authority
- **Server Authority Rules**:
  - Offline client **cannot** autonomously activate SafeTrip without server timestamp.
  - Local active status **never** overrides server cancelled or alerted state.
  - Emergency alerts, SOS dispatch, and verified arrivals require live server validation.
- **Permitted Offline**: Check-in intent recorded locally (`JourneyCheckin` with `sync_status = pending`), dispatched upon reconnection.

---

## 8. Background Sync & Connectivity Constraints

- **Connectivity Detection**: `ConnectivityService` validates live reachability (avoiding false-positive "Wi-Fi connected without internet" states) without aggressive polling.
- **No Continuous Background Sync**: Background synchronization is executed when:
  1. The application is in foreground / active.
  2. Network connectivity returns.
  3. User performs a manual sync ("Sync now").
  4. Repository mutation occurs.
- Platform background execution (e.g. WorkManager) is deferred to a future dedicated platform background phase.

---

## 9. Privacy-Safe Telemetry & Auditing

Telemetry events emitted:
- `sync_started`, `sync_completed`, `sync_failed`, `sync_conflict`, `sync_retry_scheduled`, `offline_mode_entered`, `offline_mode_exited`, `account_switch_purged`.

**Guarantees**:
- Never logs message contents, prompt texts, emails, phone numbers, GPS coordinates, or credentials.
