-- ============================================================
-- VIDA LAB — Phase 1: Additive web-only tables
-- ============================================================
-- Safe to run against the live production database.
-- Assumes security.is_admin() and public.update_updated_at()
-- already exist (iOS schema).
-- ============================================================

-- ========== TREATMENTS (user-owned) ==========
CREATE TABLE IF NOT EXISTS public.treatments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  type text CHECK (type IN ('medication','supplement','therapy','lifestyle','procedure','other')) DEFAULT 'medication',
  start_date date,
  end_date date,
  dosage text,
  effectiveness int CHECK (effectiveness BETWEEN 1 AND 5) DEFAULT 3,
  side_effects text,
  notes text,
  status text CHECK (status IN ('current','past','discontinued')) DEFAULT 'past',
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE public.treatments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "treatments_owner_all" ON public.treatments;
CREATE POLICY "treatments_owner_all" ON public.treatments
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_treatments_user ON public.treatments(user_id);

-- ========== DOCTORS (public read, admin write) ==========
CREATE TABLE IF NOT EXISTS public.doctors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  practice_name text NOT NULL,
  specialty text NOT NULL,
  category text CHECK (category IN ('autoimmune','neurological','cardiovascular','endocrine','musculoskeletal','gastrointestinal','respiratory','mental_health','chronic_pain','dysautonomia','gynecological','other')),
  phone text,
  email text,
  address text,
  city text,
  state text,
  zip_code text,
  website text,
  accepting_new_patients boolean DEFAULT true,
  notes text,
  sort_order numeric DEFAULT 0,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE public.doctors ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "doctors_public_read" ON public.doctors;
CREATE POLICY "doctors_public_read" ON public.doctors
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "doctors_admin_write" ON public.doctors;
CREATE POLICY "doctors_admin_write" ON public.doctors
  FOR ALL TO authenticated
  USING (security.is_admin()) WITH CHECK (security.is_admin());

-- ========== APPOINTMENTS (user-owned) ==========
CREATE TABLE IF NOT EXISTS public.appointments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  doctor_id uuid REFERENCES public.doctors(id) ON DELETE SET NULL,
  doctor_name text NOT NULL,
  practice_name text,
  specialty text,
  appointment_date date NOT NULL,
  appointment_time text NOT NULL,
  reason text,
  status text CHECK (status IN ('requested','confirmed','cancelled','completed')) DEFAULT 'requested',
  notes text,
  snapshot_sent boolean DEFAULT false,
  reminder_sent boolean DEFAULT false,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "appointments_owner_all" ON public.appointments;
CREATE POLICY "appointments_owner_all" ON public.appointments
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_appts_user_date ON public.appointments(user_id, appointment_date);

-- ========== HEALTH RESOURCES (public read, admin write) ==========
CREATE TABLE IF NOT EXISTS public.health_resources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  category text CHECK (category IN ('recipe','exercise','meditation','supplement','habit')),
  subcategory text,
  description text NOT NULL,
  content text NOT NULL,
  duration_minutes numeric,
  difficulty text CHECK (difficulty IN ('gentle','easy','moderate','advanced')) DEFAULT 'easy',
  tags text[] DEFAULT '{}',
  citations text,
  is_public boolean DEFAULT true,
  sort_order numeric DEFAULT 0,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE public.health_resources ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "resources_public_read" ON public.health_resources;
CREATE POLICY "resources_public_read" ON public.health_resources
  FOR SELECT TO anon, authenticated
  USING (is_public = true OR security.is_admin());
DROP POLICY IF EXISTS "resources_admin_write" ON public.health_resources;
CREATE POLICY "resources_admin_write" ON public.health_resources
  FOR ALL TO authenticated
  USING (security.is_admin()) WITH CHECK (security.is_admin());

-- ========== DISEASE REPORTS (public read, admin write) ==========
CREATE TABLE IF NOT EXISTS public.disease_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  category text CHECK (category IN ('autoimmune','neurological','cardiovascular','endocrine','musculoskeletal','gastrointestinal','respiratory','mental_health','chronic_pain','dysautonomia','gynecological','other')),
  summary text NOT NULL,
  overview text NOT NULL,
  symptoms text,
  diagnosis text,
  treatments text,
  resources text,
  doctors_guide text,
  advocacy_guide text,
  conquer_plan text,
  is_public boolean DEFAULT true,
  sort_order numeric DEFAULT 0,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE public.disease_reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "reports_public_read" ON public.disease_reports;
CREATE POLICY "reports_public_read" ON public.disease_reports
  FOR SELECT TO anon, authenticated
  USING (is_public = true OR security.is_admin());
DROP POLICY IF EXISTS "reports_admin_write" ON public.disease_reports;
CREATE POLICY "reports_admin_write" ON public.disease_reports
  FOR ALL TO authenticated
  USING (security.is_admin()) WITH CHECK (security.is_admin());

CREATE INDEX IF NOT EXISTS idx_reports_slug ON public.disease_reports(slug);

