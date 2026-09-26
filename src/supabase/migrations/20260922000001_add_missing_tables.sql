-- ============================================================
-- VIDA LAB — Full Supabase Migration: Missing tables + helpers
-- ============================================================
-- This migration creates everything the previous scaffolding assumed
-- but never created:
--   1. security.is_admin() function
--   2. public.update_updated_at() trigger function
--   3. profiles table (with membership, role, onboarding fields)
--   4. Auto-create profile trigger on auth.users insert
--   5. daily_checkins table (user-owned)
--   6. experiments table (user-owned)
--   7. favorites table (user-owned)
--
-- Safe to re-run — all statements use IF NOT EXISTS.
-- ============================================================

-- ========== 1. SECURITY SCHEMA + IS_ADMIN FUNCTION ==========
CREATE SCHEMA IF NOT EXISTS security;

CREATE OR REPLACE FUNCTION security.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

-- ========== 2. UPDATED_AT TRIGGER FUNCTION ==========
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_date = now();
  RETURN NEW;
END;
$$;

-- ========== 3. PROFILES TABLE ==========
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text,
  full_name text,
  role text CHECK (role IN ('admin','user')) DEFAULT 'user',
  membership text DEFAULT null,
  gender text,
  health_concerns text[] DEFAULT '{}',
  last_rewind_date date,
  reminder_enabled boolean DEFAULT true,
  reminder_time text DEFAULT '20:00',
  content_updates boolean DEFAULT true,
  cycle_tracking_enabled boolean DEFAULT true,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Users can read their own profile; admins can read all
DROP POLICY IF EXISTS "profiles_read" ON public.profiles;
CREATE POLICY "profiles_read" ON public.profiles
  FOR SELECT TO authenticated
  USING (auth.uid() = id OR security.is_admin());

-- Users can update their own profile (but not role/membership — those are admin-only)
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Admins can update any profile
DROP POLICY IF EXISTS "profiles_admin_update" ON public.profiles;
CREATE POLICY "profiles_admin_update" ON public.profiles
  FOR UPDATE TO authenticated
  USING (security.is_admin()) WITH CHECK (security.is_admin());

-- ========== 3a. AUTO-CREATE PROFILE ON SIGNUP ==========
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'full_name', ''))
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ========== 4. DAILY CHECKINS (user-owned) ==========
CREATE TABLE IF NOT EXISTS public.daily_checkins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  checkin_date date NOT NULL,
  energy int CHECK (energy BETWEEN 1 AND 5) NOT NULL,
  sleep_hours numeric CHECK (sleep_hours BETWEEN 0 AND 14),
  sleep_quality int CHECK (sleep_quality BETWEEN 1 AND 5),
  mood text CHECK (mood IN ('calm','happy','neutral','anxious','sad','irritable','motivated')) NOT NULL,
  pain_level int CHECK (pain_level BETWEEN 0 AND 3) DEFAULT 0,
  cycle_phase text CHECK (cycle_phase IN ('menstrual','follicular','ovulation','luteal','not_tracking')) DEFAULT 'not_tracking',
  symptoms text[] DEFAULT '{}',
  practices text[] DEFAULT '{}',
  notes text,
  insight text,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE public.daily_checkins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "checkins_owner_all" ON public.daily_checkins;
CREATE POLICY "checkins_owner_all" ON public.daily_checkins
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_checkins_user_date ON public.daily_checkins(user_id, checkin_date DESC);

-- ========== 5. EXPERIMENTS (user-owned) ==========
CREATE TABLE IF NOT EXISTS public.experiments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  intervention text NOT NULL,
  hypothesis text NOT NULL,
  duration_days int CHECK (duration_days BETWEEN 7 AND 90) DEFAULT 21,
  start_date date NOT NULL,
  end_date date,
  status text CHECK (status IN ('active','completed','abandoned')) DEFAULT 'active',
  metrics_to_watch text[] DEFAULT '{}',
  results_summary text,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE public.experiments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "experiments_owner_all" ON public.experiments;
CREATE POLICY "experiments_owner_all" ON public.experiments
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_experiments_user ON public.experiments(user_id, created_date DESC);

-- ========== 6. FAVORITES (user-owned) ==========
CREATE TABLE IF NOT EXISTS public.favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  resource_id text NOT NULL,
  resource_title text NOT NULL,
  resource_category text,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "favorites_owner_all" ON public.favorites;
CREATE POLICY "favorites_owner_all" ON public.favorites
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_favorites_user ON public.favorites(user_id, created_date DESC);
CREATE INDEX IF NOT EXISTS idx_favorites_resource ON public.favorites(resource_id);

-- ========== 7. UPDATED_AT TRIGGERS FOR ALL TABLES ==========
DO $$
DECLARE
  tbl text;
  tables text[] := array[
    'profiles','daily_checkins','experiments','favorites'
  ];
BEGIN
  FOREACH tbl IN ARRAY tables LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_updated_date ON public.%I', tbl);
    EXECUTE format('CREATE TRIGGER set_updated_date BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.update_updated_at()', tbl);
  END LOOP;
END $$;