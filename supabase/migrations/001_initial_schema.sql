-- ==============================================================================
-- SafeMate Canonical Initial Schema — Migration 001
-- SafeMate Universal Engineering Rules Compliant
-- ==============================================================================
-- 23 Core Entities:
--  1. users               2. profiles           3. verifications
--  4. travel_preferences  5. trips              6. trip_preferences
--  7. matches             8. match_events       9. connections
-- 10. chat_rooms         11. chat_members      12. messages
-- 13. reviews            14. reports           15. blocks
-- 16. safety_contacts    17. safety_events     18. journey_status
-- 19. notifications      20. subscriptions     21. payments
-- 22. admin_actions      23. audit_logs
-- ==============================================================================

-- Enable essential extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Helper function: Updated-at trigger
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- 1. USERS (Application User Registry mapped to auth.users)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    phone TEXT UNIQUE,
    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'moderator', 'admin')),
    is_suspended BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TRIGGER set_users_updated_at
BEFORE UPDATE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Helper function: Check if authenticated user is admin/moderator
CREATE OR REPLACE FUNCTION public.is_admin_or_moderator(check_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.users
        WHERE id = check_user_id AND role IN ('admin', 'moderator') AND is_suspended = FALSE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------------------------
-- 2. PROFILES (Public and companion profile details)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    bio TEXT,
    avatar_url TEXT,
    languages TEXT[] NOT NULL DEFAULT '{}',
    travel_styles TEXT[] NOT NULL DEFAULT '{}',
    trust_score INTEGER NOT NULL DEFAULT 0 CHECK (trust_score >= 0 AND trust_score <= 100),
    trips_completed INTEGER NOT NULL DEFAULT 0 CHECK (trips_completed >= 0),
    reliability_rating NUMERIC(3,2) NOT NULL DEFAULT 5.00 CHECK (reliability_rating >= 0.00 AND reliability_rating <= 5.00),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TRIGGER set_profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 3. VERIFICATIONS (Factual evidence signals, never "safe_person = true")
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE UNIQUE,
    phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
    phone_verified_at TIMESTAMPTZ,
    identity_verified BOOLEAN NOT NULL DEFAULT FALSE,
    identity_verified_at TIMESTAMPTZ,
    selfie_verified BOOLEAN NOT NULL DEFAULT FALSE,
    selfie_verified_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'unverified' CHECK (status IN ('unverified', 'pending', 'verified', 'rejected')),
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TRIGGER set_verifications_updated_at
BEFORE UPDATE ON public.verifications
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 4. TRAVEL_PREFERENCES (Pace, budget, transport, social energy)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.travel_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE UNIQUE,
    travel_pace TEXT NOT NULL DEFAULT 'moderate' CHECK (travel_pace IN ('slow', 'moderate', 'fast', 'flexible')),
    budget_tier TEXT NOT NULL DEFAULT 'moderate' CHECK (budget_tier IN ('backpacker', 'moderate', 'luxury', 'flexible')),
    preferred_transport TEXT[] NOT NULL DEFAULT '{}',
    smoking_preference TEXT NOT NULL DEFAULT 'non_smoker' CHECK (smoking_preference IN ('non_smoker', 'smoker', 'outside_only', 'flexible')),
    social_energy TEXT NOT NULL DEFAULT 'ambivert' CHECK (social_energy IN ('introvert', 'ambivert', 'extrovert', 'flexible')),
    dietary_preferences TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TRIGGER set_travel_preferences_updated_at
BEFORE UPDATE ON public.travel_preferences
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 5. TRIPS (User journeys with scalable geohashes for route matching)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    origin TEXT NOT NULL,
    destination TEXT NOT NULL,
    origin_geohash VARCHAR(12),
    destination_geohash VARCHAR(12),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    estimated_budget NUMERIC(10,2) CHECK (estimated_budget >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    transport_mode TEXT NOT NULL DEFAULT 'flexible' CHECK (transport_mode IN ('flight', 'train', 'road_trip', 'backpacking', 'cruise', 'flexible')),
    trip_purpose TEXT NOT NULL DEFAULT 'leisure' CHECK (trip_purpose IN ('leisure', 'adventure', 'workation', 'cultural', 'spiritual', 'other')),
    status TEXT NOT NULL DEFAULT 'planned' CHECK (status IN ('draft', 'planned', 'active', 'completed', 'cancelled')),
    max_companions INTEGER NOT NULL DEFAULT 3 CHECK (max_companions >= 1 AND max_companions <= 10),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT check_trip_dates CHECK (end_date >= start_date)
);

CREATE TRIGGER set_trips_updated_at
BEFORE UPDATE ON public.trips
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 6. TRIP_PREFERENCES (Trip-specific companion criteria)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.trip_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE UNIQUE,
    preferred_gender TEXT NOT NULL DEFAULT 'any' CHECK (preferred_gender IN ('any', 'female_only', 'male_only')),
    age_min INTEGER CHECK (age_min >= 18),
    age_max INTEGER CHECK (age_max >= age_min),
    require_verified_id BOOLEAN NOT NULL DEFAULT TRUE,
    flexible_dates_days INTEGER NOT NULL DEFAULT 0 CHECK (flexible_dates_days >= 0 AND flexible_dates_days <= 14),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TRIGGER set_trip_preferences_updated_at
BEFORE UPDATE ON public.trip_preferences
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 7. MATCHES (Deterministic scoring breakdown; AI only explains)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    candidate_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    candidate_trip_id UUID REFERENCES public.trips(id) ON DELETE SET NULL,
    compatibility_score INTEGER NOT NULL CHECK (compatibility_score >= 0 AND compatibility_score <= 100),
    score_breakdown JSONB NOT NULL DEFAULT '{}'::jsonb,
    status TEXT NOT NULL DEFAULT 'suggested' CHECK (status IN ('suggested', 'liked', 'passed', 'connected', 'expired')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT check_distinct_match_users CHECK (user_id != candidate_id),
    CONSTRAINT uq_user_candidate_trip UNIQUE (user_id, candidate_id, trip_id)
);

CREATE TRIGGER set_matches_updated_at
BEFORE UPDATE ON public.matches
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 8. MATCH_EVENTS (Audit log of match interactions)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.match_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID REFERENCES public.matches(id) ON DELETE CASCADE,
    actor_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN ('viewed', 'liked', 'passed', 'unmatched', 'reported')),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ------------------------------------------------------------------------------
