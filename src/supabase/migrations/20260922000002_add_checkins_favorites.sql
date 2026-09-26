-- ============================================================
-- VIDA LAB — Fix: create the two missing tables
-- ============================================================
-- daily_checkins and favorites were never created in Supabase.
-- Run this in the Supabase Dashboard → SQL Editor → New query.
-- Safe to re-run (IF NOT EXISTS / OR REPLACE).
-- Assumes security.is_admin() and public.update_updated_at()
-- already exist (they do — used by the content tables).
-- ============================================================

-- ========== DAILY CHECKINS (user-owned) ==========
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

-- ========== FAVORITES (user-owned) ==========
CREATE TABLE IF NOT EXISTS public.favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  resource_id text NOT NULL,
  resource_title text NOT NULL,
  resource_category text,
  resource_type text,
  resource_url text,
  resource_subtitle text,
  resource_image text,
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

-- ========== UPDATED_AT TRIGGERS ==========
DO $$
DECLARE tbl text;
BEGIN
  FOREACH tbl IN ARRAY array['daily_checkins','favorites'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_updated_date ON public.%I', tbl);
    EXECUTE format('CREATE TRIGGER set_updated_date BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.update_updated_at()', tbl);
  END LOOP;
END $$;