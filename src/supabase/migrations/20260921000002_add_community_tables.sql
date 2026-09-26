-- ============================================================
-- VIDA LAB — Phase 1: Community tables (anonymous-by-design)
-- ============================================================
-- CRITICAL: RLS filters ROWS, not COLUMNS. To actually hide user_id
-- from API responses, we use column-level GRANT/REVOKE in addition
-- to RLS. The anon/authenticated roles can only SELECT the columns
-- explicitly granted — user_id is excluded from the SELECT grant.
-- INSERT still needs user_id (for the RLS check), so it is included
-- in the INSERT grant only.
--
-- The web app should still use explicit column selection in queries
-- as a defense-in-depth measure, but the column grant is what
-- actually enforces anonymity at the database level.
-- ============================================================

-- ========== COMMUNITY POSTS ==========
CREATE TABLE IF NOT EXISTS public.community_posts (
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

ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;

-- RLS: active posts visible to authenticated users; hidden admin-only
DROP POLICY IF EXISTS "community_posts_read" ON public.community_posts;
CREATE POLICY "community_posts_read" ON public.community_posts
  FOR SELECT TO authenticated
  USING (status = 'active' OR security.is_admin());

-- Any authenticated user can create a post (RLS checks ownership)
DROP POLICY IF EXISTS "community_posts_create" ON public.community_posts;
CREATE POLICY "community_posts_create" ON public.community_posts
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Only admin can update/delete (moderation)
DROP POLICY IF EXISTS "community_posts_admin_update" ON public.community_posts;
CREATE POLICY "community_posts_admin_update" ON public.community_posts
  FOR UPDATE TO authenticated
  USING (security.is_admin()) WITH CHECK (security.is_admin());

DROP POLICY IF EXISTS "community_posts_admin_delete" ON public.community_posts;
CREATE POLICY "community_posts_delete" ON public.community_posts
  FOR DELETE TO authenticated
  USING (security.is_admin());

-- Column-level security: hide user_id from SELECT, allow it for INSERT
REVOKE ALL ON public.community_posts FROM PUBLIC, anon, authenticated;
GRANT SELECT (id, title, content, category, display_name, status, flagged, created_date, updated_date)
  ON public.community_posts TO authenticated;
GRANT INSERT (id, user_id, title, content, category, display_name, status, flagged)
  ON public.community_posts TO authenticated;
GRANT UPDATE (title, content, category, display_name, status, flagged)
  ON public.community_posts TO authenticated;
GRANT DELETE ON public.community_posts TO authenticated;

-- ========== COMMUNITY REPLIES ==========
CREATE TABLE IF NOT EXISTS public.community_replies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  post_id uuid NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  content text NOT NULL,
  display_name text DEFAULT 'Anonymous',
  status text CHECK (status IN ('active','hidden')) DEFAULT 'active',
  flagged boolean DEFAULT false,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE public.community_replies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "community_replies_read" ON public.community_replies;
CREATE POLICY "community_replies_read" ON public.community_replies
  FOR SELECT TO authenticated
  USING (status = 'active' OR security.is_admin());

DROP POLICY IF EXISTS "community_replies_create" ON public.community_replies;
CREATE POLICY "community_replies_create" ON public.community_replies
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "community_replies_admin_update" ON public.community_replies;
CREATE POLICY "community_replies_admin_update" ON public.community_replies
  FOR UPDATE TO authenticated
  USING (security.is_admin()) WITH CHECK (security.is_admin());

DROP POLICY IF EXISTS "community_replies_admin_delete" ON public.community_replies;
CREATE POLICY "community_replies_delete" ON public.community_replies
  FOR DELETE TO authenticated
  USING (security.is_admin());

-- Column-level security: hide user_id from SELECT
REVOKE ALL ON public.community_replies FROM PUBLIC, anon, authenticated;
GRANT SELECT (id, post_id, content, display_name, status, flagged, created_date, updated_date)
  ON public.community_replies TO authenticated;
GRANT INSERT (id, user_id, post_id, content, display_name, status, flagged)
  ON public.community_replies TO authenticated;
GRANT UPDATE (content, display_name, status, flagged)
  ON public.community_replies TO authenticated;
GRANT DELETE ON public.community_replies TO authenticated;

CREATE INDEX IF NOT EXISTS idx_replies_post ON public.community_replies(post_id, created_date);

-- ========== UPDATED_AT TRIGGERS ==========
DO $$
DECLARE
  tbl text;
  tables text[] := array['community_posts','community_replies'];
BEGIN
  FOREACH tbl IN ARRAY tables LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_updated_date ON public.%I', tbl);
    EXECUTE format('CREATE TRIGGER set_updated_date BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.update_updated_at()', tbl);
  END LOOP;
END $$;