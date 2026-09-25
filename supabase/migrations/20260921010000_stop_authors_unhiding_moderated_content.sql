-- Close a moderation bypass: authors could un-hide their own content.
--
-- 20260920220000 granted update on `status` to `authenticated`, and the edit
-- policy passed for `auth.uid() = author_id or is_moderator()`. Both halves
-- are reasonable alone; together they mean a moderator hides a post and its
-- author sets status back to 'active'. The person being moderated was able to
-- undo the moderation.
--
-- Postgres grants are per-role, and "moderator" is a row on profiles rather
-- than a role, so the column grant cannot express this. The split has to live
-- in the policies instead.
--
-- RLS gives us exactly the two halves needed: USING sees the existing row,
-- WITH CHECK sees the proposed one. Constraining both to 'active' on the
-- author branch means an author can edit a live post, cannot touch a hidden
-- one, and cannot move a row between those states in either direction.
--
-- Multiple permissive policies for the same command are OR'd, so moderators
-- keep full reach through their own policy.
--
-- Authors lose the ability to hide their own post. That was never surfaced in
-- the app -- the UI offers delete -- and "hide yourself" and "un-hide what a
-- moderator hid" are the same grant.

-- MARK: - Posts

drop policy if exists "Edit own posts or moderate" on public.community_posts;

create policy "Edit own active posts" on public.community_posts
for update to authenticated
using ((select auth.uid())::text = author_id and status = 'active')
with check ((select auth.uid())::text = author_id and status = 'active');

create policy "Moderators edit any post" on public.community_posts
for update to authenticated
using (public.is_moderator())
with check (public.is_moderator());

-- MARK: - Replies

drop policy if exists "Edit own replies or moderate" on public.community_replies;

create policy "Edit own active replies" on public.community_replies
for update to authenticated
using ((select auth.uid())::text = author_id and status = 'active')
with check ((select auth.uid())::text = author_id and status = 'active');

create policy "Moderators edit any reply" on public.community_replies
for update to authenticated
using (public.is_moderator())
with check (public.is_moderator());

-- MARK: - Flags
--
-- Narrow the read grant. Rows are already restricted to moderators by policy,
-- so nothing leaks today, but the grant covered every column including
-- reporter_id — one loosened policy away from showing a member who reported
-- them, which is the retaliation the flags table exists to prevent.
--
-- reporter_id is dropped from the grant entirely rather than kept for
-- moderators: grants are per-role and "moderator" is a row on profiles, not a
-- role, so there is no way to grant it to only them. No client reads this
-- table at all today — CommunityService inserts and never selects — so this
-- costs nothing. Reviewing the queue happens through the dashboard, where the
-- service role bypasses grants anyway.
--
-- The unique indexes still stop a reporter filing twice, because a constraint
-- does not need the column to be selectable.

revoke select on public.community_flags from authenticated;
grant select (id, post_id, reply_id, created_at)
    on public.community_flags to authenticated;
