-- Add email column to profiles so backend functions can query user emails
-- without relying on the Supabase Auth Admin API (which has connectivity issues).
-- The email is synced from auth.users on each login via getUserFromToken().
--
-- Run this in your Supabase Dashboard → SQL Editor.

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS email text;

CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);

-- Backfill emails from auth.users for existing profiles.
-- profiles.id is text, auth.users.id is uuid — cast explicitly.
UPDATE profiles p
  SET email = u.email
  FROM auth.users u
  WHERE p.id = u.id::text AND (p.email IS NULL OR p.email = '');