-- 9. CONNECTIONS (Mutual companion connection state machine)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    trip_id UUID REFERENCES public.trips(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN ('requested', 'accepted', 'rejected', 'cancelled', 'blocked')),
    accepted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT check_distinct_connection_users CHECK (requester_id != receiver_id),
    CONSTRAINT uq_connection_pair_trip UNIQUE (requester_id, receiver_id, trip_id)
);

CREATE TRIGGER set_connections_updated_at
BEFORE UPDATE ON public.connections
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 10. CHAT_ROOMS (1:1 and Journey Room channels)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chat_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    connection_id UUID REFERENCES public.connections(id) ON DELETE CASCADE,
    room_type TEXT NOT NULL DEFAULT 'direct' CHECK (room_type IN ('direct', 'journey_room')),
    title TEXT,
    trip_id UUID REFERENCES public.trips(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TRIGGER set_chat_rooms_updated_at
BEFORE UPDATE ON public.chat_rooms
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 11. CHAT_MEMBERS (Room authorization and unread markers)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chat_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'admin')),
    last_read_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_room_member UNIQUE (room_id, user_id)
);

-- ------------------------------------------------------------------------------
-- 12. MESSAGES (Realtime delivery status and validation)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL CHECK (char_length(content) > 0 AND char_length(content) <= 4000),
    message_type TEXT NOT NULL DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'location_share', 'system_event')),
    status TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sending', 'sent', 'delivered', 'read', 'failed')),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TRIGGER set_messages_updated_at
BEFORE UPDATE ON public.messages
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 13. REVIEWS (Two-way reviews tied to completed journeys)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    reviewer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reviewee_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    punctuality_rating INTEGER CHECK (punctuality_rating >= 1 AND punctuality_rating <= 5),
    reliability_rating INTEGER CHECK (reliability_rating >= 1 AND reliability_rating <= 5),
    comment TEXT CHECK (char_length(comment) <= 1000),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT check_distinct_review_users CHECK (reviewer_id != reviewee_id),
    CONSTRAINT uq_trip_reviewer_reviewee UNIQUE (trip_id, reviewer_id, reviewee_id)
);

-- ------------------------------------------------------------------------------
-- 14. REPORTS (Safety reports with lifecycle handling)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reported_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    category TEXT NOT NULL CHECK (category IN ('harassment', 'scam', 'inappropriate_behavior', 'impersonation', 'no_show', 'safety_concern', 'other')),
    description TEXT NOT NULL CHECK (char_length(description) >= 10 AND char_length(description) <= 2000),
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'under_review', 'resolved', 'dismissed')),
    resolution_notes TEXT,
    resolved_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT check_distinct_report_users CHECK (reporter_id != reported_id)
);

