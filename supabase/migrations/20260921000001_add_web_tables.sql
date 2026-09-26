-- ============================================================
-- VIDA LAB — Phase 1: Additive web-only tables
-- ============================================================
-- Safe to run against the live production database.
-- Uses IF NOT EXISTS — no-op if tables already exist.
-- Does NOT touch existing iOS tables (profiles, check_ins, experiments,
-- doctor_preps, saved_articles, entitlements, entitlement_log).
-- ============================================================

-- ========== TREATMENTS (user-owned) ==========
CREATE TABLE IF NOT EXISTS treatments (
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

ALTER TABLE treatments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "treatments_owner_all" ON treatments;
CREATE POLICY "treatments_owner_all" ON treatments FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_treatments_user ON treatments(user_id);

-- ========== DOCTORS (public read, admin write) ==========
CREATE TABLE IF NOT EXISTS doctors (
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

ALTER TABLE doctors ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "doctors_public_read" ON doctors;
CREATE POLICY "doctors_public_read" ON doctors FOR SELECT USING (true);
DROP POLICY IF EXISTS "doctors_admin_write" ON doctors;
CREATE POLICY "doctors_admin_write" ON doctors FOR ALL
  USING (security.is_admin()) WITH CHECK (security.is_admin());

-- ========== APPOINTMENTS (user-owned) ==========
CREATE TABLE IF NOT EXISTS appointments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  doctor_id text NOT NULL,
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

ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "appointments_owner_all" ON appointments;
CREATE POLICY "appointments_owner_all" ON appointments FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_appts_user_date ON appointments(user_id, appointment_date);

-- ========== HEALTH RESOURCES (public read, admin write) ==========
CREATE TABLE IF NOT EXISTS health_resources (
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

ALTER TABLE health_resources ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "resources_public_read" ON health_resources;
CREATE POLICY "resources_public_read" ON health_resources FOR SELECT
  USING (is_public = true OR security.is_admin());
DROP POLICY IF EXISTS "resources_admin_write" ON health_resources;
CREATE POLICY "resources_admin_write" ON health_resources FOR ALL
  USING (security.is_admin()) WITH CHECK (security.is_admin());

-- ========== DISEASE REPORTS (public read, admin write) ==========
CREATE TABLE IF NOT EXISTS disease_reports (
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

ALTER TABLE disease_reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "reports_public_read" ON disease_reports;
CREATE POLICY "reports_public_read" ON disease_reports FOR SELECT
  USING (is_public = true OR security.is_admin());
DROP POLICY IF EXISTS "reports_admin_write" ON disease_reports;
CREATE POLICY "reports_admin_write" ON disease_reports FOR ALL
  USING (security.is_admin()) WITH CHECK (security.is_admin());

CREATE INDEX IF NOT EXISTS idx_reports_slug ON disease_reports(slug);

-- ========== EXPLAINERS (public read, admin write) ==========
CREATE TABLE IF NOT EXISTS explainers (
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

ALTER TABLE explainers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "explainers_public_read" ON explainers;
CREATE POLICY "explainers_public_read" ON explainers FOR SELECT
  USING (is_public = true OR security.is_admin());
DROP POLICY IF EXISTS "explainers_admin_write" ON explainers;
CREATE POLICY "explainers_admin_write" ON explainers FOR ALL
  USING (security.is_admin()) WITH CHECK (security.is_admin());

-- ========== SUBSTACK ARTICLES (public read, admin write) ==========
CREATE TABLE IF NOT EXISTS substack_articles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  link text NOT NULL,
  description text,
  pub_date text,
  sort_order numeric DEFAULT 0,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE substack_articles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "substack_public_read" ON substack_articles;
CREATE POLICY "substack_public_read" ON substack_articles FOR SELECT USING (true);
DROP POLICY IF EXISTS "substack_admin_write" ON substack_articles;
CREATE POLICY "substack_admin_write" ON substack_articles FOR ALL
  USING (security.is_admin()) WITH CHECK (security.is_admin());

-- ========== RESEARCH PAPERS (public read, admin write) ==========
CREATE TABLE IF NOT EXISTS research_papers (
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

ALTER TABLE research_papers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "papers_public_read" ON research_papers;
CREATE POLICY "papers_public_read" ON research_papers FOR SELECT USING (true);
DROP POLICY IF EXISTS "papers_admin_write" ON research_papers;
CREATE POLICY "papers_admin_write" ON research_papers FOR ALL
  USING (security.is_admin()) WITH CHECK (security.is_admin());

-- ========== NEWSLETTER SIGNUPS (public insert, admin read/update/delete) ==========
CREATE TABLE IF NOT EXISTS newsletter_signups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  source text DEFAULT 'site',
  status text CHECK (status IN ('subscribed','unsubscribed')) DEFAULT 'subscribed',
  unsubscribe_reason text,
  unsubscribe_token text,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE newsletter_signups ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "newsletter_public_insert" ON newsletter_signups;
CREATE POLICY "newsletter_public_insert" ON newsletter_signups FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "newsletter_admin_read" ON newsletter_signups;
CREATE POLICY "newsletter_admin_read" ON newsletter_signups FOR SELECT USING (security.is_admin());
DROP POLICY IF EXISTS "newsletter_admin_update" ON newsletter_signups;
CREATE POLICY "newsletter_admin_update" ON newsletter_signups FOR UPDATE USING (security.is_admin());
DROP POLICY IF EXISTS "newsletter_admin_delete" ON newsletter_signups;
CREATE POLICY "newsletter_admin_delete" ON newsletter_signups FOR DELETE USING (security.is_admin());

-- ========== PURCHASES (payment records — separate from entitlements) ==========
CREATE TABLE IF NOT EXISTS purchases (
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

ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "purchases_owner_read" ON purchases;
CREATE POLICY "purchases_owner_read" ON purchases FOR SELECT
  USING (auth.uid() = user_id OR security.is_admin());
DROP POLICY IF EXISTS "purchases_admin_write" ON purchases;
CREATE POLICY "purchases_admin_write" ON purchases FOR ALL
  USING (security.is_admin()) WITH CHECK (security.is_admin());

CREATE INDEX IF NOT EXISTS idx_purchases_session ON purchases(checkout_session_id);

-- ========== EXPERIMENT LOGS (user-owned) ==========
CREATE TABLE IF NOT EXISTS experiment_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  experiment_id text NOT NULL,
  log_date date NOT NULL,
  adhered boolean DEFAULT true,
  notes text,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE experiment_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "explogs_owner_all" ON experiment_logs;
CREATE POLICY "explogs_owner_all" ON experiment_logs FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_explogs_exp ON experiment_logs(experiment_id, log_date DESC);

-- ========== UPDATED_AT TRIGGERS (new tables only) ==========
-- Reuse the existing update_updated_at() function from the iOS schema.
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
    EXECUTE format('DROP TRIGGER IF EXISTS set_updated_date ON %I', tbl);
    EXECUTE format('CREATE TRIGGER set_updated_date BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION update_updated_at()', tbl);
  END LOOP;
END $$;