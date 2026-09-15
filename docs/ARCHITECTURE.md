# SafeMate — Architecture Documentation

## 1. System Overview

SafeMate is a high-trust companion matching and safety platform designed to help people find compatible, verified travel companions and travel together safely.

```
┌────────────────────────────────────────────────────────┐
│                   SafeMate Mobile App                  │
│             (Flutter 3.47+ / Android & iOS)            │
│  UI Layer (Screens, Widgets, Semantic Accessibility)   │
│  State Management (flutter_riverpod)                   │
│  Domain & Service Layer (Clean Architecture)           │
└───────────────┬────────────────────────┬───────────────┘
                │                        │
       HTTPS / REST (Supabase)           │ WebSockets (Realtime)
                │                        │
┌───────────────▼────────────────────────▼───────────────┐
│              Backend Infrastructure (Supabase)         │
│  ┌──────────────────┐  ┌────────────────────────────┐  │
│  │ Supabase Auth    │  │ Realtime Engine            │  │
│  │ (PKCE, Sessions) │  │ (Channels, Pub/Sub)        │  │
│  └──────────────────┘  └────────────────────────────┘  │
│  ┌──────────────────┐  ┌────────────────────────────┐  │
│  │ PostgreSQL 16+   │  │ Storage Buckets            │  │
│  │ (23 Tables, RLS) │  │ (Avatars, Verification IDs)│  │
│  └──────────────────┘  └────────────────────────────┘  │
│  ┌──────────────────┐  ┌────────────────────────────┐  │
│  │ Edge Functions   │  │ AI Gateway (Gemini API)    │  │
│  │ (Server Auth)    │  │ (Match & Safety Signals)   │  │
│  └──────────────────┘  └────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

---

## 2. Directory Structure

```
lib/
├── app/
│   ├── app.dart                   # SafeMateApp root widget with theme & GoRouter
│   └── routes.dart                # Central GoRouter declarative route table & auth boundaries
│
├── core/
│   ├── config/
│   │   └── app_config.dart        # Compile-time environment configuration (--dart-define)
│   ├── constants/
│   │   └── app_colors.dart        # Calm, trustworthy SafeMate color palette
│   ├── errors/
│   │   └── app_exception.dart     # Domain exceptions and structured failure types
│   ├── network/
│   │   └── supabase_client.dart   # Supabase client singleton & PKCE auth manager
│   ├── security/
│   │   └── secure_storage_service.dart # FlutterSecureStorage (Keystore/Keychain)
│   ├── theme/
│   │   └── app_theme.dart         # Material 3 Light & Dark themes
│   └── utils/
│       └── geohash_helper.dart    # Geohash spatial encoding for scalable route queries
│
└── features/
    ├── auth/
    │   ├── domain/models/user_session.dart
    │   └── presentation/screens/
    │       ├── splash_screen.dart
    │       └── auth_landing_screen.dart
    ├── trips/
    │   ├── domain/models/trip.dart
    │   └── presentation/screens/trips_home_screen.dart
    ├── matching/
    │   ├── domain/models/match_result.dart
    │   └── domain/services/compatibility_scorer.dart
    ├── connections/
    │   └── domain/models/connection.dart
    └── safety/
        └── domain/models/safety_contact.dart

supabase/
└── migrations/
    └── 001_initial_schema.sql     # Canonical 23-entity PostgreSQL migration with RLS

test/
├── core/
│   ├── config_test.dart
│   ├── geohash_helper_test.dart
│   └── security_test.dart
└── features/
    ├── connections/connection_model_test.dart
    ├── matching/compatibility_scorer_test.dart
    └── trips/trip_model_test.dart
```

---

## 3. Security Model

1. **Zero Client Secrets:** The mobile client only holds the public Supabase anonymous key (`SUPABASE_ANON_KEY`). Service-role keys are strictly forbidden in client code.
2. **Server-Side Enforcement (Rule #7 & #13):** Client claims (user ID, roles, verification status) are never trusted. All access is governed by PostgreSQL Row Level Security (RLS) evaluated against `auth.uid()`.
3. **Session Token Protection:** Session tokens are stored in hardware-backed storage (`flutter_secure_storage` using Android `EncryptedSharedPreferences` and iOS `KeychainServices`).
4. **Mutual Exclusion (Blocks):** When User A blocks User B, the server-side `is_blocked(user_a, user_b)` function automatically purges and denies all search results, matching events, connection queries, and chat messages between both parties.

---

## 4. Environment Variables

Variables are configured via `--dart-define` at compile time or `.env` during local development:

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `APP_ENV` | Environment identifier | `development` / `staging` / `production` |
| `SUPABASE_URL` | Supabase API endpoint | `https://your-project.supabase.co` |
| `SUPABASE_ANON_KEY` | Public anon key | `your-anon-key` |
| `ENABLE_JOURNEY_COPILOT` | AI assistant feature flag | `false` |
| `ENABLE_PASSIVE_SAFETY_ALERTS` | Safety alert engine | `true` |

---

## 5. Development & Testing Commands

```bash
# Fetch and update dependencies
flutter pub get

# Run static analysis
dart analyze

# Run all unit and domain test suites
flutter test

# Build debug APK for Android
flutter build apk --debug
```
