-- Add missing profile fields needed by the Supabase-migrated backend functions.
-- The reminder system (send-reminders workflow) needs these columns to track
-- when each user was last reminded and what timezone they're in.
--
-- Run this in your Supabase Dashboard → SQL Editor.

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS last_reminder_date text,
  ADD COLUMN IF NOT EXISTS reminder_timezone text DEFAULT 'UTC';

-- Ensure content_updates exists (alias content_updates_enabled is handled in code)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS content_updates boolean DEFAULT true;