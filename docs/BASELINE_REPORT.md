# SAFEMATE ENGINEERING BASELINE REPORT

**Project:** SafeMate  
**Auditor:** Principal Software & Security Architect  
**Date:** September 15, 2026  
**Status:** Audit Completed — Greenfield Repository Confirmed  

---

## 1. Overall Project Health Score: 15 / 100

| Area | Score | Notes |
| :--- | :---: | :--- |
| **Toolchain & Environment** | 95/100 | Flutter 3.47.2, Dart 3.13.2, Android SDK 36.0.0, Visual Studio 2026 C++, Chrome all ready. |
| **Repository Hygiene** | 90/100 | Clean git repository (`midhun-777/SafeMate`), valid MIT License, zero git conflicts, zero tech debt. |
| **Application Code** | 0/100 | Greenfield state — no application scaffold, `pubspec.yaml`, or source code exists yet. |
| **Database & Schema** | 0/100 | 0 of 23 required SafeMate tables/entities exist. No migrations or RLS policies in place. |
| **Authentication & Security** | 0/100 | No auth flows, session handlers, role checks, or `.gitignore` secret protections configured. |
| **Realtime Infrastructure** | 0/100 | No WebSocket/Supabase Realtime channels or synchronization layer configured. |
| **AI Integration** | 0/100 | No AI copilot, moderation, or compatibility scoring layer implemented. |
| **Test Coverage** | 0/100 | 0 automated unit, widget, integration, or security tests. |
| **Weighted Total** | **15 / 100** | **Clean Slate / High Readiness for Structured Scaffold** |

---

## 2. Technology Stack

### Detected Environment & Target Toolchain
- **Host OS:** Microsoft Windows 11 (Build 26200.9445)
- **Primary Client Framework:** Flutter 3.47.2 (Channel `stable`, engine `1cf1c4773f`)
- **Language:** Dart 3.13.2
- **Mobile Target:** Android SDK version 36.0.0 (API Level 36)
- **Desktop Target:** Windows Desktop (Visual Studio Community 2026 18.9.2)
- **Web Targets:** Google Chrome 153.0.8010.36, Microsoft Edge 153.0.4234.32
- **Backend & Database Target (Recommended):** PostgreSQL 16+ via Supabase (Auth, Row Level Security, Realtime, Storage, Edge Functions)
- **AI Integration Target:** Google Gen AI SDK (Gemini 2.5/Flash) for match explanations, safety signal analysis, and trip copilot.
- **Repository Remote:** `https://github.com/midhun-777/SafeMate.git` (`main` branch)

---

## 3. Architecture Summary

