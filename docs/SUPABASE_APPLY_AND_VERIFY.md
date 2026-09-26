# Applying the Supabase changes, and proving they worked

Five migrations and three Edge Functions are written but unapplied. This is the
order to put them live in, and how to tell at each step whether it worked.

Run every phase against a **development branch or staging project first**. Phase
6 is the only one that touches production.

---

## Read this before you start

**Migrations must go before functions.** The updated `delete-account` now
deletes from `push_tokens` and `community_blocks`. PostgREST rejects a delete
against a table that does not exist, and that function throws on the first
error, so deploying it before the migrations would leave **account deletion
completely broken** — a 500, nothing deleted, and an App Review 5.1.1(v)
failure. Nothing is gained by deploying functions early; do not.

**We do not know whether the September 22 migrations were already applied.**
`20260922195302_secure_ios_checkin_event_rpc.sql` claims its history "matches
the applied production history", but this checkout has no `supabase/config.toml`
and no `supabase/.temp`, so nothing was ever pushed *from here*. Phase 0 settles
it by looking, rather than trusting the comment. All five migrations are now
idempotent (`if not exists`, `drop policy if exists`, `create or replace`), so
re-running one that already landed is safe.

**The app is already fixed for this.** The iOS dual-write encoder bug is fixed,
so once `ios_checkin_events` exists the push will work. Until it exists, every
sync fails and Settings shows "Backup didn't finish." That is the expected
before-state, not a new bug.

---

## Phase 0 — Find out what production actually has

Read-only. Change nothing.

In the Supabase dashboard → SQL Editor, against **production**:

```sql
-- Which of our tables exist?
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'ios_checkin_events', 'push_tokens', 'community_blocks',
    'community_posts', 'check_ins', 'daily_checkins'
  )
order by table_name;

-- Which of our functions exist?
select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'apply_ios_checkin_event', 'block_community_author',
    'community_block_count', 'unblock_all_community_authors',
    'is_blocked_by_viewer', 'claim_push_token'
  )
order by routine_name;

-- What does Supabase think it has already run?
select version, name
from supabase_migrations.schema_migrations
order by version;
```

Write the three answers down. They decide Phase 2.

Also confirm the column names the app now depends on, because this is where the
recovered source was wrong:

```sql
select column_name
from information_schema.columns
where table_schema = 'public' and table_name = 'community_posts'
order by column_name;
```

You should see `author_id`, `body`, `created_at`. If you instead see `user_id`,
`content`, or `created_date`, **stop** — production disagrees with the migration
and the Swift fixes I made are calibrated to the migration. Tell me which it is.

---

## Phase 1 — Link the CLI

```bash
cd "/Users/rowan/Desktop/vida-lab/vida lab/VIDA_LAB_RECOVERED"
supabase login
supabase link --project-ref <your-project-ref>
```

The ref is in the dashboard URL: `supabase.com/dashboard/project/<ref>`.

Then confirm the CLI's view matches what you just read by hand:

```bash
supabase migration list
```

`Local` and `Remote` columns that disagree are exactly what Phase 2 fixes.

---

## Phase 2 — Reconcile migration history

Only if Phase 0 showed a table or function already exists **but** its version is
missing from `schema_migrations`. That combination means somebody applied SQL
through the dashboard without the CLI, and a plain `db push` would try to run it
again.

Mark the already-applied ones as done, without re-running them:

```bash
supabase migration repair --status applied 20260922195212
supabase migration repair --status applied 20260922195302
supabase migration repair --status applied 20260922195342
```

Only repair the versions Phase 0 proved are really there. Repairing a migration
that did *not* run would skip it permanently — the worst outcome available here,
because everything would look fine until the app hit a missing table.

---

## Phase 3 — Apply to a branch, not production

```bash
supabase branches create shared-checkin-verify   # if you have branching
# or point --project-ref at a separate staging project
supabase db push
```

Expect five versions to apply (or two, if Phase 2 repaired three). Then verify
the shapes rather than assuming:

```sql
-- Tombstones and conflict protection are the point of this table.
select column_name, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'ios_checkin_events'
order by ordinal_position;

-- The unique key is what makes two devices merge instead of duplicating.
select conname, pg_get_constraintdef(oid)
from pg_constraint
where conrelid = 'public.ios_checkin_events'::regclass;
```

