# SafeMate Phase 10: SafeTrip Real-Time Journey Safety Architecture

## 1. Executive Overview

SafeMate SafeTrip provides a privacy-first, consent-driven, server-authoritative real-time journey safety layer.

> **Core Promise**: *"The traveler is always in control of what SafeMate shares, with whom, and for how long."*
> **Safety Disclaimer**: SafeMate assists travelers with check-ins and emergency contact notifications, but **never guarantees absolute personal safety** and **never makes autonomous emergency dispatch decisions**.

---

## 2. SafeTrip State Machine

The SafeTrip lifecycle is deterministic, server-authoritative, and audited.

```text
PREPARING → READY
READY → ACTIVE
ACTIVE → PAUSED
PAUSED → ACTIVE
ACTIVE → ARRIVED
ARRIVED → COMPLETED
READY → CANCELLED
ACTIVE → CANCELLED
ACTIVE → EXPIRED
PAUSED → EXPIRED
```

### State Definitions
- **PREPARING**: Journey parameters gathered, consent checklist displayed.
- **READY**: Trip is valid, published, and requirements satisfied. Ready for explicit traveler activation.
- **ACTIVE**: Journey in progress. Periodic check-in reminders scheduled. Location sharing active if consented.
- **PAUSED**: Traveler temporarily pauses check-ins (e.g. airport layover).
- **ARRIVED**: Traveler explicitly confirms safe arrival. Location sharing terminated automatically.
- **COMPLETED**: Journey safely closed; two-way companion reviews unlocked.
- **CANCELLED**: Traveler terminates SafeTrip early.
- **EXPIRED**: Journey exceeded expected arrival time plus configured safety buffer.

---

## 3. Explicit Consent Model

Consent is granular and never bundled. Before activation, the traveler reviews 3 distinct toggles:

1. **Journey Status Sharing**: Notifies designated trusted contact upon start, successful check-ins, and arrival.
2. **Approximate Location Sharing**: Shares coarse transit area (~20km geohash) only during active journey. Defaults to `OFF`.
3. **Check-in Reminders**: Periodic non-alarming prompts ("I'm OK").

---

## 4. Location Privacy & Storage

- **Default State**: Strictly `OFF`.
- **Resolution**: Approximate (~20km geohash). Never raw GPS or home coordinates.
- **Expiry**: Tied to arrival, cancellation, or explicit session timer (1h, 2h, 4h).
- **Zero Coordinate Leakage**: Raw latitude and longitude are forbidden in analytics, logs, push notifications, and URLs.
- **Revocation**: Can be stopped immediately via `[ Stop Sharing ]` without cancelling the trip.

---

## 5. Check-In & Non-Alarming Escalation

```text
Check-in Deadline
       ↓
Configured Grace Period (e.g. 15 min)
       ↓
Gentle Reminder Notification
       ↓
No Confirmation ("Missed Check-in")
       ↓
Trusted Contact Notification (If Consented)
       ↓
Traveler Confirms "I'm OK" OR Chooses "Need Help"
```

> [!IMPORTANT]
> **A missed check-in is NOT treated as proof of danger.** Language remains calm and informative. No alarming red flashing banners or panic alerts are shown.

---

## 6. Realtime Architecture

- Scoped channels: `safe_trip:{journey_id}`.
- Restricted to journey owner, authorized companion, and authorized safety contact.
- Supported events:
  - `journey_activated`
  - `checkin_completed`
  - `checkin_missed`
  - `arrival_confirmed`
  - `location_sharing_started`
  - `location_sharing_stopped`
  - `journey_completed`

---

## 7. Emergency Boundary & Threat Model

- **No Fake Emergency Calls**: SafeMate does not simulate 911/112 auto-dialing or fake police dispatch.
- **Dialer Boundary**: Traveler is prompted to connect directly using their native phone dialer for local emergency services.
- **Threat Mitigations**:
  - Replay attacks prevented via client idempotency keys (`idempotency_key`).
  - Unauthorized viewing prevented via Row Level Security (RLS) on `safe_trips`, `journey_checkins`, and `location_share_sessions`.
  - Anti-enumeration: UUID primary keys; third parties receive empty results.
