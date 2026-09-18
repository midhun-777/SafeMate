# SafeMate Battery, Power & Background Execution Profile
**Phase 12.5 Production Offline Reliability & Resource Hardening**

This document establishes the verified battery consumption, wakefulness, and memory performance constraints of SafeMate's offline-first architecture.

---

## 1. Background Execution & Wakeup Policy

### Non-Negotiable Principle
**SafeMate never registers unrestricted background execution, persistent OS wakelocks, or unconstrained sync timers.**

### Trigger Boundaries
Sync dispatch occurs strictly across three event-driven boundaries:
1. **Direct Traveler Interaction (Foreground)**: Enqueueing a mutation while online triggers an immediate single-flight sync attempt.
2. **Network Handover / Reconnect (Event-Driven)**: `ConnectivityService` listens to OS network interface events. On transitioning from offline to online, a single queue flush is scheduled.
3. **Application Foregrounding (`AppLifecycleState.resumed`)**: When the traveler brings SafeMate back to the foreground, in-flight pending conflicts and unsynced counts are updated.

---

## 2. Battery Conservation & Anti-Throttling Architecture

| Component | Architecture | Power Optimization |
| :--- | :--- | :--- |
| **Connectivity Monitoring** | `connectivity_plus` broadcast stream + lazy DNS probe (`dns.google`). | DNS probes are strictly throttled to $\ge 45\text{s}$ intervals. Prevents cellular radio ramp-up loops when network is unstable. |
| **Retry Backoff Engine** | Bounded Exponential Backoff: $\min(2^{\text{retry}}, 60) + \text{jitter}$ seconds. | Maximum retry cap is 5 attempts. Permanent, validation, and authentication errors immediately pause retry to prevent runaway battery drain. |
| **Single-Flight Lock** | In-memory `_isSyncing` mutex lock. | Concurrent mutations coalesce into one sequential queue worker. Zero duplicate background threads or competing SQLite writes. |
| **Realtime WebSockets** | Channels subscribe only for active user-scoped tables while foregrounded. | WebSockets disconnect cleanly during long background periods and resubscribe upon app resumption without lingering listeners. |
| **SafeTrip Check-In Processing** | Offline check-ins are journaled to SQLite instantly in a single transaction (< 15ms). | No GPS location polling when permission is off or approximate mode is selected. Radio sleep states are respected. |

---

## 3. Memory Bounds & Heap Profile

- **Queue Query Paging**: `sync_queue` items are retrieved in bounded batches (`LIMIT 20`), ensuring queue processing heap usage remains $< 2\text{MB}$ even with hundreds of pending operations.
- **SQLite WAL Mode**: SQLite operates with Write-Ahead Logging (`PRAGMA journal_mode = WAL; PRAGMA synchronous = NORMAL;`), preventing database locking stalls and minimizing flash write cycles.
- **Subscription Teardown**: All Riverpod providers and stream controllers invoke `ref.onDispose()` to unregister event listeners, eliminating memory leaks across screen navigation and session switches.