CREATE TRIGGER set_reports_updated_at
BEFORE UPDATE ON public.reports
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 15. BLOCKS (Mutual exclusion across search, matching, and chat)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT check_distinct_block_users CHECK (blocker_id != blocked_id),
    CONSTRAINT uq_blocker_blocked UNIQUE (blocker_id, blocked_id)
);

-- Helper function: Check if two users have an active block between them
CREATE OR REPLACE FUNCTION public.is_blocked(user_a UUID, user_b UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.blocks
        WHERE (blocker_id = user_a AND blocked_id = user_b)
           OR (blocker_id = user_b AND blocked_id = user_a)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------------------------
-- 16. SAFETY_CONTACTS (Trusted emergency contacts)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.safety_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    contact_name TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    email TEXT,
    relationship TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    notify_on_trip_start BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TRIGGER set_safety_contacts_updated_at
BEFORE UPDATE ON public.safety_contacts
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 17. SAFETY_EVENTS (SOS triggers, check-in updates)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.safety_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    trip_id UUID REFERENCES public.trips(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL CHECK (event_type IN ('sos_triggered', 'sos_cancelled', 'checkin_completed', 'checkin_missed', 'route_deviation')),
    approx_latitude NUMERIC(10,6),
    approx_longitude NUMERIC(10,6),
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ------------------------------------------------------------------------------
-- 18. JOURNEY_STATUS (Active trip journey state and check-in scheduler)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.journey_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'planned' CHECK (status IN ('planned', 'active', 'paused', 'completed', 'emergency_alert')),
    last_checkin_at TIMESTAMPTZ,
    next_checkin_due TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_trip_user_journey UNIQUE (trip_id, user_id)
);

CREATE TRIGGER set_journey_status_updated_at
BEFORE UPDATE ON public.journey_status
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 19. NOTIFICATIONS (System, match, and safety notifications)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('match_found', 'connection_request', 'connection_accepted', 'message_received', 'safety_alert', 'checkin_reminder', 'review_received', 'system')),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ------------------------------------------------------------------------------
-- 20. SUBSCRIPTIONS (Server-verified premium tier)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE UNIQUE,
    tier TEXT NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'plus', 'premium')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'past_due', 'cancelled', 'expired')),
    valid_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TRIGGER set_subscriptions_updated_at
BEFORE UPDATE ON public.subscriptions
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 21. PAYMENTS (Audit receipt for server-side verification)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    amount NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    status TEXT NOT NULL CHECK (status IN ('pending', 'succeeded', 'failed', 'refunded')),
    provider TEXT NOT NULL,
    provider_payment_id TEXT NOT NULL UNIQUE,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TRIGGER set_payments_updated_at
BEFORE UPDATE ON public.payments
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 22. ADMIN_ACTIONS (Traceable administrative audit records)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.admin_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    target_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    action_type TEXT NOT NULL CHECK (action_type IN ('suspend_user', 'unsuspend_user', 'resolve_report', 'verify_identity', 'reject_identity', 'delete_content')),
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    ip_address INET,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ------------------------------------------------------------------------------
-- 23. AUDIT_LOGS (Immutable system and security audit trail)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id UUID,
    ip_address INET,
    user_agent TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ==============================================================================