You need `unique (user_id, client_id)` present. Without it the `on conflict`
in `apply_ios_checkin_event` has nothing to match and every sync errors.

Then confirm the RPC is **not** reachable by a member, since it takes
`p_user_id` and would otherwise let anyone write into another account:

```sql
select grantee, privilege_type
from information_schema.routine_privileges
where routine_name = 'apply_ios_checkin_event';
```

Expect `service_role` only. If `authenticated` appears, stop and fix it.

Finally, in the dashboard: **Settings → API → exposed schemas** must include
`public`, and the new tables must be visible to the Data API. A table that
exists but is not exposed fails from the client as a confusing 404.

---

## Phase 4 — Secrets, then functions

Secrets first, so no function is ever live without its configuration.

```bash
supabase secrets set \
  APNS_KEY_ID=XXXXXXXXXX \
  APNS_TEAM_ID=YYYYYYYYYY \
  APNS_BUNDLE_ID=app.vidalab \
  APNS_PRIVATE_KEY="$(cat ~/Downloads/AuthKey_XXXXXXXXXX.p8)"
```

`app.vidalab` is the VIDALAB target's real `PRODUCT_BUNDLE_IDENTIFIER`, and APNs
uses it as `apns-topic` — a mismatch here fails every send with
`BadDeviceToken`. `APNS_PRIVATE_KEY` must keep its newlines, which is why it is
quoted with `$(cat ...)` rather than pasted.

`SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are injected
automatically — do not set them.

```bash
supabase functions deploy sync-checkin-event
supabase functions deploy delete-account
supabase functions deploy send-push
```

`ask-vida` is live in production but **is not in this repo**. Do not redeploy
functions with a bare `supabase functions deploy` (no name), because that
deploys only what is on disk and could disturb it. Export it when you can:

```bash
supabase functions download ask-vida
```

---

## Phase 5 — Verify

### Automated, first

```bash
cd "/Users/rowan/Desktop/vida-lab/vida lab/VIDA_LAB_RECOVERED"
xcodebuild -workspace OPEN_VIDA_LAB.xcworkspace -scheme VIDALAB \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test
```

80 tests, 0 failures. These cover the stable event ID, the tombstone queue and
merge ordering, the community column names, and the RPC parameter names — the
four things that were actually broken.

### The sync cases

Run `SHARED_CHECKIN_SYNC_TEST_PLAN.md` in full, with synthetic accounts and
fictional entries. Case 5 (deletion tombstone) is newly implemented and has
never run against a real server; case 4 (same-reading conflict) exercises the
stale-write rejection. Treat those two as the ones most likely to surprise you.

One addition to that plan, which it predates: confirm the **dual-write actually
lands**. After a check-in on a signed-in device:

```sql
select local_date, period, schema_version, deleted_at is not null as is_tombstone
from public.ios_checkin_events
order by client_updated_at desc
limit 10;
```

Rows should appear with `is_tombstone = false`, and `ciphertext` should be
unreadable base64. If you see no rows, the function rejected the batch — check
the `sync-checkin-event` logs for `Provide 1 to 50 valid check-in events`, which
was the old encoder bug's signature.

### Blocking

As two synthetic accounts, A and B:

1. B posts. A sees it.
2. A blocks it from the post menu. The thread closes and the post is gone from A's list.
3. B still sees their own post. A's own posts are unaffected.
4. Settings shows "1 person blocked" and **no name** — that is deliberate.
5. "Unblock all" restores B's post for A.

Then confirm the list really is unreadable, as account A:

```sql
select * from public.community_blocks;  -- must return permission denied
select public.community_block_count();  -- must return 1
```

### Push

Needs a **real device**; the simulator gets no APNs token.

1. Sign in, Settings → Reminders → "Turn on reminders", accept.
2. `select user_id, environment, enabled from public.push_tokens;` — one row,
   `environment = 'sandbox'` for a debug build.
3. Send one:

```bash
curl -X POST "https://<ref>.supabase.co/functions/v1/send-push" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"userId":"<uuid>","title":"Your evening check-in is open","body":"Two minutes, whenever suits."}'
```

Expect `{"sent":1,"retired":0}`. `sent: 0` with `retired: 1` means the token was
rejected as permanently invalid — almost always a sandbox/production mismatch
between the build and `aps-environment`.

A member JWT in that `Authorization` header must return 401. Check it.

### Account deletion — do this last, it is destructive

On a throwaway account that has a check-in, a community post, a block, and a
push token. Settings → delete account, then confirm every one of these is empty:

```sql
select count(*) from public.ios_checkin_events where user_id = '<uuid>';
select count(*) from public.check_ins         where user_id = '<uuid>';
select count(*) from public.push_tokens       where user_id = '<uuid>';
select count(*) from public.community_posts   where author_id = '<uuid>';
select count(*) from public.community_blocks  where blocker_id = '<uuid>'
                                                 or blocked_author_id = '<uuid>';
