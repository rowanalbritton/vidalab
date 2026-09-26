-- ============================================================
-- VIDA LAB — RLS for existing iOS tables + membership helper
-- ============================================================
-- Run this after supabase_schema.sql. Safe to re-run.
-- ============================================================

-- ========== is_vida_plus helper (security definer) ==========
-- Checks the entitlements table for an active Vida+ membership.
create or replace function security.is_vida_plus() returns boolean as $$
  set search_path = public, pg_temp;
  select exists(
    select 1 from public.entitlements
    where user_id = (select auth.uid())::text
    and status = 'active'
    and (expires_at is null or expires_at > now())
  );
$$ language sql stable security definer;

-- ========== check_ins (user-owned, E2E encrypted) ==========
alter table check_ins enable row level security;
drop policy if exists "check_ins_owner_all" on check_ins;
create policy "check_ins_owner_all" on check_ins for all
  using (user_id = auth.uid()::text) with check (user_id = auth.uid()::text);

-- ========== doctor_preps (user-owned, E2E encrypted) ==========
alter table doctor_preps enable row level security;
drop policy if exists "doctor_preps_owner_all" on doctor_preps;
create policy "doctor_preps_owner_all" on doctor_preps for all
  using (user_id = auth.uid()::text) with check (user_id = auth.uid()::text);

-- ========== experiments (user-owned, E2E encrypted) ==========
alter table experiments enable row level security;
drop policy if exists "experiments_owner_all" on experiments;
create policy "experiments_owner_all" on experiments for all
  using (user_id = auth.uid()::text) with check (user_id = auth.uid()::text);

-- ========== saved_articles (user-owned, E2E encrypted) ==========
alter table saved_articles enable row level security;
drop policy if exists "saved_articles_owner_all" on saved_articles;
create policy "saved_articles_owner_all" on saved_articles for all
  using (user_id = auth.uid()::text) with check (user_id = auth.uid()::text);

-- ========== entitlements (user reads own, service manages) ==========
alter table entitlements enable row level security;
drop policy if exists "entitlements_owner_read" on entitlements;
drop policy if exists "entitlements_admin_all" on entitlements;
create policy "entitlements_owner_read" on entitlements for select
  using (user_id = auth.uid()::text);
create policy "entitlements_admin_all" on entitlements for all
  using (security.is_admin()) with check (security.is_admin());

-- ========== entitlement_log (user reads own, admin all) ==========
alter table entitlement_log enable row level security;
drop policy if exists "entlog_owner_read" on entitlement_log;
drop policy if exists "entlog_admin_all" on entitlement_log;
create policy "entlog_owner_read" on entitlement_log for select
  using (user_id = auth.uid()::text);
create policy "entlog_admin_all" on entitlement_log for all
  using (security.is_admin()) with check (security.is_admin());