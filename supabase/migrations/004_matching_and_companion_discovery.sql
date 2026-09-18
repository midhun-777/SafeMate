-- ==============================================================================
-- SAFEMATE MIGRATION 004: MATCHING ENGINE & COMPANION DISCOVERY
-- Universal Engineering Rule #6: 3-State Preference Semantics & Deterministic Scoring
-- Universal Engineering Rule #11: Deterministic state machines & safe transitions
-- ==============================================================================

-- 1. Extend public.matches with score versioning and explainability structures
ALTER TABLE public.matches
    ADD COLUMN IF NOT EXISTS score_version TEXT NOT NULL DEFAULT 'v1',
    ADD COLUMN IF NOT EXISTS match_reasons JSONB NOT NULL DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS mismatch_notes JSONB NOT NULL DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS evaluated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now());

-- 2. Ensure status constraints accommodate discovery statuses ('suggested', 'recommended', 'viewed', 'dismissed', 'connected')
ALTER TABLE public.matches DROP CONSTRAINT IF EXISTS matches_status_check;
ALTER TABLE public.matches
    ADD CONSTRAINT matches_status_check 
    CHECK (status IN ('suggested', 'recommended', 'viewed', 'dismissed', 'liked', 'passed', 'connected', 'expired'));

-- 3. Optimized Indices for Companion Discovery
CREATE INDEX IF NOT EXISTS idx_matches_user_trip_score 
    ON public.matches (user_id, trip_id, compatibility_score DESC);

CREATE INDEX IF NOT EXISTS idx_matches_candidate_trip 
    ON public.matches (candidate_trip_id);

CREATE INDEX IF NOT EXISTS idx_matches_status 
    ON public.matches (user_id, status);

-- 4. Secure RLS Policies for Matches
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

-- Allow users to insert/upsert their evaluated matches
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'matches' AND policyname = 'Users can insert their own match evaluations'
    ) THEN
        CREATE POLICY "Users can insert their own match evaluations"
        ON public.matches FOR INSERT
        WITH CHECK (
            auth.uid() = user_id 
            AND NOT public.is_blocked(auth.uid(), candidate_id)
        );
    END IF;
END $$;

-- Allow users to update their own match records (e.g. dismissed, viewed)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'matches' AND policyname = 'Users can update their own matches'
    ) THEN
        CREATE POLICY "Users can update their own matches"
        ON public.matches FOR UPDATE
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id);
    END IF;
END $$;
