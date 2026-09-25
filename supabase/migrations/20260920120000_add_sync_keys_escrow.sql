-- Passphrase escrow for the sync key (see VidaKeyEscrow.swift).
--
-- The sync key is a random 256-bit value that lives in the iCloud Keychain,
-- which a browser has no way to reach. This table holds a second, *wrapped*
-- copy of that same key — sealed under a key derived from a passphrase only
-- the member knows — so the website can derive it with WebCrypto and open the
-- ciphertext in the other tables.
--
-- Every column here is safe to store in plain text. The salt and iteration
-- count are public inputs by design, and wrapped_key is useless without the
-- passphrase, which never leaves the device. The server cannot open any of it.

create table if not exists public.sync_keys (
    -- One wrapped key per member. Text rather than uuid to match user_id in
    -- check_ins, experiments, doctor_preps and saved_articles, and the
    -- (select auth.uid())::text comparison the RLS policies all use.
    --
    -- No FK to auth.users: the types don't line up for one, and the rest of
    -- the schema doesn't have one either. The app deletes this row alongside
    -- every other table in deleteAllRemoteData().
    user_id text primary key,

    -- Named so the parameters can be raised later without orphaning records
    -- written under the old ones. Constrained to what unwrap() will accept —
    -- a row the app would reject should never have been writable.
    kdf text not null default 'PBKDF2-HMAC-SHA256'
        constraint sync_keys_kdf_known check (kdf = 'PBKDF2-HMAC-SHA256'),

    -- Base64 of 16 random bytes: ceil(16/3) * 4 = 24 characters.
    salt text not null
        constraint sync_keys_salt_length check (length(salt) = 24),

    -- OWASP's current floor for PBKDF2-HMAC-SHA256, mirroring
    -- VidaKeyEscrow.defaultIterations. The floor is here so a client bug can
    -- never quietly write a weak record: this passphrase is the only thing
    -- between stored ciphertext and someone's symptom history, and there is
    -- no server in the loop to rate-limit an offline guessing run.
    --
    -- Lowering the app's default requires a migration, deliberately.
    iterations integer not null
        constraint sync_keys_iterations_floor check (iterations >= 600000),

    -- Base64 of nonce(12) || ciphertext(32) || tag(16) = 60 bytes, which is
    -- exactly 80 base64 characters with no padding. Pinned to the exact length
    -- because anything else is not a sealed 256-bit key.
    wrapped_key text not null
        constraint sync_keys_wrapped_length check (length(wrapped_key) = 80),

    updated_at timestamptz not null default now()
);

comment on table public.sync_keys is
    'Passphrase-wrapped copy of each member''s sync key, so the website can '
    'derive it with WebCrypto. Unreadable without the passphrase, which never '
    'leaves the device.';

alter table public.sync_keys enable row level security;

-- Explicit, because this table is the one artefact capable of unlocking
-- everything else: no anonymous access at all, under any circumstances.
revoke all on public.sync_keys from anon;
grant select, insert, update, delete on public.sync_keys to authenticated;

drop policy if exists "Users read own sync_key" on public.sync_keys;
drop policy if exists "Users insert own sync_key" on public.sync_keys;
drop policy if exists "Users update own sync_key" on public.sync_keys;
drop policy if exists "Users delete own sync_key" on public.sync_keys;

create policy "Users read own sync_key" on public.sync_keys
for select to authenticated using ((select auth.uid())::text = user_id);

create policy "Users insert own sync_key" on public.sync_keys
for insert to authenticated with check ((select auth.uid())::text = user_id);

-- Update as well as insert: the app upserts on conflict (user_id) when the
-- passphrase is changed, which needs both.
create policy "Users update own sync_key" on public.sync_keys
for update to authenticated
using ((select auth.uid())::text = user_id)
with check ((select auth.uid())::text = user_id);

create policy "Users delete own sync_key" on public.sync_keys
for delete to authenticated using ((select auth.uid())::text = user_id);
