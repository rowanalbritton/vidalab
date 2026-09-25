-- Blocking, for App Review guideline 1.2.
--
-- The hard constraint is that `author_id` is withheld from clients by column
-- grant, so the app cannot name the person it wants to block. Everything here
-- follows from that: the member blocks a *post or reply*, the server resolves
-- the author behind it, and the block list is never readable by the client.
-- Handing that list back would return the author_id the column grant exists to
-- hide, and deanonymise everyone the member ever blocked.

create table if not exists public.community_blocks (
    blocker_id text not null,
    blocked_author_id text not null,
    created_at timestamptz not null default now(),

    primary key (blocker_id, blocked_author_id),
    constraint community_blocks_not_self check (blocker_id <> blocked_author_id)
);

create index if not exists community_blocks_blocker_idx
    on public.community_blocks (blocker_id);

alter table public.community_blocks enable row level security;
revoke all on public.community_blocks from anon, authenticated;

comment on table public.community_blocks is
    'Who a member has blocked. Written and read only through the functions '
    'below; a direct grant would expose the author_id the column grants hide.';

-- MARK: - Blocking

create or replace function public.block_community_author(
    p_post_id uuid default null,
    p_reply_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    caller text := (select auth.uid())::text;
    target text;
begin
    if caller is null then
        raise exception 'Authentication required' using errcode = '28000';
    end if;

    if (p_post_id is null) = (p_reply_id is null) then
        raise exception 'Block exactly one post or one reply' using errcode = '22023';
    end if;

    if p_post_id is not null then
        select author_id into target from public.community_posts where id = p_post_id;
    else
        select author_id into target from public.community_replies where id = p_reply_id;
    end if;

    if target is null then
        raise exception 'That content no longer exists' using errcode = 'P0002';
    end if;

    -- Blocking yourself would hide your own posts from you, which reads as a
    -- bug rather than a feature.
    if target = caller then
        raise exception 'You cannot block yourself' using errcode = '22023';
    end if;

    insert into public.community_blocks (blocker_id, blocked_author_id)
    values (caller, target)
    on conflict (blocker_id, blocked_author_id) do nothing;
end;
$$;

-- How many people the member has blocked. A count carries no author_id, so it
-- is safe to show in Settings where the list itself would not be.
create or replace function public.community_block_count()
returns integer
language sql
security definer
set search_path = public
as $$
    select count(*)::integer
    from public.community_blocks
    where blocker_id = (select auth.uid())::text;
$$;

-- The only way back. Unblocking one person would mean handing the client a
-- handle for that person, so the escape hatch is all-or-nothing by design.
create or replace function public.unblock_all_community_authors()
returns void
language sql
security definer
set search_path = public
as $$
    delete from public.community_blocks
    where blocker_id = (select auth.uid())::text;
$$;

revoke all on function public.block_community_author(uuid, uuid) from public, anon;
revoke all on function public.community_block_count() from public, anon;
revoke all on function public.unblock_all_community_authors() from public, anon;

grant execute on function public.block_community_author(uuid, uuid) to authenticated;
grant execute on function public.community_block_count() to authenticated;
grant execute on function public.unblock_all_community_authors() to authenticated;

-- MARK: - Blocked content disappears

-- Folding the block into the read policies means every existing query filters
-- automatically: the app's select lists, ordering and pagination are unchanged,
-- and there is no way to forget the filter at a call site.
--
-- Moderators keep seeing everything, because a moderator's personal block list
-- must not punch a hole in the moderation queue.

create or replace function public.is_blocked_by_viewer(p_author_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.community_blocks
        where blocker_id = (select auth.uid())::text
          and blocked_author_id = p_author_id
    );
$$;

revoke all on function public.is_blocked_by_viewer(text) from public, anon;
grant execute on function public.is_blocked_by_viewer(text) to authenticated;

drop policy if exists "Read active posts" on public.community_posts;
create policy "Read active posts" on public.community_posts
for select to authenticated
using (
    public.is_moderator()
    or (status = 'active' and not public.is_blocked_by_viewer(author_id))
);

drop policy if exists "Read active replies" on public.community_replies;
create policy "Read active replies" on public.community_replies
for select to authenticated
using (
    public.is_moderator()
    or (status = 'active' and not public.is_blocked_by_viewer(author_id))
);
