-- ==============================================================================
-- SafeMate Schema Migration 002: Profile & Travel Identity Extensions
-- SafeMate Universal Engineering Rules Compliant
-- ==============================================================================

-- 1. Extend profiles with home city, visibility privacy setting, and completion percentage
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS home_city TEXT,
    ADD COLUMN IF NOT EXISTS profile_visibility TEXT NOT NULL DEFAULT 'public_to_matches'
        CHECK (profile_visibility IN ('public_to_matches', 'private', 'hidden')),
    ADD COLUMN IF NOT EXISTS profile_completion_percentage INTEGER NOT NULL DEFAULT 0
        CHECK (profile_completion_percentage >= 0 AND profile_completion_percentage <= 100);

-- Index for searching matches by visibility
CREATE INDEX IF NOT EXISTS idx_profiles_visibility ON public.profiles(profile_visibility);

-- 2. Extend travel_preferences with accommodation, activity interests, planning & schedule style
ALTER TABLE public.travel_preferences
    ADD COLUMN IF NOT EXISTS accommodation_preference TEXT NOT NULL DEFAULT 'flexible'
        CHECK (accommodation_preference IN ('hostel', 'hotel', 'homestay', 'flexible', 'not_specified')),
    ADD COLUMN IF NOT EXISTS activity_interests TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS planning_style TEXT NOT NULL DEFAULT 'flexible'
        CHECK (planning_style IN ('structured', 'spontaneous', 'flexible', 'not_specified')),
    ADD COLUMN IF NOT EXISTS schedule_preference TEXT NOT NULL DEFAULT 'flexible'
        CHECK (schedule_preference IN ('early_bird', 'night_owl', 'flexible', 'not_specified'));

-- GIN index for high-performance array containment search on activity interests
CREATE INDEX IF NOT EXISTS idx_travel_preferences_activities ON public.travel_preferences USING GIN (activity_interests);

-- 3. Storage Bucket Configuration for Avatars
-- Creates 'avatars' storage bucket with size and MIME restrictions
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    true,
    2097152, -- 2MB file size limit
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    file_size_limit = 2097152,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

-- Storage RLS: Users can only upload, update, and delete their own avatars
CREATE POLICY "Users can upload their own profile photos"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can update their own profile photos"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can delete their own profile photos"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Profile photos are publicly viewable by authenticated users"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
);
