-- ==============================================================================
-- SAFEMATE MIGRATION 007: SAFETRIP REAL-TIME JOURNEY SAFETY (PHASE 10)
-- Universal Engineering Rule #6: Strict domain boundaries, privacy-safe identity
-- Universal Engineering Rule #7: Zero trust on client, strict server enforcement
-- Universal Engineering Rule #11: Deterministic state machines & safe transitions
-- Universal Engineering Rule #18: Server state must be authoritative
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Create public.safe_trips (Active supervised journeys)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.safe_trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    companion_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    trusted_contact_id UUID REFERENCES public.safety_contacts(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'preparing'
        CHECK (status IN ('preparing', 'ready', 'active', 'paused', 'arrived', 'completed', 'cancelled', 'expired')),
    expected_start_time TIMESTAMPTZ NOT NULL,
    expected_arrival_time TIMESTAMPTZ NOT NULL,
    actual_arrival_time TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    checkin_interval_minutes INTEGER NOT NULL DEFAULT 60
        CHECK (checkin_interval_minutes >= 15 AND checkin_interval_minutes <= 360),
    grace_period_minutes INTEGER NOT NULL DEFAULT 15
        CHECK (grace_period_minutes >= 5 AND grace_period_minutes <= 60),
    last_checkin_at TIMESTAMPTZ,
    next_checkin_deadline TIMESTAMPTZ,
    location_sharing_mode TEXT NOT NULL DEFAULT 'off'
        CHECK (location_sharing_mode IN ('off', 'approximate', 'precise')),
    location_sharing_expires_at TIMESTAMPTZ,
    consent JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_safe_trip_trip UNIQUE (trip_id)
);

CREATE TRIGGER set_safe_trips_updated_at
BEFORE UPDATE ON public.safe_trips
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 2. Create public.journey_checkins (Scheduled and completed check-ins)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.journey_checkins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    journey_id UUID NOT NULL REFERENCES public.safe_trips(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    checkin_number INTEGER NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'scheduled'
        CHECK (status IN ('scheduled', 'completed', 'missed', 'expired', 'cancelled')),
    scheduled_for TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    notes TEXT,
    idempotency_key TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_checkin_idempotency UNIQUE (journey_id, idempotency_key)
);

-- ------------------------------------------------------------------------------
-- 3. Create public.location_share_sessions (Temporary, revocable location sessions)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.location_share_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    journey_id UUID NOT NULL REFERENCES public.safe_trips(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    mode TEXT NOT NULL DEFAULT 'approximate'
        CHECK (mode IN ('off', 'approximate', 'precise')),
    approx_geohash TEXT,
    started_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TRIGGER set_location_share_sessions_updated_at
BEFORE UPDATE ON public.location_share_sessions
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 4. Create public.journey_events (Auditable journey event trail)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.journey_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    journey_id UUID NOT NULL REFERENCES public.safe_trips(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL
        CHECK (event_type IN (
            'journey_prepared', 'journey_activated', 'checkin_completed',
            'checkin_missed', 'help_requested', 'arrival_confirmed',
            'journey_completed', 'journey_cancelled', 'journey_expired',
            'location_sharing_started', 'location_sharing_stopped',
            'trusted_contact_notified'
        )),
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ------------------------------------------------------------------------------
-- 5. Indexes for fast query plans and anti-enumeration
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_safe_trips_owner ON public.safe_trips(owner_id);
CREATE INDEX IF NOT EXISTS idx_safe_trips_status ON public.safe_trips(status);
CREATE INDEX IF NOT EXISTS idx_safe_trips_companion ON public.safe_trips(companion_user_id);
CREATE INDEX IF NOT EXISTS idx_journey_checkins_journey ON public.journey_checkins(journey_id, scheduled_for DESC);
CREATE INDEX IF NOT EXISTS idx_location_share_sessions_active ON public.location_share_sessions(journey_id, expires_at)
    WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_journey_events_journey ON public.journey_events(journey_id, created_at DESC);

-- ------------------------------------------------------------------------------
-- 6. Row Level Security (RLS)
-- ------------------------------------------------------------------------------
ALTER TABLE public.safe_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.location_share_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_events ENABLE ROW LEVEL SECURITY;

-- Policy: safe_trips SELECT
CREATE POLICY "safe_trips_select_authorized"
ON public.safe_trips FOR SELECT
USING (
    auth.uid() = owner_id
    OR auth.uid() = companion_user_id
    OR public.is_admin_or_moderator(auth.uid())
);

-- Policy: safe_trips INSERT (Owner only)
CREATE POLICY "safe_trips_insert_owner"
ON public.safe_trips FOR INSERT
WITH CHECK (auth.uid() = owner_id);

-- Policy: safe_trips UPDATE (Owner only, or admin)
CREATE POLICY "safe_trips_update_owner"
ON public.safe_trips FOR UPDATE
USING (auth.uid() = owner_id OR public.is_admin_or_moderator(auth.uid()))
WITH CHECK (auth.uid() = owner_id OR public.is_admin_or_moderator(auth.uid()));

-- Policy: safe_trips DELETE (Owner only when preparing or cancelled)
CREATE POLICY "safe_trips_delete_owner"
ON public.safe_trips FOR DELETE
USING (auth.uid() = owner_id AND status IN ('preparing', 'cancelled'));

-- Policy: journey_checkins SELECT
CREATE POLICY "journey_checkins_select_authorized"
ON public.journey_checkins FOR SELECT
USING (
    auth.uid() = user_id
    OR EXISTS (
        SELECT 1 FROM public.safe_trips
        WHERE safe_trips.id = journey_checkins.journey_id
          AND (safe_trips.owner_id = auth.uid() OR safe_trips.companion_user_id = auth.uid())
    )
    OR public.is_admin_or_moderator(auth.uid())
);

-- Policy: journey_checkins INSERT & UPDATE (Owner only)
CREATE POLICY "journey_checkins_write_owner"
ON public.journey_checkins FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: location_share_sessions SELECT (Owner or authorized contact during active session)
CREATE POLICY "location_share_sessions_select"
ON public.location_share_sessions FOR SELECT
USING (
    auth.uid() = user_id
    OR (
        revoked_at IS NULL
        AND timezone('utc'::text, now()) < expires_at
        AND EXISTS (
            SELECT 1 FROM public.safe_trips st
            JOIN public.safety_contacts sc ON sc.id = st.trusted_contact_id
            WHERE st.id = location_share_sessions.journey_id
              AND (st.consent->>'share_approximate_location')::boolean = true
              AND sc.user_id = st.owner_id
        )
    )
    OR public.is_admin_or_moderator(auth.uid())
);

-- Policy: location_share_sessions WRITE (Owner only)
CREATE POLICY "location_share_sessions_write_owner"
ON public.location_share_sessions FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: journey_events SELECT (Owner, companion, admin)
CREATE POLICY "journey_events_select_authorized"
ON public.journey_events FOR SELECT
USING (
    auth.uid() = user_id
    OR EXISTS (
        SELECT 1 FROM public.safe_trips
        WHERE safe_trips.id = journey_events.journey_id
          AND (safe_trips.owner_id = auth.uid() OR safe_trips.companion_user_id = auth.uid())
    )
    OR public.is_admin_or_moderator(auth.uid())
);

-- Policy: journey_events INSERT (Owner only)
CREATE POLICY "journey_events_insert_owner"
ON public.journey_events FOR INSERT
WITH CHECK (auth.uid() = user_id);
