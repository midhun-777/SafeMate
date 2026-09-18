-- ==============================================================================
-- SAFEMATE MIGRATION 008: OPTIMISTIC CONCURRENCY CONTROL & SERVER RECONCILIATION
-- Universal Engineering Rule #6: Strict domain boundaries, privacy-safe identity
-- Universal Engineering Rule #7: Zero trust on client, strict server enforcement
-- Universal Engineering Rule #11: Deterministic state machines & safe transitions
-- Universal Engineering Rule #18: Server is authoritative on conflict; no wall-clock LWW
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. ITINERARIES TABLE (Correction #1: Add itineraries to versioning architecture)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.itineraries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE UNIQUE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    days_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_itineraries_trip ON public.itineraries(trip_id);
CREATE INDEX IF NOT EXISTS idx_itineraries_user ON public.itineraries(user_id);

ALTER TABLE public.itineraries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view itineraries for accessible trips"
ON public.itineraries FOR SELECT
USING (
    auth.uid() = user_id
    OR EXISTS (
        SELECT 1 FROM public.trips t
        WHERE t.id = trip_id
        AND (t.status = 'published' AND t.visibility = 'visible_for_matching')
    )
);

CREATE POLICY "Users can manage their own itineraries"
ON public.itineraries FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- ------------------------------------------------------------------------------
-- 2. ADD VERSION COLUMNS (Trips, Profiles, Trip Preferences)
-- ------------------------------------------------------------------------------
ALTER TABLE public.trips
    ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1;

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1;

ALTER TABLE public.trip_preferences
    ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1;

-- ------------------------------------------------------------------------------
-- 3. VERSION AUTO-INCREMENT TRIGGER FUNCTION
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.increment_entity_version()
RETURNS TRIGGER AS $$
BEGIN
    NEW.version = OLD.version + 1;
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach version increment triggers
DROP TRIGGER IF EXISTS trg_trips_increment_version ON public.trips;
CREATE TRIGGER trg_trips_increment_version
    BEFORE UPDATE ON public.trips
    FOR EACH ROW
    EXECUTE FUNCTION public.increment_entity_version();

DROP TRIGGER IF EXISTS trg_profiles_increment_version ON public.profiles;
CREATE TRIGGER trg_profiles_increment_version
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.increment_entity_version();

DROP TRIGGER IF EXISTS trg_trip_preferences_increment_version ON public.trip_preferences;
CREATE TRIGGER trg_trip_preferences_increment_version
    BEFORE UPDATE ON public.trip_preferences
    FOR EACH ROW
    EXECUTE FUNCTION public.increment_entity_version();

DROP TRIGGER IF EXISTS trg_itineraries_increment_version ON public.itineraries;
CREATE TRIGGER trg_itineraries_increment_version
    BEFORE UPDATE ON public.itineraries
    FOR EACH ROW
    EXECUTE FUNCTION public.increment_entity_version();

-- ------------------------------------------------------------------------------
-- 4. SERVER AUTHORITY PROFILE SECURITY TRIGGER (Correction #3)
-- Strictly prevents client from mutating trust_score, trips_completed, or reliability_rating
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_server_authoritative_profile_fields()
RETURNS TRIGGER AS $$
DECLARE
    v_auth_uid UUID := auth.uid();
BEGIN
    -- If a non-admin/non-moderator user is updating, freeze server-authoritative scoring fields
    IF v_auth_uid IS NOT NULL AND NOT public.is_admin_or_moderator(v_auth_uid) THEN
        NEW.trust_score = OLD.trust_score;
        NEW.trips_completed = OLD.trips_completed;
        NEW.reliability_rating = OLD.reliability_rating;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_protect_profile_fields ON public.profiles;
CREATE TRIGGER trg_protect_profile_fields
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.protect_server_authoritative_profile_fields();

-- ------------------------------------------------------------------------------
-- 5. ATOMIC OCC UPDATE RPC FOR TRIPS
-- Evaluates base_version before applying mutations. Returns 409 error if diverged.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_trip_occ(
    p_trip_id UUID,
    p_base_version INTEGER,
    p_patch JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_auth_uid UUID := auth.uid();
    v_current_trip RECORD;
    v_updated_trip RECORD;
BEGIN
    IF v_auth_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    -- Lock trip row for atomic update
    SELECT * INTO v_current_trip
    FROM public.trips
    WHERE id = p_trip_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Trip not found: %', p_trip_id USING ERRCODE = 'P0002';
    END IF;

    IF v_current_trip.user_id != v_auth_uid THEN
        RAISE EXCEPTION 'Unauthorized: only owner can update trip' USING ERRCODE = '42501';
    END IF;

    -- Concurrency check: does current server version match the client base version?
    IF v_current_trip.version != p_base_version THEN
        RAISE EXCEPTION '409 Conflict: Trip version % on server differs from client base version %',
            v_current_trip.version, p_base_version USING ERRCODE = 'P0001';
    END IF;

    -- Apply safe scalar field updates
    UPDATE public.trips
    SET
        title = COALESCE(p_patch->>'title', title),
        origin = COALESCE(p_patch->>'origin', origin),
        destination = COALESCE(p_patch->>'destination', destination),
        start_date = COALESCE((p_patch->>'start_date')::date, start_date),
        end_date = COALESCE((p_patch->>'end_date')::date, end_date),
        estimated_budget = COALESCE((p_patch->>'estimated_budget')::numeric, estimated_budget),
        currency = COALESCE(p_patch->>'currency', currency),
        transport_mode = COALESCE(p_patch->>'transport_mode', transport_mode),
        trip_purpose = COALESCE(p_patch->>'trip_purpose', trip_purpose),
        visibility = COALESCE(p_patch->>'visibility', visibility),
        budget_tier = COALESCE(p_patch->>'budget_tier', budget_tier),
        max_companions = COALESCE((p_patch->>'max_companions')::integer, max_companions)
    WHERE id = p_trip_id
    RETURNING * INTO v_updated_trip;

    RETURN to_jsonb(v_updated_trip);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
