create table if not exists public.ios_checkin_events (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    client_id uuid not null,
    local_date date not null,
    period text not null check (period in ('morning', 'evening')),
    timezone text,
    ciphertext text not null,
    schema_version integer not null default 1,
    client_updated_at timestamptz not null,
    deleted_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, client_id)
);

create index if not exists ios_checkin_events_owner_date_idx
    on public.ios_checkin_events (user_id, local_date desc, period);
create index if not exists ios_checkin_events_owner_changed_idx
    on public.ios_checkin_events (user_id, client_updated_at desc);

alter table public.ios_checkin_events enable row level security;
revoke all on public.ios_checkin_events from anon;
grant select on public.ios_checkin_events to authenticated;

drop policy if exists "Members read their own encrypted check-in events"
    on public.ios_checkin_events;
create policy "Members read their own encrypted check-in events"
    on public.ios_checkin_events
    for select
    to authenticated
    using ((select auth.uid()) = user_id);

comment on table public.ios_checkin_events is
    'Encrypted per-reading iOS check-in stream. Decrypt only client-side with the member-held key; deleted_at is a sync tombstone, not a record to show.';
