# SafeMate Offline Failure Recovery & Reliability Operations Guide
**Phase 12.5 Production Reliability, Recovery Protocols & Operational Checklist**

---

## 1. Offline Architecture & Single-Flight Sync Engine

SafeMate uses an offline-first architecture anchored by SQLite Write-Ahead Logging (`WAL`) on the client and PostgreSQL / Supabase on the cloud.

```
+-------------------------------------------------------------+
|                     PRESENTATION LAYER                      |
|           (TripsHomeScreen, ConflictReviewScreen)           |
+------------------------------+------------------------------+
                               |
                               v
+-------------------------------------------------------------+
|                  OFFLINE-FIRST REPOSITORIES                 |
|   (OfflineFirstTripRepo, OfflineFirstProfileRepo, etc.)     |
+---------------+-----------------------------+---------------+
                |                             |
                v                             v
+-------------------------------+ +---------------------------+
|    LOCAL SQLITE DATA LAYER    | |       SYNC ENGINE         |
|  (local_trips, local_profiles)| |    (Single-Flight Mutex,  |
|   Atomic ACID Transactions    | |  Bounded Backoff, Jitter) |
+---------------+---------------+ +-------------+-------------+
                |                               |
                +---------------+---------------+
                                |
                                v
               +----------------------------------+
               |     REMOTE SUPABASE BACKEND      |
               | (PostgreSQL, OCC Triggers, RLS)  |
               +----------------------------------+
```

### Key Guarantees
1. **Server Remains Authoritative**: Remote version counters (`server_version`) dictate the true state. Client revisions (`local_revision`) track local uncommitted drafts.
2. **Durability Invariant**: Every pending operation staged in `sync_queue` survives application force-close, background OS termination, and device power cycles.
3. **Idempotency Guarantee**: Retrying an operation after a dropped response packet re-uses the unique `operation_id` or `idempotency_key`, resulting in exactly one server-side commit.

---

## 2. Failure Recovery Matrix

| Failure Mode | Detection Mechanism | Immediate Action | Recovery Protocol |
| :--- | :--- | :--- | :--- |
| **Network Loss During Mutation** | `SocketException` / `TimeoutException` | Mutation preserved in SQLite; status marked `pending`. | `ConnectivityService` detects online transition; `SyncEngine` retries with exponential backoff. |
| **Dropped Response Packet** | Client timeout after server commit | `SyncRecord` kept in `sync_queue` with `retry_count += 1`. | Client replays request with identical `operation_id`; server returns cached result idempotently. |
| **Concurrent Version Collision (409)** | HTTP 409 Conflict / version mismatch | Queue record marked `conflict`; traveler notified via banner. | `DeterministicReconciler` performs non-conflicting field merge or routes to `ConflictReviewScreen`. |
| **Authentication Expiry (401)** | HTTP 401 Unauthorized | Queue traversal pauses; status updated to `auth_required`. | Supabase SDK attempts silent refresh; upon re-login, queue resumes cleanly. |
| **Process Death Mid-Transaction** | OS termination | SQLite rollback journal cleans up uncommitted writes. | On reboot, SQLite WAL opens cleanly; pending operations remain fully intact. |
| **Device Storage Exhaustion** | `DatabaseLowStorageException` | Writes abort gracefully; user presented with storage warning. | Traveler frees disk space; sync engine retries without data corruption. |
| **Authoritative Deletion** | Realtime `DELETE` event | Entity removed from local SQLite; tombstone preserved. | Stale replayed update events are ignored, preventing deleted-record resurrection. |

---

## 3. SafeTrip Physical Safety Boundaries

1. **Offline Check-In $\ne$ Confirmed Cloud Delivery**:
   - Check-ins recorded offline are marked `sync_status = 'pending'`.
   - UI explicitly displays "Saved locally; waiting for network". It **never** displays "Confirmed" or "Delivered" until server acknowledgment is received.
2. **Emergency SOS Boundary**:
   - If cellular connectivity is absent, SafeMate presents an offline boundary dialog providing direct OS emergency phone dialing fallback (e.g. 112 / 911). It never fabricates cloud dispatch.
3. **GPS Permission Revocation**:
   - If GPS permission is revoked during an active journey, check-ins record with `[Location Revoked]` notes, allowing manual checkpoint confirmation via Wi-Fi without crashing.

---

## 4. Production Reliability Checklist

- [x] Offline queue survives app restart and device reboot.
- [x] Zero silent data loss across all supported entities.
- [x] Zero duplicate logical mutations under network drops.
- [x] Zero duplicate chat messages via append-only client UUIDs.
- [x] Zero resurrection of server-deleted records.
- [x] Cross-account data leakage blocked via `purgeUserData` on logout.
- [x] Single-flight concurrency lock prevents sync race conditions.
- [x] Bounded exponential backoff caps retries at 5 attempts (max 60s + jitter).
- [x] Privacy telemetry strips all Category C attributes, PII, tokens, and raw GPS.
- [x] Error taxonomy maps internal exceptions to traveler-safe actionable messages.
- [x] 100% automated test regression passing (519/519 tests).
- [x] 0 static analyzer issues (`dart analyze`).
- [x] Android binary compiles cleanly (`BUILD SUCCESSFUL`).