-- ========== EXPLAINERS (public read, admin write) ==========
CREATE TABLE IF NOT EXISTS public.explainers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  subtitle text,
  category text CHECK (category IN ('cycle','sleep','mood','nutrition','movement','stress','hormones')),
  content text NOT NULL,
  read_time_minutes int CHECK (read_time_minutes BETWEEN 1 AND 30),
  image_url text,
  is_public boolean DEFAULT true,
  is_vida_plus boolean DEFAULT false,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE public.explainers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "explainers_public_read" ON public.explainers;
CREATE POLICY "explainers_public_read" ON public.explainers
  FOR SELECT TO anon, authenticated
  USING (is_public = true OR security.is_admin());
DROP POLICY IF EXISTS "explainers_admin_write" ON public.explainers;
CREATE POLICY "explainers_admin_write" ON public.explainers
  FOR ALL TO authenticated
  USING (security.is_admin()) WITH CHECK (security.is_admin());

-- ========== SUBSTACK ARTICLES (public read, admin write) ==========
CREATE TABLE IF NOT EXISTS public.substack_articles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  link text NOT NULL,
  description text,
  pub_date text,
  sort_order numeric DEFAULT 0,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE public.substack_articles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "substack_public_read" ON public.substack_articles;
CREATE POLICY "substack_public_read" ON public.substack_articles
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "substack_admin_write" ON public.substack_articles;
CREATE POLICY "substack_admin_write" ON public.substack_articles
  FOR ALL TO authenticated
  USING (security.is_admin()) WITH CHECK (security.is_admin());

-- ========== RESEARCH PAPERS (public read, admin write) ==========
CREATE TABLE IF NOT EXISTS public.research_papers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  program text CHECK (program IN ('AP Research','AP Seminar')),
  year text,
  abstract text NOT NULL,
  file_url text,
  sort_order numeric DEFAULT 0,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE public.research_papers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "papers_public_read" ON public.research_papers;
CREATE POLICY "papers_public_read" ON public.research_papers
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "papers_admin_write" ON public.research_papers;
CREATE POLICY "papers_admin_write" ON public.research_papers
  FOR ALL TO authenticated
  USING (security.is_admin()) WITH CHECK (security.is_admin());

-- ========== NEWSLETTER SIGNUPS (public insert, admin read/update/delete) ==========
CREATE TABLE IF NOT EXISTS public.newsletter_signups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  source text DEFAULT 'site',
  status text CHECK (status IN ('subscribed','unsubscribed')) DEFAULT 'subscribed',
  unsubscribe_reason text,
  unsubscribe_token text,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE public.newsletter_signups ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "newsletter_public_insert" ON public.newsletter_signups;
CREATE POLICY "newsletter_public_insert" ON public.newsletter_signups
  FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "newsletter_admin_read" ON public.newsletter_signups;
CREATE POLICY "newsletter_admin_read" ON public.newsletter_signups
  FOR SELECT TO authenticated USING (security.is_admin());
DROP POLICY IF EXISTS "newsletter_admin_update" ON public.newsletter_signups;
CREATE POLICY "newsletter_admin_update" ON public.newsletter_signups
  FOR UPDATE TO authenticated USING (security.is_admin());
DROP POLICY IF EXISTS "newsletter_admin_delete" ON public.newsletter_signups;
CREATE POLICY "newsletter_admin_delete" ON public.newsletter_signups
  FOR DELETE TO authenticated USING (security.is_admin());

-- ========== PURCHASES (payment records — separate from entitlements) ==========
CREATE TABLE IF NOT EXISTS public.purchases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  checkout_session_id text NOT NULL,
  status text CHECK (status IN ('pending','paid','canceled')) DEFAULT 'pending',
  order_id text,
  buyer_email text,
  product_id text,
  product_name text,
  quantity numeric DEFAULT 1,
  amount text,
  currency text,
  subscription_id text,
  paid_at timestamptz,
  canceled_at timestamptz,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "purchases_owner_read" ON public.purchases;
CREATE POLICY "purchases_owner_read" ON public.purchases
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR security.is_admin());
DROP POLICY IF EXISTS "purchases_admin_write" ON public.purchases;
CREATE POLICY "purchases_admin_write" ON public.purchases
  FOR ALL TO authenticated
  USING (security.is_admin()) WITH CHECK (security.is_admin());

CREATE INDEX IF NOT EXISTS idx_purchases_session ON public.purchases(checkout_session_id);

-- ========== EXPERIMENT LOGS (user-owned) ==========
CREATE TABLE IF NOT EXISTS public.experiment_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  experiment_id text NOT NULL,
  log_date date NOT NULL,
  adhered boolean DEFAULT true,
  notes text,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE public.experiment_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "explogs_owner_all" ON public.experiment_logs;
CREATE POLICY "explogs_owner_all" ON public.experiment_logs
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_explogs_exp ON public.experiment_logs(experiment_id, log_date DESC);

-- ========== UPDATED_AT TRIGGERS (new tables only) ==========
DO $$
DECLARE
  tbl text;
  tables text[] := array[
    'treatments','doctors','appointments','health_resources','disease_reports',
    'explainers','substack_articles','research_papers','newsletter_signups',
    'purchases','experiment_logs'
  ];
BEGIN
  FOREACH tbl IN ARRAY tables LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_updated_date ON public.%I', tbl);
    EXECUTE format('CREATE TRIGGER set_updated_date BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.update_updated_at()', tbl);
  END LOOP;
END $$;