select count(*) from auth.users               where id = '<uuid>';
```

All zero. Any non-zero result is the 5.1.1(v) blocker reopening — this is the
exact failure the `author_id` fix addressed, so it is worth confirming rather
than assuming.

### Advisors

Dashboard → Advisors → Security and Performance. Clear anything naming the new
tables. An unindexed foreign key or an RLS-disabled table here is cheap to fix
now and awkward later.

---

## Phase 6 — Production

Only once every case above passed on the branch.

```bash
supabase link --project-ref <production-ref>
supabase migration list        # read it before pushing
supabase db push
supabase secrets set ...       # production APNs values
supabase functions deploy sync-checkin-event
supabase functions deploy delete-account
supabase functions deploy send-push
```

Then, on production, re-run only: one dual-write check, one block, and one
deletion on a synthetic account. Do not re-run the destructive case on real data.

Release note for the App Store build: `aps-environment` must be `production` in
the archived build, or push will silently fail for every real user while working
perfectly in your debug builds.

---

## What stays untouched

- **`check_ins` dual-write continues.** The encrypted whole-day rows remain the
  recovery source until every shipped client reads the event stream. Do not
  remove that write, and do not backfill from it.
- **`daily_checkins` is left alone.** It is the website's plaintext schema. Never
  copy encrypted health data into it; that would hand the server readable
  symptoms and undo the entire privacy model.

## If it goes wrong

Every migration is additive — no drops, no column changes, no data rewrites — so
rollback is undeploying, not restoring. To disable a feature without touching
data:

```sql
-- Stop the app writing events; existing rows and check_ins are untouched.
revoke execute on function public.apply_ios_checkin_event(
    uuid, uuid, date, text, text, text, integer, timestamptz, timestamptz
) from service_role;

-- Stop blocking taking effect, keeping the rows.
drop policy if exists "Read active posts" on public.community_posts;
create policy "Read active posts" on public.community_posts
for select to authenticated using (status = 'active' or public.is_moderator());
```

The app degrades quietly in both cases: sync reports a failure it already knows
how to report, and local storage keeps working, which is the whole reason
`VidaStore` stays the source of truth.

## Sign in with Apple token revocation (added 2026-09-26)

App Review Guideline 5.1.1(v) requires revoking a member's Sign in with Apple tokens when they delete their account. Until the steps below are done, Apple sign-in and account deletion still work; deletion just doesn't revoke Apple's access.

Order matters: apply the migration before deploying the functions.

1. Apply `migrations/20260926120000_add_apple_sign_in_tokens.sql` (creates `apple_sign_in_tokens`, service role only).
2. In the Apple Developer portal, go to Certificates, Identifiers & Profiles > Keys, create a key with **Sign in with Apple** enabled, set its primary App ID to `app.vidalab`, and download the `.p8` file (Apple only lets you download it once).
3. Set the secrets:
   ```
   supabase secrets set APPLE_TEAM_ID=FQF67NVP7H APPLE_KEY_ID=<10-char key id> APPLE_PRIVATE_KEY="$(cat AuthKey_<id>.p8)"
   ```
4. Deploy `apple-token-exchange` and the updated `delete-account`.
5. Verify: sign in with Apple on a device, then check that `apple_sign_in_tokens` has a row for that user. Delete the account in the app. The row should be gone, and the app should no longer be listed under Settings > Apple Account > Sign in with Apple on that device.
