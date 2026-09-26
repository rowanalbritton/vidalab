-- Reconciles community_posts / community_replies onto the iOS column names.
--
-- Two migrations created these tables a day apart with incompatible columns,
-- and both used CREATE TABLE IF NOT EXISTS — so whichever ran first won
-- silently and the other client has been broken ever since, with no error at
-- migration time:
--
--                 iOS 20260920220000   website 20260921000002
--   owner         author_id (text)     user_id (uuid)
--   body          body                 content
--   timestamp     created_at           created_date
--
-- The iOS names are canonical (decided 2026-09-24): that schema lets an author
-- edit their own post, and it hides the owner column behind a column grant
-- rather than relying on clients to remember to omit it from SELECT lists.
--
-- Every step is conditional on the current state, so this is safe to run
-- whichever migration actually landed, and safe to re-run.

-- MARK: - community_posts

do $$
begin
    if not exists (select 1 from information_schema.tables
                   where table_schema = 'public' and table_name = 'community_posts') then
        raise notice 'community_posts does not exist; nothing to reconcile.';
        return;
    end if;

    -- content -> body
    if exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'community_posts'
                 and column_name = 'content')
       and not exists (select 1 from information_schema.columns
                       where table_schema = 'public' and table_name = 'community_posts'
                         and column_name = 'body') then
        alter table public.community_posts rename column content to body;
        raise notice 'community_posts.content renamed to body.';
    end if;

    -- created_date -> created_at
    if exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'community_posts'
                 and column_name = 'created_date')
       and not exists (select 1 from information_schema.columns
                       where table_schema = 'public' and table_name = 'community_posts'
                         and column_name = 'created_at') then
        alter table public.community_posts rename column created_date to created_at;
        raise notice 'community_posts.created_date renamed to created_at.';
    end if;

    -- updated_date -> updated_at
    if exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'community_posts'
                 and column_name = 'updated_date')
       and not exists (select 1 from information_schema.columns
                       where table_schema = 'public' and table_name = 'community_posts'
                         and column_name = 'updated_at') then
        alter table public.community_posts rename column updated_date to updated_at;
    end if;

    -- user_id -> author_id. The iOS schema types this as text holding the
    -- uuid, matching every other owner column in that schema; the cast is
    -- explicit so a uuid column converts rather than failing.
    if exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'community_posts'
                 and column_name = 'user_id')
       and not exists (select 1 from information_schema.columns
                       where table_schema = 'public' and table_name = 'community_posts'
                         and column_name = 'author_id') then
        alter table public.community_posts rename column user_id to author_id;
        alter table public.community_posts alter column author_id type text using author_id::text;
        raise notice 'community_posts.user_id renamed to author_id and cast to text.';
    end if;
end $$;

-- MARK: - community_replies

do $$
begin
    if not exists (select 1 from information_schema.tables
                   where table_schema = 'public' and table_name = 'community_replies') then
        return;
    end if;

    if exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'community_replies'
                 and column_name = 'content')
       and not exists (select 1 from information_schema.columns
                       where table_schema = 'public' and table_name = 'community_replies'
                         and column_name = 'body') then
        alter table public.community_replies rename column content to body;
    end if;

    if exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'community_replies'
                 and column_name = 'created_date')
       and not exists (select 1 from information_schema.columns
                       where table_schema = 'public' and table_name = 'community_replies'
                         and column_name = 'created_at') then
        alter table public.community_replies rename column created_date to created_at;
    end if;

    if exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'community_replies'
                 and column_name = 'user_id')
       and not exists (select 1 from information_schema.columns
                       where table_schema = 'public' and table_name = 'community_replies'
                         and column_name = 'author_id') then
        alter table public.community_replies rename column user_id to author_id;
        alter table public.community_replies alter column author_id type text using author_id::text;
    end if;
end $$;

-- MARK: - Confirm the result

-- Fails loudly rather than leaving a half-reconciled schema behind. If this
-- raises, the tables were in a shape neither migration produces — stop and
-- inspect before running anything else against them.
do $$
declare
    missing text;
begin
    select string_agg(expected, ', ')
    into missing
    from (values
        ('community_posts.body'), ('community_posts.created_at'), ('community_posts.author_id'),
        ('community_replies.body'), ('community_replies.created_at'), ('community_replies.author_id')
    ) as required(expected)
    where not exists (
        select 1 from information_schema.columns
        where table_schema = 'public'
          and table_name = split_part(required.expected, '.', 1)
          and column_name = split_part(required.expected, '.', 2)
    )
    and exists (
        select 1 from information_schema.tables
        where table_schema = 'public' and table_name = split_part(required.expected, '.', 1)
    );

    if missing is not null then
        raise exception 'Community reconciliation incomplete; still missing: %', missing;
    end if;
end $$;