-- AUTOMATIC USER REGISTRATION TRIGGER
-- Automatically populates public.users and public.profiles on signup
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email, phone, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.email, ''),
        NEW.phone,
        'user'
    )
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.profiles (id, display_name, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(COALESCE(NEW.email, 'Traveler'), '@', 1)),
        NEW.raw_user_meta_data->>'avatar_url'
    )
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.verifications (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;

    INSERT INTO public.travel_preferences (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;

    INSERT INTO public.subscriptions (user_id, tier, status)
    VALUES (NEW.id, 'free', 'active')
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger attached to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- INDEXES FOR HIGH-FREQUENCY OPERATIONS
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);
CREATE INDEX IF NOT EXISTS idx_profiles_trust_score ON public.profiles(trust_score DESC);
CREATE INDEX IF NOT EXISTS idx_verifications_status ON public.verifications(status);

-- Trips spatial and temporal indices
CREATE INDEX IF NOT EXISTS idx_trips_user_id ON public.trips(user_id);
CREATE INDEX IF NOT EXISTS idx_trips_status ON public.trips(status);
CREATE INDEX IF NOT EXISTS idx_trips_origin_geohash ON public.trips(origin_geohash);
CREATE INDEX IF NOT EXISTS idx_trips_destination_geohash ON public.trips(destination_geohash);
CREATE INDEX IF NOT EXISTS idx_trips_dates ON public.trips(start_date, end_date);

-- Matching indices
CREATE INDEX IF NOT EXISTS idx_matches_user_id ON public.matches(user_id);
CREATE INDEX IF NOT EXISTS idx_matches_candidate_id ON public.matches(candidate_id);
CREATE INDEX IF NOT EXISTS idx_matches_trip_id ON public.matches(trip_id);
CREATE INDEX IF NOT EXISTS idx_matches_status ON public.matches(status);
CREATE INDEX IF NOT EXISTS idx_matches_score ON public.matches(compatibility_score DESC);

-- Connection indices
CREATE INDEX IF NOT EXISTS idx_connections_requester ON public.connections(requester_id);
CREATE INDEX IF NOT EXISTS idx_connections_receiver ON public.connections(receiver_id);
CREATE INDEX IF NOT EXISTS idx_connections_status ON public.connections(status);

-- Chat indices
CREATE INDEX IF NOT EXISTS idx_chat_members_room ON public.chat_members(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_members_user ON public.chat_members(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_room_created ON public.messages(room_id, created_at DESC);

-- Safety & Moderation indices
CREATE INDEX IF NOT EXISTS idx_blocks_blocker ON public.blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocks_blocked ON public.blocks(blocked_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON public.reports(status);
CREATE INDEX IF NOT EXISTS idx_safety_contacts_user ON public.safety_contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_safety_events_user ON public.safety_events(user_id);
CREATE INDEX IF NOT EXISTS idx_journey_status_trip ON public.journey_status(trip_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON public.notifications(user_id, is_read, created_at DESC);

-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- Rule #7 & Rule #20: Zero trust on client, strict server enforcement
-- ==============================================================================

-- 1. users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own record and admins can view all"
ON public.users FOR SELECT
USING (auth.uid() = id OR public.is_admin_or_moderator(auth.uid()));

CREATE POLICY "Users can update their own non-role fields"
ON public.users FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id AND role = (SELECT role FROM public.users WHERE id = auth.uid()));

-- 2. profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profiles are viewable by authenticated users not blocked"
ON public.profiles FOR SELECT
USING (
    auth.role() = 'authenticated'
    AND NOT public.is_blocked(auth.uid(), id)
);

CREATE POLICY "Users can update their own profile"
ON public.profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- 3. verifications
ALTER TABLE public.verifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own verification signals"
ON public.verifications FOR SELECT
USING (auth.uid() = user_id OR public.is_admin_or_moderator(auth.uid()));

CREATE POLICY "Only admins can modify verification statuses"
ON public.verifications FOR UPDATE
USING (public.is_admin_or_moderator(auth.uid()));

-- 4. travel_preferences
ALTER TABLE public.travel_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Travel preferences viewable by authenticated non-blocked users"
ON public.travel_preferences FOR SELECT
USING (auth.role() = 'authenticated' AND NOT public.is_blocked(auth.uid(), user_id));

CREATE POLICY "Users can manage their own travel preferences"
ON public.travel_preferences FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 5. trips
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Active planned trips viewable by non-blocked authenticated users"
ON public.trips FOR SELECT
USING (
    auth.role() = 'authenticated'
    AND (auth.uid() = user_id OR (status IN ('planned', 'active') AND NOT public.is_blocked(auth.uid(), user_id)))
);

CREATE POLICY "Users can manage their own trips"
ON public.trips FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 6. trip_preferences
ALTER TABLE public.trip_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Trip preferences viewable along with trip"
ON public.trip_preferences FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.trips
        WHERE trips.id = trip_preferences.trip_id
          AND (trips.user_id = auth.uid() OR NOT public.is_blocked(auth.uid(), trips.user_id))
    )
);

CREATE POLICY "Trip owners manage their trip preferences"
ON public.trip_preferences FOR ALL
USING (
    EXISTS (SELECT 1 FROM public.trips WHERE trips.id = trip_preferences.trip_id AND trips.user_id = auth.uid())
)
WITH CHECK (
    EXISTS (SELECT 1 FROM public.trips WHERE trips.id = trip_preferences.trip_id AND trips.user_id = auth.uid())
);

-- 7. matches
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own matches"
ON public.matches FOR SELECT
USING (auth.uid() = user_id AND NOT public.is_blocked(auth.uid(), candidate_id));

CREATE POLICY "Users can update status on their own matches"
ON public.matches FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 8. match_events
ALTER TABLE public.match_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can create and view their own match events"
ON public.match_events FOR ALL
USING (auth.uid() = actor_id)
WITH CHECK (auth.uid() = actor_id);

-- 9. connections
ALTER TABLE public.connections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own connections"
ON public.connections FOR SELECT
USING (
    (auth.uid() = requester_id OR auth.uid() = receiver_id)
    AND NOT public.is_blocked(requester_id, receiver_id)
);

CREATE POLICY "Users can create connection requests"
ON public.connections FOR INSERT
WITH CHECK (auth.uid() = requester_id AND NOT public.is_blocked(requester_id, receiver_id));

CREATE POLICY "Participants can update connection status"
ON public.connections FOR UPDATE
USING (auth.uid() = requester_id OR auth.uid() = receiver_id)
WITH CHECK (auth.uid() = requester_id OR auth.uid() = receiver_id);

-- 10. chat_rooms
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view their chat rooms"
ON public.chat_rooms FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.chat_members
        WHERE chat_members.room_id = chat_rooms.id
          AND chat_members.user_id = auth.uid()
          AND chat_members.is_active = TRUE
    )
);

