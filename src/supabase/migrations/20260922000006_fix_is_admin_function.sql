-- ============================================================
-- VIDA LAB — Fix security.is_admin() function
-- ============================================================
-- The is_admin() function was created with SET search_path = public
-- while marked STABLE, which PostgreSQL rejects with
-- "SET is not allowed in a non-volatile function."
-- This broke EVERY RLS policy referencing is_admin(), causing all
-- public tables (health_resources, disease_reports, explainers,
-- doctors, etc.) to return zero rows to anon/authenticated users.
--
-- Fix: recreate without the SET option. The function body already
-- uses fully-qualified names (public.profiles, auth.uid()), so the
-- SET search_path was redundant anyway.
-- ============================================================

-- Fix is_admin: remove SET search_path, keep STABLE + SECURITY DEFINER
CREATE OR REPLACE FUNCTION security.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

-- Fix is_vida_plus: same issue — remove SET from inside body
CREATE OR REPLACE FUNCTION security.is_vida_plus()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.entitlements
    WHERE user_id = (SELECT auth.uid())::text
    AND status = 'active'
    AND (expires_at IS NULL OR expires_at > now())
  );
$$;

-- Verify the fix works (this would have thrown before)
-- Note: returns false for anon/service_role since auth.uid() is null
SELECT security.is_admin() as admin_check_works;