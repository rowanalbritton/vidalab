-- ============================================================
-- VIDA LAB — Phase 1: Ask Vida curated library + conversations
-- ============================================================
-- The curated_qa table mirrors the iOS AskVidaLibrary.swift entries.
-- Both web and iOS read from this table — single source of truth,
-- no divergent health claims.
--
-- Two rules enforced by the application layer:
-- 1. No answer without sources — entries with empty citations are
--    filtered out of suggested questions.
-- 2. relevance suggests, never restricts — someone asking a question
--    outright gets the best answer regardless of sex.
-- ============================================================

-- ========== CURATED Q&A LIBRARY ==========
CREATE TABLE IF NOT EXISTS curated_qa (
  id text PRIMARY KEY,                    -- matches VidaAnswer.id
  question text NOT NULL,
  short_answer text NOT NULL,
  detail jsonb DEFAULT '[]',             -- array of strings
  article_id text,                       -- links to citation-bearing article/explainer
  track_suggestion text,                 -- SignalCategory enum
  keywords jsonb DEFAULT '[]',           -- array of strings
  relevance text DEFAULT 'anyone',       -- anyone | female | male (suggests, never restricts)
  is_active boolean DEFAULT true,
  sort_order numeric DEFAULT 0,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE curated_qa ENABLE ROW LEVEL SECURITY;

-- Public read: active entries visible to all; admin sees all
DROP POLICY IF EXISTS "curated_qa_public_read" ON curated_qa;
CREATE POLICY "curated_qa_public_read" ON curated_qa FOR SELECT
  USING (is_active = true OR security.is_admin());

-- Admin-only write
DROP POLICY IF EXISTS "curated_qa_admin_write" ON curated_qa;
CREATE POLICY "curated_qa_admin_write" ON curated_qa FOR ALL
  USING (security.is_admin()) WITH CHECK (security.is_admin());

-- ========== AGENT CONVERSATIONS (non-health chat only) ==========
CREATE TABLE IF NOT EXISTS agent_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  agent_name text DEFAULT 'vida',
  messages jsonb DEFAULT '[]',
  metadata jsonb DEFAULT '{}',
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE agent_conversations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "conversations_owner" ON agent_conversations;
CREATE POLICY "conversations_owner" ON agent_conversations FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_conversations_user ON agent_conversations(user_id, created_date DESC);

-- ========== UPDATED_AT TRIGGERS ==========
DO $$
DECLARE
  tbl text;
  tables text[] := array['curated_qa','agent_conversations'];
BEGIN
  FOREACH tbl IN ARRAY tables LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_updated_date ON %I', tbl);
    EXECUTE format('CREATE TRIGGER set_updated_date BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION update_updated_at()', tbl);
  END LOOP;
END $$;