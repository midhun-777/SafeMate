-- ==============================================================================
-- SAFEMATE MIGRATION 006: TRUST VERIFICATION & SAFETY FOUNDATION (PHASE 9)
-- Universal Engineering Rule #6: Strict domain boundaries, privacy-safe identity
-- Universal Engineering Rule #7: Zero trust on client, strict server enforcement
-- Universal Engineering Rule #11: Deterministic state machines & safe transitions
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Extend public.verifications
-- ------------------------------------------------------------------------------
ALTER TABLE public.verifications
    ADD COLUMN IF NOT EXISTS verification_type TEXT NOT NULL DEFAULT 'government_id',
    ADD COLUMN IF NOT EXISTS provider TEXT NOT NULL DEFAULT 'mock_dev',
    ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

ALTER TABLE public.verifications DROP CONSTRAINT IF EXISTS verifications_status_check;
ALTER TABLE public.verifications
    ADD CONSTRAINT verifications_status_check
    CHECK (status IN ('not_started', 'unverified', 'pending', 'verified', 'rejected', 'expired', 'requires_review'));

ALTER TABLE public.verifications DROP CONSTRAINT IF EXISTS verifications_type_check;
ALTER TABLE public.verifications
    ADD CONSTRAINT verifications_type_check
    CHECK (verification_type IN ('phone', 'government_id', 'selfie_liveness', 'composite'));

-- ------------------------------------------------------------------------------
-- 2. Create public.verification_records (Audit history of verification attempts)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.verification_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    verification_type TEXT NOT NULL,
    provider TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'verified', 'rejected', 'expired', 'requires_review')),
    rejection_reason TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_verification_records_user ON public.verification_records(user_id, created_at DESC);

-- ------------------------------------------------------------------------------
-- 3. Extend public.reviews (Structured companion feedback)
-- ------------------------------------------------------------------------------
ALTER TABLE public.reviews
    ADD COLUMN IF NOT EXISTS communication_rating INTEGER CHECK (communication_rating >= 1 AND communication_rating <= 5),
    ADD COLUMN IF NOT EXISTS respect_rating INTEGER CHECK (respect_rating >= 1 AND respect_rating <= 5),
    ADD COLUMN IF NOT EXISTS planning_rating INTEGER CHECK (planning_rating >= 1 AND planning_rating <= 5);

-- ------------------------------------------------------------------------------
-- 4. Create public.privacy_settings
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.privacy_settings (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    profile_visibility TEXT NOT NULL DEFAULT 'public_to_matches' CHECK (profile_visibility IN ('public_to_matches', 'private', 'hidden')),
    trip_visibility TEXT NOT NULL DEFAULT 'public' CHECK (trip_visibility IN ('public', 'connections_only', 'hidden')),
    show_online_presence BOOLEAN NOT NULL DEFAULT TRUE,
    coarse_location_only BOOLEAN NOT NULL DEFAULT TRUE,
    allow_discovery BOOLEAN NOT NULL DEFAULT TRUE,
    show_verification_badge BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TRIGGER set_privacy_settings_updated_at
BEFORE UPDATE ON public.privacy_settings
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 5. Extend public.reports & Add Context
-- ------------------------------------------------------------------------------
ALTER TABLE public.reports
    ADD COLUMN IF NOT EXISTS context_type TEXT NOT NULL DEFAULT 'other',
    ADD COLUMN IF NOT EXISTS context_id TEXT;

ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_context_type_check;
ALTER TABLE public.reports
    ADD CONSTRAINT reports_context_type_check
    CHECK (context_type IN ('chat', 'trip', 'profile', 'connection', 'other'));

ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_category_check;
ALTER TABLE public.reports
    ADD CONSTRAINT reports_category_check
    CHECK (category IN (
        'harassment', 'spam', 'scam', 'inappropriate_behavior', 'impersonation',
        'no_show', 'safety_concern', 'unsafe_behavior', 'inappropriate_content',
        'privacy_violation', 'other'
    ));

-- ------------------------------------------------------------------------------
-- 6. Create public.moderation_actions
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.moderation_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID REFERENCES public.reports(id) ON DELETE SET NULL,
    target_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL CHECK (action_type IN ('no_action', 'warning', 'content_removed', 'user_restricted', 'user_suspended', 'user_banned')),
    reason TEXT NOT NULL,
    actioned_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_moderation_actions_target ON public.moderation_actions(target_user_id, created_at DESC);

-- ------------------------------------------------------------------------------
-- 7. RLS POLICIES FOR NEW & EXTENDED TABLES
-- ------------------------------------------------------------------------------

-- privacy_settings
ALTER TABLE public.privacy_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own privacy settings"
ON public.privacy_settings FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- verification_records
ALTER TABLE public.verification_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own verification records"
ON public.verification_records FOR SELECT
USING (auth.uid() = user_id OR public.is_admin_or_moderator(auth.uid()));

-- moderation_actions
ALTER TABLE public.moderation_actions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Only admins and moderators can access moderation actions"
ON public.moderation_actions FOR ALL
USING (public.is_admin_or_moderator(auth.uid()))
WITH CHECK (public.is_admin_or_moderator(auth.uid()));