-- 11. chat_members
ALTER TABLE public.chat_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view other members of their rooms"
ON public.chat_members FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.chat_members AS cm
        WHERE cm.room_id = chat_members.room_id
          AND cm.user_id = auth.uid()
    )
);

-- 12. messages
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Room members can read messages"
ON public.messages FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.chat_members
        WHERE chat_members.room_id = messages.room_id
          AND chat_members.user_id = auth.uid()
          AND chat_members.is_active = TRUE
    )
);

CREATE POLICY "Room members can send messages"
ON public.messages FOR INSERT
WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
        SELECT 1 FROM public.chat_members
        WHERE chat_members.room_id = messages.room_id
          AND chat_members.user_id = auth.uid()
          AND chat_members.is_active = TRUE
    )
);

-- 13. reviews
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Completed journey reviews are public"
ON public.reviews FOR SELECT
USING (auth.role() = 'authenticated');

CREATE POLICY "Companions can submit reviews for their completed trips"
ON public.reviews FOR INSERT
WITH CHECK (
    auth.uid() = reviewer_id
    AND EXISTS (
        SELECT 1 FROM public.trips
        WHERE trips.id = reviews.trip_id
          AND trips.status = 'completed'
    )
);

-- 14. reports
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own submitted reports"
ON public.reports FOR SELECT
USING (auth.uid() = reporter_id OR public.is_admin_or_moderator(auth.uid()));

CREATE POLICY "Users can create reports"
ON public.reports FOR INSERT
WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Admins can update reports"
ON public.reports FOR UPDATE
USING (public.is_admin_or_moderator(auth.uid()));

-- 15. blocks
ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view and manage their block list"
ON public.blocks FOR ALL
USING (auth.uid() = blocker_id)
WITH CHECK (auth.uid() = blocker_id);

-- 16. safety_contacts
ALTER TABLE public.safety_contacts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage their own safety contacts"
ON public.safety_contacts FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 17. safety_events
ALTER TABLE public.safety_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users and admins view safety events"
ON public.safety_events FOR SELECT
USING (auth.uid() = user_id OR public.is_admin_or_moderator(auth.uid()));

CREATE POLICY "Users trigger safety events"
ON public.safety_events FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- 18. journey_status
ALTER TABLE public.journey_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Journey status viewable by journey companions and safety contacts"
ON public.journey_status FOR SELECT
USING (
    auth.uid() = user_id
    OR EXISTS (
        SELECT 1 FROM public.connections
        WHERE connections.trip_id = journey_status.trip_id
          AND (connections.requester_id = auth.uid() OR connections.receiver_id = auth.uid())
          AND connections.status = 'accepted'
    )
);

CREATE POLICY "Users update their own journey status"
ON public.journey_status FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 19. notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users view and manage their own notifications"
ON public.notifications FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 20. subscriptions
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users view their own subscription status"
ON public.subscriptions FOR SELECT
USING (auth.uid() = user_id OR public.is_admin_or_moderator(auth.uid()));

-- 21. payments
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users view their own payment receipts"
ON public.payments FOR SELECT
USING (auth.uid() = user_id OR public.is_admin_or_moderator(auth.uid()));

-- 22. admin_actions
ALTER TABLE public.admin_actions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Only admins can access admin action logs"
ON public.admin_actions FOR ALL
USING (public.is_admin_or_moderator(auth.uid()));

-- 23. audit_logs
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Only admins can view audit logs"
ON public.audit_logs FOR SELECT
USING (public.is_admin_or_moderator(auth.uid()));

CREATE POLICY "System functions can insert audit logs"
ON public.audit_logs FOR INSERT
WITH CHECK (auth.role() IN ('authenticated', 'service_role'));

-- ==============================================================================
-- END OF MIGRATION 001
-- ==============================================================================
