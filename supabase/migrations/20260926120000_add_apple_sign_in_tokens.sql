-- Apple refresh tokens, kept only so account deletion can revoke them.
--
-- App Review Guideline 5.1.1(v): an app offering Sign in with Apple must
-- revoke the member's Apple tokens when they delete their account. Revoking
-- needs a token Apple issued to this app, which the app can only get by
-- exchanging the one-time authorization code from sign-in. The
-- apple-token-exchange function stores the result here; delete-account reads
-- it, revokes it with Apple, and then removes the row.
--
-- Service role only. No policies, and no grants to anon or authenticated, so
-- a member's own session can't read the token back.

create table if not exists public.apple_sign_in_tokens (
    user_id uuid primary key references auth.users (id) on delete cascade,
    refresh_token text not null,
    updated_at timestamptz not null default now()
);

alter table public.apple_sign_in_tokens enable row level security;

revoke all on table public.apple_sign_in_tokens from anon, authenticated;
