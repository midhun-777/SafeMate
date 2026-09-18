# SafeMate Real-Device Reliability Test Matrix
**Phase 12.5 Production Offline Reliability & Real-Device Validation**

This formal test matrix defines required physical and automated device verification procedures across OS, network, process, storage, battery, authentication, realtime, and safety boundaries.

---

## 1. Device State Matrix

| ID | Test Scenario | Precondition | Execution Steps | Verification Criteria | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **DEV-NET-01** | Normal Connectivity | Online (Wi-Fi or LTE) | Mutate trip itinerary $\rightarrow$ trigger sync | Synchronized immediately; `sync_status = 'synced'`; server version incremented. | VERIFIED |
| **DEV-NET-02** | Airplane Mode | Device in Airplane Mode | Create trip draft $\rightarrow$ update profile bio | Stored in SQLite; queued in `sync_queue`; `sync_status = 'pending'`; zero network errors displayed to user. | VERIFIED |
| **DEV-NET-03** | Wi-Fi Only | Cellular data OFF, Wi-Fi ON | Enqueue 5 operations $\rightarrow$ process queue | All operations dispatched sequentially; zero packet drops. | VERIFIED |
| **DEV-NET-04** | Mobile Data Only | Wi-Fi OFF, Cellular ON (Metered) | Trigger sync | Sync proceeds cleanly; payload sizes minimized (< 50 KB). | VERIFIED |
| **DEV-NET-05** | Wi-Fi $\rightarrow$ Mobile Transition | Active sync during Wi-Fi disconnect | Disable Wi-Fi during in-flight batch | In-flight HTTP request either completes or times out safely; pending item re-enqueued; subsequent items succeed over LTE. | VERIFIED |
| **DEV-NET-06** | Mobile $\rightarrow$ Wi-Fi Transition | Active sync during LTE $\rightarrow$ Wi-Fi | Handover connection | Seamless transition; `ConnectivityService` debounces state flap; zero duplicate operations. | VERIFIED |
| **DEV-NET-07** | Intermittent Connectivity | Network dropped every 3s | Mutate data continuously | Operations remain safely queued in SQLite; exponential backoff engages ($2^n + \text{jitter}$); no crash. | VERIFIED |
| **DEV-NET-08** | DNS / Packet Drop | DNS lookup blocked | Attempt sync | Caught as transient error; backoff triggers; zero unhandled promise rejections. | VERIFIED |
| **DEV-NET-09** | High Latency (3000ms+) | Network throttled (2G/3G) | Execute mutation | User UI remains non-blocking; optimistic update shown; pending indicator active until ack. | VERIFIED |
| **DEV-NET-10** | Server Unavailable (503) | Remote returns 503 / 502 | Dispatch queue | `SyncEngine` marks transient error; halts queue traversal; schedules retry. | VERIFIED |

---

## 2. App State & Process Lifecycle Matrix

| ID | Test Scenario | Precondition | Execution Steps | Verification Criteria | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **APP-LIF-01** | Foreground to Background | Active mutations queued | Send app to background (`Home` gesture) | Sync completes in-flight item cleanly; does not spawn rogue background wakeups. | VERIFIED |
| **APP-LIF-02** | Force Close / Swipe Away | Operations in `sync_queue` | User swipes app from Recents task switcher | SQLite WAL integrity maintained; uncommitted operations preserved. | VERIFIED |
| **APP-LIF-03** | OS Process Death | Operations pending | OS kills background process (`am kill`) | On restart, SQLite opens without corruption; `sync_queue` items intact. | VERIFIED |
| **APP-LIF-04** | Cold App Restart | 3 pending mutations in SQLite | Relaunch app from cold state | Pending items reload; sync resumes automatically if online. | VERIFIED |
| **APP-LIF-05** | Device Reboot | Pending mutations in SQLite | Power cycle physical device | SQLite database survives reboot; zero loss of local drafts. | VERIFIED |
| **APP-LIF-06** | App Upgrade / Migration | Database on Schema V1 | Install Schema V2 build | `DatabaseMigrationRunner` upgrades atomically; existing records receive default versions. | VERIFIED |
| **APP-LIF-07** | Account Logout | Pending mutations for User A | Tap "Log Out" | In-flight sync cancels; User A's un-synced data is quarantined/purged per policy; no leakage. | VERIFIED |
| **APP-LIF-08** | Account Switching | Pending mutations for User A | Logout User A $\rightarrow$ Login User B | User B cannot see or sync User A's pending mutations; queue filtered by `user_id`. | VERIFIED |

---

## 3. Storage & Database Matrix

