drop policy if exists "Users can read own profile" on public.profiles;
drop policy if exists "Users can insert own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Users can delete own profile" on public.profiles;

create policy "Users can read own profile" on public.profiles
for select to authenticated using ((select auth.uid())::text = id);
create policy "Users can insert own profile" on public.profiles
for insert to authenticated with check ((select auth.uid())::text = id);
create policy "Users can update own profile" on public.profiles
for update to authenticated
using ((select auth.uid())::text = id)
with check ((select auth.uid())::text = id);
create policy "Users can delete own profile" on public.profiles
for delete to authenticated using ((select auth.uid())::text = id);

drop policy if exists "Users read own check_ins" on public.check_ins;
drop policy if exists "Users insert own check_ins" on public.check_ins;
drop policy if exists "Users update own check_ins" on public.check_ins;
drop policy if exists "Users delete own check_ins" on public.check_ins;

create policy "Users read own check_ins" on public.check_ins
for select to authenticated using ((select auth.uid())::text = user_id);
create policy "Users insert own check_ins" on public.check_ins
for insert to authenticated with check ((select auth.uid())::text = user_id);
create policy "Users update own check_ins" on public.check_ins
for update to authenticated
using ((select auth.uid())::text = user_id)
with check ((select auth.uid())::text = user_id);
create policy "Users delete own check_ins" on public.check_ins
for delete to authenticated using ((select auth.uid())::text = user_id);

drop policy if exists "Users read own experiments" on public.experiments;
drop policy if exists "Users insert own experiments" on public.experiments;
drop policy if exists "Users update own experiments" on public.experiments;
drop policy if exists "Users delete own experiments" on public.experiments;

create policy "Users read own experiments" on public.experiments
for select to authenticated using ((select auth.uid())::text = user_id);
create policy "Users insert own experiments" on public.experiments
for insert to authenticated with check ((select auth.uid())::text = user_id);
create policy "Users update own experiments" on public.experiments
for update to authenticated
using ((select auth.uid())::text = user_id)
with check ((select auth.uid())::text = user_id);
create policy "Users delete own experiments" on public.experiments
for delete to authenticated using ((select auth.uid())::text = user_id);

drop policy if exists "Users read own doctor_preps" on public.doctor_preps;
drop policy if exists "Users insert own doctor_preps" on public.doctor_preps;
drop policy if exists "Users update own doctor_preps" on public.doctor_preps;
drop policy if exists "Users delete own doctor_preps" on public.doctor_preps;

create policy "Users read own doctor_preps" on public.doctor_preps
for select to authenticated using ((select auth.uid())::text = user_id);
create policy "Users insert own doctor_preps" on public.doctor_preps
for insert to authenticated with check ((select auth.uid())::text = user_id);
create policy "Users update own doctor_preps" on public.doctor_preps
for update to authenticated
using ((select auth.uid())::text = user_id)
with check ((select auth.uid())::text = user_id);
create policy "Users delete own doctor_preps" on public.doctor_preps
for delete to authenticated using ((select auth.uid())::text = user_id);

drop policy if exists "Users read own saved_articles" on public.saved_articles;
drop policy if exists "Users insert own saved_articles" on public.saved_articles;
drop policy if exists "Users delete own saved_articles" on public.saved_articles;

create policy "Users read own saved_articles" on public.saved_articles
for select to authenticated using ((select auth.uid())::text = user_id);
create policy "Users insert own saved_articles" on public.saved_articles
for insert to authenticated with check ((select auth.uid())::text = user_id);
create policy "Users delete own saved_articles" on public.saved_articles
for delete to authenticated using ((select auth.uid())::text = user_id);

drop policy if exists "Users read own entitlement" on public.entitlements;
create policy "Users read own entitlement" on public.entitlements
for select to authenticated using ((select auth.uid())::text = user_id);

drop policy if exists "Users read own entitlement_log" on public.entitlement_log;
create policy "Users read own entitlement_log" on public.entitlement_log
for select to authenticated using ((select auth.uid())::text = user_id);
