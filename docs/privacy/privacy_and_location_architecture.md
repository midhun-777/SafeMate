# SafeMate Privacy & Location Architecture

## 1. Core Principle: Privacy by Default
SafeMate enforces strict privacy controls adhering to Universal Engineering Rules #7 and #10:
- **No live, pinpoint GPS coordinate disclosure** to other users or public feeds.
- **No precise home or workplace address sharing**.
- **Coarse Geohash Precision (~20km)** for route recommendation and discovery.
- **Strict Row-Level Security (RLS)** in PostgreSQL/Supabase.

---

## 2. Profile Discovery States

Travelers control their visibility in `public.privacy_settings`:

| Visibility Mode | Behavior & Exposure |
| :--- | :--- |
| `public_to_matches` | Visible only to verified travelers with overlapping routes and compatible dates. |
| `private` | Visible only to approved connections. Hidden from recommendation feeds. |
| `hidden` | Completely invisible. Active journeys are paused from discovery. |

---

## 3. Trusted Emergency Contacts (Max 5)
- Travelers designate up to 5 emergency contacts (family, partner, trusted friends).
- Trusted contacts receive automated departure notifications via SMS/email upon trip initiation.
- Trusted contacts **NEVER** have access to chat histories, personal message bodies, or companion profile details.
- Contacts can be updated or removed at any time.

---

## 4. Confidential Safety Reporting & Anonymity
- Reports filed through `public.reports` are strictly confidential.
- The reported user **never** learns who filed the report or the exact context ID to protect reporting travelers from retaliation or harassment.
- Instant blocking (`public.blocks`) severs all connection state, message transport, and route matching instantaneously.

---

## 5. SafeTrip Real-Time Location Sharing (~20km Coarse Area)
- **Strictly Consent-Driven**: Location sharing mode defaults strictly to `OFF`.
- **Coarse Resolution**: When enabled with explicit traveler consent, only approximate city/transit region (~20km geohash) is shared with the traveler's designated trusted contact.
- **Time-Limited Sessions**: All location sharing sessions require a defined duration (1h, 2h, 4h, or journey arrival).
- **Auto-Revocation**: Sharing is automatically terminated immediately upon arrival confirmation (`ARRIVED`), trip cancellation (`CANCELLED`), or buffer timeout (`EXPIRED`).
- **Immediate Revocation**: Travelers can tap `[ Stop Sharing ]` at any time during an active SafeTrip without ending the journey.
- **Zero Coordinate Leakage**: Raw latitude and longitude coordinates are strictly prohibited from analytics, crash reports, debug logs, push notification previews, and URL parameters.