### Current Repository State
- Repository contains only: [LICENSE](file:///c:/Users/chand/SafeMate/LICENSE) (MIT License, Copyright 2026 midhun-777).
- Commit history: 1 commit (`f6aafa2 Initial commit`).
- No source tree, no build configuration files, no environment files.

### Desired Production Architecture
```
┌────────────────────────────────────────────────────────┐
│                   SafeMate Mobile App                  │
│             (Flutter 3.47+ / Android & iOS)            │
│  UI Layer (Screens & Widgets)                          │
│  State Management (Riverpod / BLoC)                    │
│  Domain & Service Layer (Repository Pattern)           │
└───────────────┬────────────────────────┬───────────────┘
                │                        │
       HTTPS / REST / gRPC               │ WebSockets (Realtime)
                │                        │
┌───────────────▼────────────────────────▼───────────────┐
│              Backend Infrastructure (Supabase)         │
│  ┌──────────────────┐  ┌────────────────────────────┐  │
│  │ Auth & Sessions  │  │ Realtime Engine (Pub/Sub)  │  │
│  └──────────────────┘  └────────────────────────────┘  │
│  ┌──────────────────┐  ┌────────────────────────────┐  │
│  │ PostgreSQL 16+   │  │ Storage Buckets            │  │
│  │ (RLS + Triggers) │  │ (ID Verification, Media)   │  │
│  └──────────────────┘  └────────────────────────────┘  │
│  ┌──────────────────┐  ┌────────────────────────────┐  │
│  │ Edge Functions   │  │ AI Gateway (Gemini API)    │  │
│  │ (Server Auth)    │  │ Match & Safety Signals     │  │
│  └──────────────────┘  └────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

---

## 4. Build Status

- **Status:** 🔴 CRITICAL (Blocked)
- **Details:** Neither `pubspec.yaml` nor client/backend project files exist in the repository. Running build commands (`flutter build`, `dart analyze`) fails due to the absence of project configuration.
- **Remediation:** Initialize standard Flutter project structure with designated bundle identifier (`com.safemate.app`), configure build targets, and set up `.gitignore`.

---

## 5. Test Status

- **Status:** 🔴 CRITICAL (0% Coverage)
- **Existing Tests:** None (`test/` directory does not exist).
- **Required Suites Before Beta:**
  1. Unit tests for Matching Algorithm and Compatibility Scorer.
  2. Unit tests for Verification & Trust Score calculator.
  3. Integration tests for Auth & Protected Routes.
  4. Integration tests for Realtime Chat delivery states (`sending`, `sent`, `delivered`, `read`, `failed`).
  5. Security tests verifying Row Level Security (RLS) enforcement.

---

## 6. Security Status

### Findings
- 🔴 **CRITICAL — Missing `.gitignore`:** The repository currently has no `.gitignore`. Creating files without a strict `.gitignore` could lead to accidental commits of API keys, `.env` files, Supabase service keys, keystores, or platform build artifacts.
- 🔴 **CRITICAL — Client-Side Security Isolation:** No server-side boundary or security policies exist yet. As mandated by Rule #7 & Rule #13, all sensitive claims (verification status, moderation, payment, matching authorization) must be enforced via PostgreSQL Row Level Security (RLS) and trusted backend functions.
- 🟠 **HIGH — Secret Management:** Need clear segregation between `anon/public` keys and `service_role` secrets. Zero secrets must be embedded in the mobile binary.

---

## 7. Database Status

### Entity Audit (23 Core Entities Required by Constitution)

| Entity Name | Status | RLS Required | Notes / Purpose |
| :--- | :---: | :---: | :--- |
| `users` | ❌ Missing | Yes | Core auth identity mapping |
| `profiles` | ❌ Missing | Yes | Public & companion profile, bio, languages, stats |
| `verifications` | ❌ Missing | Yes | ID, selfie, phone, trust badges (factual signals) |
| `travel_preferences` | ❌ Missing | Yes | Pace, budget tier, transport, smoking, social energy |
| `trips` | ❌ Missing | Yes | Origin, destination, route, date range, transport mode |
| `trip_preferences` | ❌ Missing | Yes | Trip-specific companion criteria |
| `matches` | ❌ Missing | Yes | Matched pairs/groups, score, explainable breakdown |
| `match_events` | ❌ Missing | Yes | Audit log of match interactions (seen, skipped, saved) |
| `connections` | ❌ Missing | Yes | Confirmed companion connections (mutual agreement) |
| `chat_rooms` | ❌ Missing | Yes | 1:1 and Journey Room chat channels |
| `chat_members` | ❌ Missing | Yes | Participant roles, active status, last read marker |
| `messages` | ❌ Missing | Yes | Encrypted/validated messages, status, attachments |
| `reviews` | ❌ Missing | Yes | Post-journey 2-way reviews, punctuality, reliability |
| `reports` | ❌ Missing | Yes | User safety reports with category, evidence, state |
| `blocks` | ❌ Missing | Yes | Mutual exclusion across search, match, and chat |
| `safety_contacts` | ❌ Missing | Yes | Trusted emergency contacts (phone, email, relation) |
| `safety_events` | ❌ Missing | Yes | Check-in missed, SOS trigger, route deviation |
| `journey_status` | ❌ Missing | Yes | Real-time journey state (planned, active, completed) |
| `notifications` | ❌ Missing | Yes | System, safety, and match notifications |
| `subscriptions` | ❌ Missing | Yes | Premium tier status (validated server-side) |
| `payments` | ❌ Missing | Yes | Transaction records & payment webhook receipts |
| `admin_actions` | ❌ Missing | Yes | Audit trail for moderation/admin interventions |
| `audit_logs` | ❌ Missing | Yes | Immutable system security and access logs |

---

## 8. Authentication Audit

- **Current State:** ❌ Completely Missing
- **Requirements:**
  - Email/Password & Phone OTP authentication.
  - Secure session storage (Flutter Secure Storage / platform keychain).
  - Strict token refresh mechanism.
  - Client state must never assume roles or verification status: all profile claims must be fetched from authenticated DB views protected by RLS.

---

## 9. Realtime Audit

- **Current State:** ❌ Completely Missing
- **Requirements:**
  - Supabase Realtime / WebSocket channel abstraction.
  - Message state machine: `pending` → `sent` → `delivered` → `read`.
  - Reconnection resilience: offline queue with idempotent retry IDs.
  - Presence tracking (companion online/in-transit status) without exposing fine-grained coordinates.

---

## 10. AI Audit

- **Current State:** ❌ No Integration Present
- **Safety & Architecture Boundary (Rule #10):**
  - AI is strictly an assistant, never an authoritative judge.
  - **Planned Features:**
    1. *Match Reason Explainer:* Explains compatibility (e.g. "92% Compatibility: Shared route, matching pace, overlapping dates") without hallucination.
    2. *SafeMate Journey Assistant:* Itinerary suggestions, packing essentials, safety checklist.
    3. *Scam & Risk Detection (Passive):* Scans chat messages for off-platform financial manipulation or pressure signals and presents calm safety alerts.

---

## 11. Product MVP Flow Matrix

| Step | Flow Step | Status | Blockers |
| :---: | :--- | :---: | :--- |
| 1 | **Login / Register** | ❌ Missing | Auth service not initialized |
| 2 | **Profile Setup** | ❌ Missing | Profile entity and UI absent |
| 3 | **Verification** | ❌ Missing | Storage bucket & verification flow absent |
| 4 | **Create Trip** | ❌ Missing | Trip schema & creation forms absent |
| 5 | **Trip Preferences** | ❌ Missing | Matching filters absent |
| 6 | **Matching Engine** | ❌ Missing | Algorithmic scoring service absent |
| 7 | **Compatibility Score** | ❌ Missing | Breakdown & explainability logic absent |
| 8 | **Trust Profile** | ❌ Missing | Verification badges & review display absent |
| 9 | **Connect / Request** | ❌ Missing | Mutual connection request state machine absent |
| 10 | **Realtime Chat** | ❌ Missing | Realtime messaging & UI absent |
| 11 | **SafeTrip (Active Journey)** | ❌ Missing | Emergency check-in & status tracker absent |
| 12 | **Journey Completion** | ❌ Missing | State transition & completion event absent |
| 13 | **Review & Reputation** | ❌ Missing | Review submission & trust update absent |

---

## 12. UX Audit

- **Current State:** ❌ No UI present.
- **Guiding Directive (Rule #1 & #18):**
  - "Find the right people for your journey."
  - Avoid dating-app swipe mechanics.
  - Avoid flashy or fear-inducing UI.
  - Require explicit UX states on all async operations: `Initial`, `Loading`, `Success`, `Empty`, `Error`, `Offline`, `Retry`.

---

## 13. Performance Audit

- **Current State:** Greenfield — 0 performance debt.
- **Architectural Guardrails Established:**
  - Route matching must use indexed geospatial or geographic queries (`origin_geohash`, `destination_geohash`, date range indices).
  - Unbounded queries strictly prohibited; standard pagination (`limit`/`offset` or cursor-based) required.
  - Image assets must be compressed client-side before upload to storage buckets.

---

## 14. Testing Audit

- **Target Coverage:**
  - Core Domain & Matching Logic: >90%
  - Repositories & Data Serialization: >85%
  - Critical UI Widgets (Safety SOS, Chat, Trip Form): >80%

---

## 15. Dependency Audit

- **Current Dependencies:** 0 (clean repository).
- **Vetted Dependencies to Add (Phase 3 Foundation):**
  - `supabase_flutter` — Official Supabase SDK for Auth, Database, Realtime, and Storage.
  - `flutter_riverpod` (or `flutter_bloc`) — Predictable, testable reactive state management.
  - `go_router` — Declarative routing with redirect guards for authentication states.
  - `flutter_secure_storage` — Encrypted keychain/keystore storage for session tokens.
  - `google_generative_ai` — Official Google GenAI SDK for Gemini API integration.
  - `uuid` / `intl` — Essential data formatting and identity utilities.

---

## 16. SafeMate Architecture Gap Analysis

| Layer | Expected Component | Current State | Gap / Action Required |
| :--- | :--- | :---: | :--- |
| **Client** | Flutter 3.47+ Mobile Client | ❌ Absent | Scaffold Flutter app structure with clean architecture |
| **Routing** | Declarative Router | ❌ Absent | Implement `go_router` with auth state listeners |
| **State** | Reactive State Layer | ❌ Absent | Setup Riverpod providers for auth, trips, chat |
| **Auth** | Supabase Auth Client | ❌ Absent | Integrate email/OTP signup, login, session restore |
| **Database** | PostgreSQL 16 on Supabase | ❌ Absent | Author complete SQL migration for the 23 core entities |
| **Security** | Row Level Security (RLS) | ❌ Absent | Write explicit RLS policies for every table |
| **Realtime** | WebSocket Pub/Sub Channels | ❌ Absent | Create chat & journey status realtime subscribers |
| **Storage** | Object Storage Buckets | ❌ Absent | Configure buckets for profile avatars and ID documents |
| **Safety** | SOS & Emergency Contacts | ❌ Absent | Build check-in timers, emergency contact alerts |
| **AI Layer** | Gemini Copilot & Explainer | ❌ Absent | Build structured prompt client with fallback handling |

---

## 17. Priority Plan

### P0 — BLOCKERS (Immediate Foundation)
1. **Repository Security & Foundation:** Add comprehensive `.gitignore` (Flutter, Dart, Android, iOS, Windows, `.env`).
2. **Flutter App Initialization:** Initialize the Flutter mobile application structure conforming to Universal Engineering Rules.
3. **Database Schema & RLS Migrations:** Write the canonical PostgreSQL SQL schema creating all 23 entities with foreign keys, indexes, check constraints, and RLS policies.
4. **Environment & Supabase Client Setup:** Configure secure environment variable handling and Supabase client singleton with offline resilience.
5. **Authentication Flow:** Complete registration, login, logout, session persistence, and auth guard routing.

### P1 — MVP CORE (Beta Release)
1. **Profile & Verification:** Profile creation, travel style questionnaire, trust badges, factual verification signals.
2. **Trip Management:** Create trip, set dates/route/budget/transport, edit/cancel trips.
3. **Matching Engine:** Deterministic rule-based filter + compatibility scoring algorithm with explainable match reasons.
4. **Connections & Messaging:** Connection request state machine (requested, accepted, rejected), 1:1 realtime chat with delivery statuses.
5. **Safety Core:** Trusted safety contacts, check-in button, active journey status, emergency guidance.
6. **Trip Completion & Reviews:** Journey completion trigger, bilateral companion reviews with reliability scoring.
7. **Safety Center:** In-app reporting, user blocking (instant exclusion from search/chat).

### P2 — IMPORTANT (Post-Beta Enhancements)
1. **AI Journey Copilot:** Gemini-powered itinerary suggestion, weather/safety advisory, match reason synthesizer.
2. **Journey Rooms:** Multi-companion group chat for shared road trips/treks.
3. **Push Notifications:** FCM integration for connection requests, messages, and safety check-ins.
4. **Advanced Privacy Controls:** Invisible mode, location obfuscation (city-level only until connected).

### P3 — FUTURE
1. **Travel Commerce & Bookings:** Partner host/hotel/ride integrations.
2. **Multi-hop Route Matching:** Dynamic corridor matching for companions joining along en-route waypoints.

---

## 18. Recommended Next Task

**Task:** **Phase 3 — Repository Foundation & Canonical Database Schema Definition**  
1. Create a robust, multi-platform `.gitignore` preventing any secret leakage.
2. Initialize the clean Flutter application structure (`lib/core`, `lib/features`, `test/`).
3. Author the complete, production-grade SQL migration script (`supabase/migrations/001_initial_schema.sql`) covering all 23 core entities, foreign key constraints, indexes, and comprehensive Row Level Security (RLS) policies.
4. Verify build and static analysis readiness.

---
