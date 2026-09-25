-- Encrypted meal log (see MealEntry.swift and VidaSyncService.pushMeals).
--
-- Meals were local-only at first, which meant a lost phone restored every
-- check-in, experiment and doctor prep and none of the food — and Lab Notes'
-- meal card quietly vanished after the restore, because the recap reads from
-- the local store.
--
-- What someone eats is health data like everything else here, so this table
-- holds the same thing the others do: an opaque sync key and ciphertext the
-- server cannot open. No meal name, no note, no comfort score is ever legible
-- to Vida. Mirrors the shape of experiments and doctor_preps exactly, because
-- the client writes all three through the same ClientKeyedRow.

create table if not exists public.meals (
    -- Text rather than uuid, matching user_id in check_ins, experiments,
    -- doctor_preps and saved_articles, and the (select auth.uid())::text
    -- comparison every RLS policy in this schema uses.
    user_id text not null,

    -- MealEntry.id from the device. The client upserts on
    -- (user_id, client_id), so editing a meal updates its row instead of
    -- accumulating a new one every time sync runs.
    client_id text not null,

    -- Base64 of nonce(12) || ciphertext || tag(16), sealed with AES-256-GCM
    -- under the member's own key. Length is not pinned the way sync_keys is:
    -- unlike a wrapped key, a meal payload is legitimately variable.
    ciphertext text not null,

    schema_version integer not null default 1,
    updated_at timestamptz not null default now(),

    primary key (user_id, client_id)
);

comment on table public.meals is
    'Client-encrypted meal log. Ciphertext only — the server cannot read a '
    'meal name, note or comfort score.';

-- Reading a month of meals back for a recap is the common query, and it is
-- always scoped to one member.
create index if not exists meals_user_updated_idx
    on public.meals (user_id, updated_at desc);

alter table public.meals enable row level security;

revoke all on public.meals from anon;
grant select, insert, update, delete on public.meals to authenticated;

drop policy if exists "Users read own meals" on public.meals;
drop policy if exists "Users insert own meals" on public.meals;
drop policy if exists "Users update own meals" on public.meals;
drop policy if exists "Users delete own meals" on public.meals;

create policy "Users read own meals" on public.meals
for select to authenticated using ((select auth.uid())::text = user_id);

create policy "Users insert own meals" on public.meals
for insert to authenticated with check ((select auth.uid())::text = user_id);

-- Update as well as insert: the client upserts on conflict, which needs both.
create policy "Users update own meals" on public.meals
for update to authenticated
using ((select auth.uid())::text = user_id)
with check ((select auth.uid())::text = user_id);

create policy "Users delete own meals" on public.meals
for delete to authenticated using ((select auth.uid())::text = user_id);
