# SafeMate Security Architecture: Concurrency, Versioning & Server Authority

## 1. Zero-Trust Optimistic Concurrency Model
SafeMate enforces a zero-trust model between mobile/web clients and Supabase backend services. The local device is treated as an untrusted client that can propose mutations, but can never decree authoritative state or unilaterally resolve collisions.

### 1.1 Core Principles
* **Server Version Authority**: The server alone holds and increments the authoritative version counter on entities (`trips`, `profiles`, `trip_preferences`, `itineraries`).
* **Optimistic Concurrency Comparison**:
  $$\text{local.baseServerVersion} == \text{server.version}$$
  Any divergence between the version upon which the client based its mutation and the live server version results in a deterministic conflict (`staleBase` or `concurrentUpdate`).
* **Zero Wall-Clock Dependency**: SafeMate strictly rejects wall-clock `updatedAt` comparison. Client device clocks are susceptible to drift, user manipulation, timezone errors, and deliberate skew. Concurrency is governed purely by logical versions and row locks.

---

## 2. Server-Authoritative Field Freezing
Under no circumstances may a client modify security, trust, or lifecycle metadata. Attempted offline or online mutations to these fields are trapped by both the client-side `DeterministicConflictDetector` and PostgreSQL database triggers.

### 2.1 Frozen Attributes
| Entity | Server-Authoritative Fields | Enforcement Mechanism |
| :--- | :--- | :--- |
| **Profile** | `trust_score`, `is_verified`, `verification_status`, `reliability_rating`, `trips_completed`, `moderation_state`, `is_suspended`, `suspension_reason`, `role` | Client: `DeterministicConflictDetector` (`permissionChanged`)<br>DB: `protect_server_authoritative_profile_fields()` trigger |
| **Trip** | `user_id` / `owner_id`, `id`, `version` | Client: `DeterministicConflictDetector` (`permissionChanged`)<br>DB: RLS policies + `update_trip_occ` RPC |
| **SafeTrip** | `status`, `is_sos_active`, `safety_authorization`, `emergency_state` | Client: `DeterministicConflictDetector` (`serverStateChanged`)<br>DB: Server state machine transitions |

---

## 3. Database Atomicity & RPC Concurrency Control
To prevent lost updates under high concurrency, Supabase PostgreSQL employs row-level pessimistic locking within stored procedures:

```sql
SELECT * INTO v_current_trip
FROM public.trips
WHERE id = p_trip_id
FOR UPDATE;

IF v_current_trip.version != p_base_version THEN
    RAISE EXCEPTION '409 Conflict: Trip version % on server differs from client base version %',
        v_current_trip.version, p_base_version USING ERRCODE = 'P0001';
END IF;
```

`FOR UPDATE` guarantees mutual exclusion: when multiple devices attempt concurrent updates against version $N$, exactly one transaction acquires the lock, validates $N == N$, applies changes, and increments to $N+1$. Concurrent transactions waiting on the lock subsequently observe version $N+1$, failing the concurrency check with a `409 Conflict` exception.

---

## 4. Cross-Account Isolation
1. **User Scoped Queries**: SQLite operations must explicitly provide `userId`.
2. **Conflict Ownership**: `SyncConflict` validates non-empty `userId` and binds strictly to the user session.
3. **Session Revocation**: Invalidation of credentials halts sync queue processing immediately, emitting `SyncEngineStatus.authRequired` without leaking dirty mutations across accounts.

---

## 5. Non-Destructive Reconciliation Security & Privacy Boundaries (Phase 12.4.3)
1. **Forbidden Resolution Actions**:
   - The UI and repository controllers strictly prohibit "Keep Mine" (`ResolutionStrategy.keepLocal`) for any server-authoritative field (`trust_score`, `is_verified`, `verification_status`, `moderation_state`, `is_suspended`, `status` of SafeTrip).
   - Attempting to pass `keepLocal` on authoritative fields throws `ArgumentError` immediately before any mutation can reach the local or remote database.
2. **Resurrection Prevention**:
   - In `updateVsDelete` scenarios where an entity was deleted on the server, the local mutation is cleanly discarded (`ReconciliationOutcome.discarded`). The system never resurrects deleted server records.
3. **Terminal Lifecycle Immobility**:
   - Entities marked in terminal states on the server (`CANCELLED`, `COMPLETED` for Trips) cannot have their status or content mutated by offline clients.
4. **Privacy Sanitization in Audit & Telemetry**:
   - Conflict resolution audit payloads and telemetry events strictly scrub Category C sensitive data (passwords, government IDs, auth tokens) and precision GPS coordinates before emitting to logs or synchronization queues.

---

## 6. Conflict Action Hardening & Realtime Ingestion Boundaries (Phase 12.4.5)

### 6.1 Bypassing Stale Base-Version Retry Vulnerabilities
* **Flaw Avoided**: Blindly retrying an old conflicted mutation with its original base version ($V=9$ against server $V=10$) causes infinite retry loops and perpetual 409 collisions.
* **Hardened Architecture**: SafeMate requires obtaining the authoritative server state ($V=10$), re-running deterministic 3-way reconciliation, creating a **new mutation** with `base_server_version = 10`, and assigning a brand new `client_operation_id` (UUIDv4) linked to the original conflict audit identifier.

### 6.2 Keep-Mine Security Boundary
* The client strictly freezes the following fields to server authority even during a "Keep My Changes" action:
  - `trust_score`
  - `verification_status`
  - `verification_level`
  - `reliability_rating`
  - `moderation_state`
  - `account_status`
  - `ownership` / `permissions`
  - `SafeTrip` journey status
  - `security restrictions`
* Any attempt by local state to inject modifications into these fields is overwritten with server-authoritative values prior to enqueuing the new mutation.

### 6.3 Stale UI Protection
* Resolution commands must re-verify that the active server version has not moved beyond the version reviewed by the traveler (`expectedServerVersion == currentServerVersion`).
* If a background sync or remote device advanced the server version ($V_{server} > V_{UI}$), `StaleConflictVersionException` is raised, preventing blind execution against stale state.

### 6.4 Realtime Ingestion & Resurrection Defense
* Incoming Realtime server events are strictly filtered:
  - Older version: `IGNORE` (dropped immediately).
  - Same version: `DEDUPLICATE` (no-op).
  - Newer version: `RECONCILE` (clean update or conflict detection).
  - Server deletion: Purges local entity and prevents resurrection from delayed update events.


