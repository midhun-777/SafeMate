# SafeMate — Database Architecture & Schema Guide

## 1. Overview

The SafeMate data layer is built on PostgreSQL 16+ via Supabase. It adheres strictly to the SafeMate Universal Engineering Rules:
- Referential and data integrity via foreign keys and check constraints.
- Privacy by design: no unbounded queries, explicit Row Level Security (RLS) on all tables.
- Separation of auth credentials from application profiles.
- Factual verification evidence (no false "safe_person = true" guarantees).

Migration File: `supabase/migrations/001_initial_schema.sql`

---

## 2. Core Entities (23 Tables)

| Table Name | Primary Key | Foreign Keys / Relations | Purpose & Security |
| :--- | :--- | :--- | :--- |
| `users` | `id UUID` | `auth.users(id) ON DELETE CASCADE` | Core application identity, email, role (`user`/`admin`). |
| `profiles` | `id UUID` | `public.users(id) ON DELETE CASCADE` | Public traveler profile, bio, languages, trust score. |
| `verifications` | `id UUID` | `user_id -> users(id)` | Factual signals (phone, ID, selfie). Admin-only updates. |
| `travel_preferences` | `id UUID` | `user_id -> users(id)` | Travel pace, budget tier, transport, social energy. |
| `trips` | `id UUID` | `user_id -> users(id)` | Journey details, dates, spatial geohashes (`origin_geohash`, `destination_geohash`). |
| `trip_preferences` | `id UUID` | `trip_id -> trips(id)` | Companion criteria for specific trips. |
| `matches` | `id UUID` | `user_id`, `candidate_id`, `trip_id` | Deterministic score (0-100) & breakdown JSONB. |
| `match_events` | `id UUID` | `match_id`, `actor_id` | Audit trail of swipes/likes/passes. |
| `connections` | `id UUID` | `requester_id`, `receiver_id`, `trip_id` | Mutual connection state machine. |
| `chat_rooms` | `id UUID` | `connection_id`, `trip_id` | 1:1 and Journey Room chat channels. |
| `chat_members` | `id UUID` | `room_id`, `user_id` | Room membership, unread message tracking. |
| `messages` | `id UUID` | `room_id`, `sender_id` | Realtime messages with delivery status. |
| `reviews` | `id UUID` | `trip_id`, `reviewer_id`, `reviewee_id` | Two-way companion reviews for completed journeys. |
| `reports` | `id UUID` | `reporter_id`, `reported_id` | Safety reporting with resolution workflow. |
| `blocks` | `id UUID` | `blocker_id`, `blocked_id` | Mutual exclusion from search, matching, and chat. |
| `safety_contacts` | `id UUID` | `user_id` | Trusted emergency contacts (phone, relationship). |
| `safety_events` | `id UUID` | `user_id`, `trip_id` | SOS triggers, missed check-ins. |
| `journey_status` | `id UUID` | `trip_id`, `user_id` | Active journey status (`planned`, `active`, `completed`). |
| `notifications` | `id UUID` | `user_id` | In-app alerts, matches, and safety updates. |
| `subscriptions` | `id UUID` | `user_id` | Server-verified subscription tier (`free`, `premium`). |
| `payments` | `id UUID` | `user_id` | Audit receipts of payment transactions. |
| `admin_actions` | `id UUID` | `admin_id`, `target_user_id` | Traceable moderator and admin actions. |
| `audit_logs` | `id UUID` | `actor_id` | Immutable security access and change logs. |

---

## 3. Row Level Security (RLS) Strategy

Every table has `ALTER TABLE ... ENABLE ROW LEVEL SECURITY;`.
- **Private Data:** Only the owning user (`auth.uid() = user_id`) can view/update their records (`safety_contacts`, `subscriptions`, `verifications`, `notifications`).
- **Mutual Interactions:** Chat messages and rooms can only be accessed if the user is an active member in `chat_members`.
- **Block Protection:** Profiles, trips, matches, connections, and chat rooms automatically invoke `public.is_blocked(auth.uid(), other_id)` to ensure blocked users cannot observe or interact with each other.
- **Admin Isolation:** Admin operations (`admin_actions`, `audit_logs`, verification updates) require `public.is_admin_or_moderator(auth.uid())`.

---

## 4. Applying the Migration

To apply this migration to a local or hosted Supabase environment:

```bash
# Using Supabase CLI (local development)
supabase db reset

# Or apply migration directly
supabase migration up
```
