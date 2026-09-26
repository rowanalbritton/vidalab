-- ============================================================
-- VIDA LAB — Phase 1: Ask Vida curated library + conversations
-- ============================================================
-- Assumes security.is_admin() and public.update_updated_at()
-- already exist (iOS schema).
-- ============================================================

-- ========== CURATED Q&A LIBRARY ==========
CREATE TABLE IF NOT EXISTS public.curated_qa (
  id text PRIMARY KEY,
  question text NOT NULL,
  short_answer text NOT NULL,
  detail jsonb DEFAULT '[]',
  article_id text,
  track_suggestion text,
  keywords jsonb DEFAULT '[]',
  relevance text DEFAULT 'anyone',
  is_active boolean DEFAULT true,
  sort_order numeric DEFAULT 0,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE public.curated_qa ENABLE ROW LEVEL SECURITY;

-- Public read: active entries visible to all; admin sees all
DROP POLICY IF EXISTS "curated_qa_public_read" ON public.curated_qa;
CREATE POLICY "curated_qa_public_read" ON public.curated_qa
  FOR SELECT TO anon, authenticated
  USING (is_active = true OR security.is_admin());

-- Admin-only write
DROP POLICY IF EXISTS "curated_qa_admin_write" ON public.curated_qa;
CREATE POLICY "curated_qa_admin_write" ON public.curated_qa
  FOR ALL TO authenticated
  USING (security.is_admin()) WITH CHECK (security.is_admin());

-- ========== AGENT CONVERSATIONS (non-health chat only) ==========
CREATE TABLE IF NOT EXISTS public.agent_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  agent_name text DEFAULT 'vida',
  messages jsonb DEFAULT '[]',
  metadata jsonb DEFAULT '{}',
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE public.agent_conversations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "conversations_owner" ON public.agent_conversations;
CREATE POLICY "conversations_owner" ON public.agent_conversations
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_conversations_user ON public.agent_conversations(user_id, created_date DESC);

-- ========== UPDATED_AT TRIGGERS ==========
DO $$
DECLARE
  tbl text;
  tables text[] := array['curated_qa','agent_conversations'];
BEGIN
  FOREACH tbl IN ARRAY tables LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_updated_date ON public.%I', tbl);
    EXECUTE format('CREATE TRIGGER set_updated_date BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.update_updated_at()', tbl);
  END LOOP;
END $$;