-- ==============================================================================
-- SafeMate Schema Migration 003: Trips & Journey Management Extensions
-- SafeMate Universal Engineering Rules Compliant (Rules #7, #11, #20)
-- ==============================================================================

-- 1. Extend trips table with visibility, budget tier, styles, and granular location
ALTER TABLE public.trips
    ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'visible_for_matching'
        CHECK (visibility IN ('visible_for_matching', 'private', 'paused')),
    ADD COLUMN IF NOT EXISTS budget_tier TEXT NOT NULL DEFAULT 'flexible'
        CHECK (budget_tier IN ('budget', 'moderate', 'comfortable', 'flexible')),
    ADD COLUMN IF NOT EXISTS trip_styles TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS origin_city TEXT,
    ADD COLUMN IF NOT EXISTS origin_country TEXT,
    ADD COLUMN IF NOT EXISTS destination_city TEXT,
    ADD COLUMN IF NOT EXISTS destination_country TEXT;

-- Drop and recreate status check constraint to include all deterministic lifecycle states
ALTER TABLE public.trips DROP CONSTRAINT IF EXISTS trips_status_check;
ALTER TABLE public.trips ADD CONSTRAINT trips_status_check
    CHECK (status IN ('draft', 'published', 'paused', 'cancelled', 'completed', 'planned', 'active'));

-- Drop and recreate transport_mode check constraint to support modern modes
ALTER TABLE public.trips DROP CONSTRAINT IF EXISTS trips_transport_mode_check;
ALTER TABLE public.trips ADD CONSTRAINT trips_transport_mode_check
    CHECK (transport_mode IN ('bus', 'train', 'flight', 'car', 'bike', 'other', 'flexible', 'road_trip', 'backpacking', 'cruise'));

-- Drop and recreate trip_purpose check constraint
ALTER TABLE public.trips DROP CONSTRAINT IF EXISTS trips_trip_purpose_check;
ALTER TABLE public.trips ADD CONSTRAINT trips_trip_purpose_check
    CHECK (trip_purpose IN ('vacation', 'weekend_trip', 'work', 'study', 'family_visit', 'event', 'adventure', 'pilgrimage', 'exploration', 'other', 'leisure', 'workation', 'cultural', 'spiritual'));

-- GIN index for trip_styles search
CREATE INDEX IF NOT EXISTS idx_trips_styles ON public.trips USING GIN (trip_styles);
CREATE INDEX IF NOT EXISTS idx_trips_visibility ON public.trips(visibility);
CREATE INDEX IF NOT EXISTS idx_trips_user_status ON public.trips(user_id, status);

-- 2. Extend trip_preferences table with trip-specific companion criteria
ALTER TABLE public.trip_preferences
    ADD COLUMN IF NOT EXISTS travel_pace TEXT NOT NULL DEFAULT 'flexible'
        CHECK (travel_pace IN ('slow', 'balanced', 'fast', 'flexible', 'not_specified')),
    ADD COLUMN IF NOT EXISTS budget_tier TEXT NOT NULL DEFAULT 'flexible'
        CHECK (budget_tier IN ('budget', 'moderate', 'comfortable', 'flexible', 'not_specified')),
    ADD COLUMN IF NOT EXISTS accommodation_preference TEXT NOT NULL DEFAULT 'flexible'
        CHECK (accommodation_preference IN ('hostel', 'hotel', 'homestay', 'flexible', 'not_specified')),
    ADD COLUMN IF NOT EXISTS social_energy TEXT NOT NULL DEFAULT 'flexible'
        CHECK (social_energy IN ('mostly_solo', 'small_group', 'social', 'flexible', 'not_specified')),
    ADD COLUMN IF NOT EXISTS preferred_transport TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS activity_interests TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS dietary_preferences TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS schedule_preference TEXT NOT NULL DEFAULT 'flexible'
        CHECK (schedule_preference IN ('early_riser', 'night_owl', 'flexible', 'not_specified'));

-- GIN indexes for companion preferences
CREATE INDEX IF NOT EXISTS idx_trip_pref_activities ON public.trip_preferences USING GIN (activity_interests);
CREATE INDEX IF NOT EXISTS idx_trip_pref_transport ON public.trip_preferences USING GIN (preferred_transport);

-- 3. Update Row Level Security (RLS) on trips
-- Private trips, drafts, and cancelled trips are visible ONLY to the trip owner
-- Only published trips with visibility = 'visible_for_matching' are visible to other users
DROP POLICY IF EXISTS "Active planned trips viewable by non-blocked authenticated users" ON public.trips;
DROP POLICY IF EXISTS "Users can manage their own trips" ON public.trips;

-- Selective read policy
CREATE POLICY "Trips viewable based on status and privacy"
ON public.trips FOR SELECT
USING (
    auth.role() = 'authenticated'
    AND (
        -- Owner can always view all their own trips regardless of status/visibility
        auth.uid() = user_id
        OR (
            -- Other users can ONLY see published trips marked as visible_for_matching
            status = 'published'
            AND visibility = 'visible_for_matching'
            AND NOT public.is_blocked(auth.uid(), user_id)
        )
    )
);

-- Owner insert policy
CREATE POLICY "Users can create their own trips"
ON public.trips FOR INSERT
WITH CHECK (
    auth.uid() = user_id
);

-- Owner update policy
CREATE POLICY "Users can update their own trips"
ON public.trips FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Owner delete policy: STRICTLY restricted to drafts only (Rule #11, Rule #20)
-- Published, cancelled, or completed journeys must never be physically deleted by client
CREATE POLICY "Users can only delete unpublished draft trips"
ON public.trips FOR DELETE
USING (
    auth.uid() = user_id
    AND status = 'draft'
);
