-- ============================================================
-- VIDA LAB — Phase 1: Profile fields for web onboarding
-- ============================================================
-- Adds columns to the existing profiles table for web-only
-- onboarding data (gender, health concerns, reminder settings).
-- Uses ADD COLUMN IF NOT EXISTS — safe to re-run.
-- ============================================================

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS gender text,
  ADD COLUMN IF NOT EXISTS health_concerns text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS last_rewind_date date,
  ADD COLUMN IF NOT EXISTS reminder_enabled boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS reminder_time text DEFAULT '20:00',
  ADD COLUMN IF NOT EXISTS content_updates boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS cycle_tracking_enabled boolean DEFAULT true;