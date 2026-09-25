-- SUPERSEDED HISTORICAL DRAFT — DO NOT APPLY
--
-- The reviewed production implementation was applied on 2026-09-22 as:
-- * 20260922195212_ios_shared_checkin_events.sql
-- * 20260922195302_secure_ios_checkin_event_rpc.sql
-- * 20260922195342_route_ios_checkin_event_through_edge.sql
--
-- The final write path is the authenticated `sync-checkin-event` Edge
-- Function. This draft remains only as design history and must not be run.
--
-- VIDA LAB encrypted, shared check-in event stream.
--
-- This migration is deliberately additive. It does not modify or delete
-- public.check_ins (the existing encrypted whole-day backup) or
-- public.daily_checkins (the existing plaintext, web-style daily form).
--
-- Why a new table:
-- * An iOS DayLog has two independent periods (morning and evening).
-- * Each period can contain many SignalReadings, with a stable UUID and an
--   individual recorded_at timestamp.
-- * `daily_checkins` cannot represent that structure without losing data and
--   is not encrypted. Moving iOS health data into it would weaken an existing
--   privacy promise.
-- * Whole-DayLog last-writer-wins sync in `check_ins` can lose a morning entry
--   written on one device when another device later writes an evening entry.
--
-- This table makes each encrypted SignalReading an idempotent event. The app
-- will continue writing its existing `check_ins` rows during migration, so
-- existing devices and recovered data remain usable. A website that has the
-- member's passphrase-unlocked escrow key can decrypt these rows with the
-- same AES-GCM envelope as iOS.
--
-- BEFORE APPLYING:
-- 1. Confirm `sync_keys` is live and its RLS policies are restricted to the
--    owner. The browser must derive the member's key locally; no server can
--    decrypt these fields.
-- 2. Create a real migration with `supabase migration new ios_shared_checkin_sync`.
--    Copy this reviewed SQL into that generated migration; do not use this
--    draft filename as migration history.
-- 3. Verify public-schema Data API exposure and grants for this new table.
-- 4. Test every statement against a non-production branch/project with two
--    synthetic accounts and two devices before production use.
-- 5. Run Security and Performance Advisors after the migration.
--
-- The function is SECURITY INVOKER. It does not bypass RLS and cannot accept
-- a row for another member. It resolves retries and out-of-order requests:
-- the server keeps the row with the newest client_updated_at. A tombstone is
-- retained instead of deleting the row, so an offline device cannot bring a
-- deleted reading back on its next retry.

create table public.ios_checkin_events (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    -- SignalReading.id generated and persisted by the iOS client.
    client_id uuid not null,
    local_date date not null,
    period text not null check (period in ('morning', 'evening')),
    timezone text,
    ciphertext text not null,
    schema_version integer not null default 1,
    -- Client timestamp rather than updated_at decides conflicts. Server
    -- receipt time changes on retry and must never make an old edit win.
    client_updated_at timestamptz not null,
    -- A retained tombstone. Its ciphertext remains opaque and must not be
    -- decrypted or shown by clients once deleted_at is present.
    deleted_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, client_id)
);

create index ios_checkin_events_owner_date_idx
    on public.ios_checkin_events (user_id, local_date desc, period);

create index ios_checkin_events_owner_changed_idx
    on public.ios_checkin_events (user_id, client_updated_at desc);

alter table public.ios_checkin_events enable row level security;
revoke all on public.ios_checkin_events from anon;
grant select on public.ios_checkin_events to authenticated;

create policy "Members read their own encrypted check-in events"
    on public.ios_checkin_events
    for select
    to authenticated
    using ((select auth.uid()) = user_id);

-- The app and website use this RPC instead of a raw upsert so a delayed retry
-- cannot overwrite a newer event already accepted from another device.
create or replace function public.apply_ios_checkin_event(
    p_client_id uuid,
    p_local_date date,
    p_period text,
    p_timezone text,
    p_ciphertext text,
    p_schema_version integer,
    p_client_updated_at timestamptz,
    p_deleted_at timestamptz default null
)
returns public.ios_checkin_events
language plpgsql
security invoker
set search_path = public
as $$
declare
    result public.ios_checkin_events;
begin
    if auth.uid() is null then
        raise exception 'Authentication required' using errcode = '42501';
    end if;

    if p_period not in ('morning', 'evening') then
        raise exception 'Invalid check-in period' using errcode = '22023';
    end if;

    insert into public.ios_checkin_events (
        user_id, client_id, local_date, period, timezone, ciphertext,
        schema_version, client_updated_at, deleted_at
    ) values (
        auth.uid(), p_client_id, p_local_date, p_period, p_timezone, p_ciphertext,
        p_schema_version, p_client_updated_at, p_deleted_at
    )
    on conflict (user_id, client_id) do update
    set local_date = excluded.local_date,
        period = excluded.period,
        timezone = excluded.timezone,
        ciphertext = excluded.ciphertext,
        schema_version = excluded.schema_version,
        client_updated_at = excluded.client_updated_at,
        deleted_at = excluded.deleted_at,
        updated_at = now()
    where excluded.client_updated_at > public.ios_checkin_events.client_updated_at
    returning * into result;

    -- An equal/older retry is successful but returns the accepted current row.
    if result.id is null then
        select * into result
        from public.ios_checkin_events
        where user_id = auth.uid() and client_id = p_client_id;
    end if;

    return result;
end;
$$;

revoke all on function public.apply_ios_checkin_event(
    uuid, date, text, text, text, integer, timestamptz, timestamptz
) from public, anon;
grant execute on function public.apply_ios_checkin_event(
    uuid, date, text, text, text, integer, timestamptz, timestamptz
) to authenticated;

comment on table public.ios_checkin_events is
    'Encrypted per-reading iOS check-in stream. Decrypt only client-side with '
    'the member-held key; deleted_at is a sync tombstone, not a record to show.';

-- Post-deployment client protocol (implementation follows only after the
-- migration has been reviewed and applied):
-- * Upsert every SignalReading using its existing UUID as client_id.
-- * Use reading.recordedAt (or a persisted edit timestamp) as client_updated_at.
-- * Retain a local tombstone when a reading is deleted, then submit it through
--   this RPC. Do not hard-delete events from the server.
-- * Pull all owner rows; ignore tombstones; resolve the same client_id by
--   newest client_updated_at. Preserve distinct morning/evening readings.
-- * Keep `check_ins` dual-write during the release transition. Do not attempt
--   to backfill `daily_checkins` with plaintext from the encrypted event stream.
