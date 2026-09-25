-- Peer-to-peer community: posts, replies, flagging and moderation.
--
-- IMPORTANT: this is the first plaintext member content in the schema.
--
-- Every other health table holds AES-GCM ciphertext under a key the server
-- never sees. Community content cannot work that way — other people have to
-- read it — so these tables are readable by anyone with database access. That
-- is inherent to the feature, not an oversight, and the app says so plainly
-- before anyone posts.
--
-- What the schema can still protect is *who wrote what*. `author_id` is
-- needed for ownership and moderation, but no member may ever see another
-- member's. That is enforced with column-level grants below rather than left
-- to the client to remember.

-- Moderator flag. Lives on profiles because that is the row the app already
-- reads for every member.
alter table public.profiles
    add column if not exists is_moderator boolean not null default false;

comment on column public.profiles.is_moderator is
    'Grants visibility of hidden and flagged community content. Set manually; '
    'there is deliberately no way to grant this from the app.';

-- Recursion guard: the community policies below ask "is the caller a
-- moderator", which reads profiles. A security-definer function keeps that
-- lookup from re-entering RLS on profiles and deadlocking the planner.
create or replace function public.is_moderator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(
        (select p.is_moderator from public.profiles p where p.id = (select auth.uid())::text),
        false
    );
$$;

revoke all on function public.is_moderator() from public, anon;
grant execute on function public.is_moderator() to authenticated;

-- MARK: - Posts

