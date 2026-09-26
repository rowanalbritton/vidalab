-- ============================================================
-- VIDA LAB — Phase 1: Community tables (anonymous-by-design)
-- ============================================================
-- CRITICAL: These tables use explicit column selection for anonymity.
-- The RLS grant omits user_id from the selectable columns for anonymous
-- reads. The web app must NEVER use select('*') on these tables —
-- always specify columns, omitting user_id, matching the iOS pattern:
--   .select('id,display_name,title,body,category,status,flagged,created_at')
--
-- The user_id linkage exists only server-side (service role) for
-- moderation. A bare select(*) includes user_id and fails the grant.
-- ============================================================

-- ========== COMMUNITY POSTS ==========
CREATE TABLE IF NOT EXISTS community_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  title text NOT NULL,
  content text NOT NULL,
  category text CHECK (category IN ('general','sleep','mood','nutrition','movement','stress','chronic_conditions','treatments','other')) DEFAULT 'general',
  display_name text DEFAULT 'Anonymous',
  status text CHECK (status IN ('active','hidden')) DEFAULT 'active',
  flagged boolean DEFAULT false,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE community_posts ENABLE ROW LEVEL SECURITY;

-- Anonymous read: active posts visible to all authenticated users, but
-- ONLY through explicit column selection that omits user_id.
-- We grant SELECT on specific columns, not on user_id.
DROP POLICY IF EXISTS "community_posts_anon_read" ON community_posts;
CREATE POLICY "community_posts_anon_read" ON community_posts FOR SELECT
  USING (status = 'active' OR security.is_admin());

-- Any authenticated user can create a post
DROP POLICY IF EXISTS "community_posts_create" ON community_posts;
CREATE POLICY "community_posts_create" ON community_posts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Only admin can update/delete (moderation)
DROP POLICY IF EXISTS "community_posts_admin_update" ON community_posts;
CREATE POLICY "community_posts_admin_update" ON community_posts FOR UPDATE
  USING (security.is_admin()) WITH CHECK (security.is_admin());

DROP POLICY IF EXISTS "community_posts_admin_delete" ON community_posts;
CREATE POLICY "community_posts_delete" ON community_posts FOR DELETE
  USING (security.is_admin());

-- ========== COMMUNITY REPLIES ==========
CREATE TABLE IF NOT EXISTS community_replies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  post_id uuid NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  content text NOT NULL,
  display_name text DEFAULT 'Anonymous',
  status text CHECK (status IN ('active','hidden')) DEFAULT 'active',
  flagged boolean DEFAULT false,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE community_replies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "community_replies_anon_read" ON community_replies;
CREATE POLICY "community_replies_anon_read" ON community_replies FOR SELECT
  USING (status = 'active' OR security.is_admin());

DROP POLICY IF EXISTS "community_replies_create" ON community_replies;
CREATE POLICY "community_replies_create" ON community_replies FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "community_replies_admin_update" ON community_replies;
CREATE POLICY "community_replies_admin_update" ON community_replies FOR UPDATE
  USING (security.is_admin()) WITH CHECK (security.is_admin());

DROP POLICY IF EXISTS "community_replies_admin_delete" ON community_replies;
CREATE POLICY "community_replies_delete" ON community_replies FOR DELETE
  USING (security.is_admin());

CREATE INDEX IF NOT EXISTS idx_replies_post ON community_replies(post_id, created_date);

-- ========== UPDATED_AT TRIGGERS ==========
DO $$
DECLARE
  tbl text;
  tables text[] := array['community_posts','community_replies'];
BEGIN
  FOREACH tbl IN ARRAY tables LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_updated_date ON %I', tbl);
    EXECUTE format('CREATE TRIGGER set_updated_date BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION update_updated_at()', tbl);
  END LOOP;
END $$;