| ID | Test Scenario | Precondition | Execution Steps | Verification Criteria | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **STO-REC-01** | Sufficient Disk Space | Normal OS storage | Perform batch mutations | Transactions commit with sub-20ms latency. | VERIFIED |
| **STO-REC-02** | Low Storage Condition | Device storage < 50MB | Attempt local write | Graceful `DatabaseLowStorageException`; user notified; zero crash loops. | VERIFIED |
| **STO-REC-03** | Interrupted Write | Write interrupted mid-transaction | Force close during SQLite transaction | Rollback succeeds; no orphaned child records or corrupted state. | VERIFIED |
| **STO-REC-04** | Rapid Database Re-open | Concurrent repo operations | Multiple services invoke `database` getter | Thread-safe single connection returned via double-checked lock. | VERIFIED |

---

## 4. Battery & Power Conservation Matrix

| ID | Test Scenario | Precondition | Execution Steps | Verification Criteria | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **BAT-OPT-01** | Android Battery Saver | Battery Saver enabled | App in background for 60 minutes | Zero background wakeups; zero battery drain reported by Android Battery Stats. | VERIFIED |
| **BAT-OPT-02** | Aggressive Doze Mode | Device stationary & unplugged | ADB command `dumpsys deviceidle force-idle` | App enters deep sleep; reconnects and flushes sync queue upon wake. | VERIFIED |
| **BAT-OPT-03** | Extended Offline (72h+) | Offline for 3 days | Stay offline with pending items | Timers do not fire runaway loops; memory consumption remains constant (< 60MB). | VERIFIED |
| **BAT-OPT-04** | Polling Loop Audit | Device connected to network | Monitor network calls for 10 minutes idle | Zero periodic polling requests; sync is purely event-driven. | VERIFIED |

---

## 5. Authentication & Session Matrix

| ID | Test Scenario | Precondition | Execution Steps | Verification Criteria | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **AUT-SES-01** | Valid Session | Valid Supabase JWT | Execute sync | Requests succeed with `Authorization: Bearer <token>`. | VERIFIED |
| **AUT-SES-02** | Expired Access Token | Token expired | Trigger sync | Supabase SDK auto-refreshes token via refresh token; sync proceeds. | VERIFIED |
| **AUT-SES-03** | Refresh Failure / Revocation | Refresh token revoked | Trigger sync | Sync pauses; emits `auth_required`; user prompted to log in; queue preserved. | VERIFIED |
| **AUT-SES-04** | Concurrent Logout | Sync processing item 2 of 5 | Tap "Log Out" | `SyncEngine` halts immediately; item 3, 4, 5 not processed under unauthenticated state. | VERIFIED |

---

## 6. Realtime Lifecycle Matrix

| ID | Test Scenario | Precondition | Execution Steps | Verification Criteria | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **RLT-EVT-01** | WebSocket Disconnect | Active trip detail screen | Drop network for 10s then restore | Realtime channel reconnects; resubscribes to table events. | VERIFIED |
| **RLT-EVT-02** | Duplicate Event | Realtime delivers event twice | Send identical Postgres CDC payload | Second event discarded via version comparison ($V_{event} == V_{local}$). | VERIFIED |
| **RLT-EVT-03** | Stale / Out-of-Order Event | Local has $V=4$, event has $V=3$ | Deliver delayed payload | Event discarded; local SQLite remains at $V=4$. | VERIFIED |
| **RLT-EVT-04** | Anti-Resurrection | Entity deleted locally & server | Deliver delayed UPDATE event for deleted ID | Ignored; deleted entity is not resurrected. | VERIFIED |

---

## 7. SafeTrip Physical Safety Matrix

| ID | Test Scenario | Precondition | Execution Steps | Verification Criteria | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **SAF-VAL-01** | Offline Check-In | Offline | User taps "Check In" | Check-in logged to SQLite with `syncStatus = 'pending'`; UI clearly displays "Pending Network"; never falsely claims "Delivered". | VERIFIED |
| **SAF-VAL-02** | Check-In Network Recovery | Check-in pending in SQLite | Device regains network | `SyncEngine` uploads check-in with idempotency key; server confirms; status transitions to `'synced'`. | VERIFIED |
| **SAF-VAL-03** | Location Permission Revoked | SafeTrip journey active | User revokes GPS permission in OS settings | App displays alert; logs check-in with `location_unavailable`; app does not crash. | VERIFIED |
| **SAF-VAL-04** | Emergency SOS Offline Boundary | Offline | User triggers SOS | App presents offline warning; provides direct emergency phone dialing fallback (112/911); does NOT claim cloud dispatch. | VERIFIED |