create table if not exists public.community_posts (
    id uuid primary key default gen_random_uuid(),

    -- Text to match user_id everywhere else in this schema.
    author_id text not null,

    -- What other members see. Never linked to author_id in any response.
    -- Defaulted rather than required so a client that forgets the field
    -- produces an anonymous post rather than a broken one.
    display_name text not null default 'Anonymous'
        constraint community_posts_display_name_length
            check (char_length(display_name) between 1 and 50),

    title text not null
        constraint community_posts_title_length
            check (char_length(btrim(title)) between 3 and 140),

    body text not null
        constraint community_posts_body_length
            check (char_length(btrim(body)) between 1 and 5000),

    category text not null default 'general'
        constraint community_posts_category_known check (category in (
            'general', 'sleep', 'mood', 'nutrition', 'movement',
            'stress', 'chronic_conditions', 'treatments', 'other'
        )),

    status text not null default 'active'
        constraint community_posts_status_known check (status in ('active', 'hidden')),

    -- Maintained by trigger from community_flags. Not writable by members:
    -- letting a client set this directly would let anyone hide their own
    -- content from moderation, or forge a report against someone else.
    flagged boolean not null default false,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists community_posts_feed_idx
    on public.community_posts (status, created_at desc);
create index if not exists community_posts_category_idx
    on public.community_posts (category, status, created_at desc);

-- MARK: - Replies

create table if not exists public.community_replies (
    id uuid primary key default gen_random_uuid(),
    post_id uuid not null references public.community_posts(id) on delete cascade,
    author_id text not null,

    display_name text not null default 'Anonymous'
        constraint community_replies_display_name_length
            check (char_length(display_name) between 1 and 50),

    body text not null
        constraint community_replies_body_length
            check (char_length(btrim(body)) between 1 and 5000),

    status text not null default 'active'
        constraint community_replies_status_known check (status in ('active', 'hidden')),

    flagged boolean not null default false,
    created_at timestamptz not null default now()
);

create index if not exists community_replies_thread_idx
    on public.community_replies (post_id, status, created_at);

-- MARK: - Flags
--
-- A table rather than a boolean anyone can set. One row per reporter per
-- target, so the same person cannot inflate a report, and moderators can see
-- how many separate people objected rather than a bare true.

create table if not exists public.community_flags (
    id uuid primary key default gen_random_uuid(),
    reporter_id text not null,
    post_id uuid references public.community_posts(id) on delete cascade,
    reply_id uuid references public.community_replies(id) on delete cascade,
    created_at timestamptz not null default now(),

    -- Exactly one target.
    constraint community_flags_one_target check (
        (post_id is not null and reply_id is null) or
        (post_id is null and reply_id is not null)
    )
);

create unique index if not exists community_flags_unique_post
    on public.community_flags (reporter_id, post_id) where post_id is not null;
create unique index if not exists community_flags_unique_reply
    on public.community_flags (reporter_id, reply_id) where reply_id is not null;

-- Flagged content stays visible until a moderator hides it, per the spec —
-- otherwise one person could silence any post by reporting it.
create or replace function public.mark_flagged()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if new.post_id is not null then
        update public.community_posts set flagged = true where id = new.post_id;
    else
        update public.community_replies set flagged = true where id = new.reply_id;
    end if;
    return new;
end;
$$;

drop trigger if exists community_flags_mark on public.community_flags;
create trigger community_flags_mark
    after insert on public.community_flags
    for each row execute function public.mark_flagged();

-- MARK: - Row level security

alter table public.community_posts enable row level security;
alter table public.community_replies enable row level security;
alter table public.community_flags enable row level security;

revoke all on public.community_posts from anon;
revoke all on public.community_replies from anon;
revoke all on public.community_flags from anon;

-- Column-level grants are what actually keep author_id private. RLS filters
-- rows, not columns, so without this a member could simply select author_id
-- and deanonymise the entire board.
grant select (id, display_name, title, body, category, status, flagged, created_at, updated_at)
    on public.community_posts to authenticated;
grant insert (author_id, display_name, title, body, category) on public.community_posts to authenticated;
grant update (title, body, category, status) on public.community_posts to authenticated;
grant delete on public.community_posts to authenticated;

grant select (id, post_id, display_name, body, status, flagged, created_at)
    on public.community_replies to authenticated;
grant insert (post_id, author_id, display_name, body) on public.community_replies to authenticated;
grant update (body, status) on public.community_replies to authenticated;
grant delete on public.community_replies to authenticated;

grant insert (reporter_id, post_id, reply_id) on public.community_flags to authenticated;
grant select on public.community_flags to authenticated;

-- Posts

drop policy if exists "Read active posts" on public.community_posts;
create policy "Read active posts" on public.community_posts
for select to authenticated
using (status = 'active' or public.is_moderator());

drop policy if exists "Write own posts" on public.community_posts;
create policy "Write own posts" on public.community_posts
for insert to authenticated
with check ((select auth.uid())::text = author_id);

-- Authors may edit their own; moderators may hide anything. An author cannot
-- reach another member's row, and neither can change author_id — it is not in
-- the update grant.
drop policy if exists "Edit own posts or moderate" on public.community_posts;
create policy "Edit own posts or moderate" on public.community_posts
for update to authenticated
using ((select auth.uid())::text = author_id or public.is_moderator())
with check ((select auth.uid())::text = author_id or public.is_moderator());

drop policy if exists "Delete own posts or moderate" on public.community_posts;
create policy "Delete own posts or moderate" on public.community_posts
for delete to authenticated
using ((select auth.uid())::text = author_id or public.is_moderator());

-- Replies

drop policy if exists "Read active replies" on public.community_replies;
create policy "Read active replies" on public.community_replies
for select to authenticated
using (status = 'active' or public.is_moderator());

drop policy if exists "Write own replies" on public.community_replies;
create policy "Write own replies" on public.community_replies
for insert to authenticated
with check ((select auth.uid())::text = author_id);

drop policy if exists "Edit own replies or moderate" on public.community_replies;
create policy "Edit own replies or moderate" on public.community_replies
for update to authenticated
using ((select auth.uid())::text = author_id or public.is_moderator())
with check ((select auth.uid())::text = author_id or public.is_moderator());

drop policy if exists "Delete own replies or moderate" on public.community_replies;
create policy "Delete own replies or moderate" on public.community_replies
for delete to authenticated
using ((select auth.uid())::text = author_id or public.is_moderator());

-- Flags

drop policy if exists "Report content" on public.community_flags;
create policy "Report content" on public.community_flags
for insert to authenticated
with check ((select auth.uid())::text = reporter_id);

-- Only moderators read the queue. A member seeing who reported them is
-- exactly the retaliation risk reporting exists to avoid.
drop policy if exists "Moderators read flags" on public.community_flags;
create policy "Moderators read flags" on public.community_flags
for select to authenticated
using (public.is_moderator());

comment on table public.community_posts is
    'Peer-to-peer posts. PLAINTEXT, unlike every other member table — other '
    'members have to read it. author_id is withheld by column grant.';
