-- APNs device tokens, so Vida can send a nudge to a phone that is not open.
--
-- A token identifies a device, not a person, but it is still an identifier
-- tied to an account: leaking the set of tokens for a member would leak how
-- many devices they use and let anyone holding a push key reach them. So the
-- table is owner-scoped like everything else, and `anon` gets nothing.

create table if not exists public.push_tokens (
    user_id uuid not null references auth.users(id) on delete cascade,
    -- The APNs device token, hex. Primary key on its own because a token can
    -- be reassigned to a different account when a phone changes hands, and
    -- the newest claim is the correct one.
    device_token text not null primary key,
    -- 'sandbox' during development, 'production' for TestFlight and the store.
    -- Sending to the wrong APNs host fails with BadDeviceToken, so the sender
    -- has to know which one issued this token.
    environment text not null default 'production'
        check (environment in ('sandbox', 'production')),
    -- Lets the sender skip devices the member has since turned Vida off on,
    -- without deleting the row and losing the environment.
    enabled boolean not null default true,
    locale text,
    updated_at timestamptz not null default now(),
    created_at timestamptz not null default now()
);

create index if not exists push_tokens_owner_idx
    on public.push_tokens (user_id) where enabled;

alter table public.push_tokens enable row level security;
revoke all on public.push_tokens from anon;
grant select, insert, update, delete on public.push_tokens to authenticated;

drop policy if exists "Members manage their own device tokens" on public.push_tokens;
create policy "Members manage their own device tokens" on public.push_tokens
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

comment on table public.push_tokens is
    'APNs device tokens per member. A phone changing hands re-claims its token '
    'through the primary key, so a previous owner stops receiving that device.';

-- Registering has to survive the token already existing under *another*
-- account, which RLS alone cannot do: the row belongs to the old owner, so the
-- new owner cannot see or update it and a plain upsert fails the policy.
create or replace function public.claim_push_token(
    p_device_token text,
    p_environment text default 'production',
    p_locale text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    caller uuid := (select auth.uid());
begin
    if caller is null then
        raise exception 'Authentication required' using errcode = '28000';
    end if;

    if p_environment not in ('sandbox', 'production') then
        raise exception 'Unknown push environment' using errcode = '22023';
    end if;

    insert into public.push_tokens (user_id, device_token, environment, locale, enabled)
    values (caller, p_device_token, p_environment, p_locale, true)
    on conflict (device_token) do update
    set user_id = caller,
        environment = excluded.environment,
        locale = excluded.locale,
        enabled = true,
        updated_at = now();
end;
$$;

revoke all on function public.claim_push_token(text, text, text) from public, anon;
grant execute on function public.claim_push_token(text, text, text) to authenticated;
