# VIDA LAB — handover to the website migration

Answers to the four questions blocking §5, plus what to do next.

Written against the iOS app as it stands on
`agent-design-cleanup-and-optimization-4096`. The app is **live against the
production Supabase project right now**, so everything below describes a
system already in use, not a greenfield design.

---

## 1. The E2E encryption approach for shared tables

**The short version: the website cannot read the health tables with SQL.**
Four of them hold ciphertext sealed with a key the server has never seen. A
`select * from check_ins` returns base64 and nothing else. If the migration
plan assumes otherwise, that assumption needs to change before Phase 1.

### What is encrypted

| Table | Plaintext columns | Encrypted column |
|---|---|---|
| `check_ins` | `user_id`, `local_date`, `schema_version`, `updated_at` | `ciphertext` |
| `experiments` | `user_id`, `client_id`, `schema_version`, `updated_at` | `ciphertext` |
| `doctor_preps` | `user_id`, `client_id`, `schema_version`, `updated_at` | `ciphertext` |
| `saved_articles` | `user_id`, `article_ref` | `ciphertext` |

`profiles` is **not** encrypted. Neither is `sync_keys` — by design, see below.

Two notes on the plaintext columns. `local_date` means the server knows which
days someone checked in, just not what they said; that was a deliberate
trade so sync can reconcile by day. And `article_ref` is not an article ID —
it is `HMAC-SHA256(article_id)` under the member's own data key, base64url
with padding stripped. Which articles someone saves is itself revealing (a
list of endometriosis titles is a diagnosis in all but name), so the server
can deduplicate without learning what was read. **The website cannot compute
`article_ref` without the data key.**

### The envelope

Every `ciphertext` column is the same:

```
base64( nonce(12 bytes) || ciphertext || GCM tag(16 bytes) )
```

- Cipher: **AES-256-GCM**
- Plaintext: **JSON**, dates encoded **ISO 8601**
- Key: a random **32-byte** value, generated on device, stored in the
  **iCloud Keychain**. The key itself is never transmitted. If the member
  turns on web access, a copy *sealed under a passphrase-derived key* is
  stored in `sync_keys` — see below. The passphrase never leaves the device,
  so the server still holds nothing it can open.

### How the browser gets the key

Only one way: the member sets a passphrase, and the app stores a *wrapped*
copy of the data key in `sync_keys`. The passphrase never leaves the device
and the server cannot derive anything from what it stores.

`sync_keys` columns: `user_id`, `kdf`, `salt`, `iterations`, `wrapped_key`,
`updated_at`.

- `kdf` is always `PBKDF2-HMAC-SHA256` (constrained by a CHECK)
- `salt` is base64 of 16 random bytes
- `iterations` is **600,000** (OWASP floor; a CHECK enforces `>= 600000`)
- `wrapped_key` is base64 `nonce(12) || ciphertext(32) || tag(16)`, sealing
  the raw 32-byte data key

WebCrypto does all of this natively — no library needed:

```js
const enc = new TextEncoder();

// NFC, not NFKC. iOS uses precomposedStringWithCanonicalMapping, which is
// NFC. Get this wrong and accented passphrases silently fail to match.
const material = await crypto.subtle.importKey(
  "raw", enc.encode(passphrase.normalize("NFC")), "PBKDF2", false, ["deriveKey"]
);

const kek = await crypto.subtle.deriveKey(
  { name: "PBKDF2", salt, iterations, hash: "SHA-256" },
  material, { name: "AES-GCM", length: 256 }, false, ["decrypt"]
);

// wrapped = nonce(12) || ciphertext || tag(16)
const dataKey = await crypto.subtle.decrypt(
  { name: "AES-GCM", iv: wrapped.slice(0, 12) }, kek, wrapped.slice(12)
);
```

`dataKey` is then the raw 32 bytes that open every `ciphertext` column, using
the identical `nonce || ciphertext || tag` layout.

### Rules the web side must not break

1. **Never write plaintext into a `ciphertext` column.** The app will throw
   `CryptoError.openFailed` on it, and the row becomes unreadable noise in
   the member's history.
2. **Never write a `sync_keys` row with fewer than 600,000 iterations.** The
   DB rejects it, and the app would refuse it anyway.
3. **A wrong passphrase is indistinguishable from a tampered record.** That's
   the GCM tag failing, and it's the correct amount of information to give.
   Don't add a verifier column to improve the error message.
4. **Web-only accounts have no data key at all.** See the open issue below.

### Two open issues I'd want decided before Phase 2

**Web-first signup.** The data key is created by the app on first use. Someone
who registers on the website and never opens the app has no key and no
`sync_keys` row, so there is nothing to encrypt against and nothing to
decrypt. Either the web must generate a key and write its own escrow record
on signup, or web accounts stay read-only until the app has run once. This
needs a decision; it is not covered by the current design.

**Web writes require the passphrase.** Because encryption needs the data key,
the website can only *write* health rows for a member who has set up escrow
and entered their passphrase in that session. Web check-in entry is therefore
gated on escrow, not just on login. Worth designing for explicitly rather
than discovering during Phase 3.

---

## 2. Is the `sync_keys` migration applied?

**Unknown — I could not verify it, and you should treat it as not applied
until someone checks.**

The Supabase MCP server isn't authorized in my session, so I have no way to
query your project. The migration file exists and is committed:

```
supabase/migrations/20260920120000_add_sync_keys_escrow.sql
```

To check:

```sql
select to_regclass('public.sync_keys');
```

`null` means it hasn't run. To confirm the policies came with it:

```sql
select policyname, cmd from pg_policies where tablename = 'sync_keys';
```

You should see four (`select`, `insert`, `update`, `delete`), all scoped to
`(select auth.uid())::text = user_id`, plus `anon` revoked entirely.

One thing worth fixing while you're in there: **the table-creation DDL for
`profiles`, `check_ins`, `experiments`, `doctor_preps` and `saved_articles`
is not in version control.** The only migrations in the repo manage RLS
policies. Those tables were created out-of-band and are live. Capture them as
a baseline migration before the web side starts adding to the schema.

---

## 3. Does a curated Q&A library already exist?

**Yes, and it should be the source of truth for the website — not rebuilt,
and not replaced by an LLM.**

In the app:

- `Models/AskVidaLibrary.swift` — **17 curated answers**. Each has a question,
  a one-line short answer, 3–4 detail paragraphs, keywords for matching, a
  suggested signal to track, and a link to a backing article.
- `Models/ScienceLibrary.swift` — **24 articles with citations**.
- `Models/AskGuardrails.swift` — the classifier that runs *before* any answer.

Two behaviours the website must reproduce:

**Nothing uncited is ever shown.** `citedMatch(for:)` resolves an answer, then
checks the backing article exists and has citations. If not, the answer is not
produced at all — the app shows "I don't have a researched answer for that
yet" instead. An uncited claim about someone's body is the specific thing this
product exists not to do.

**Three of the four outcomes are refusals.** `AskGuardrails.classify` runs a
ladder: emergency language first (scripted crisis guidance, with separate
wording for mental-health crises), then out-of-scope (diagnosis requests and
medication questions get scripted redirects), then the cited library, then an
honest "no match".

As of today, answers are tagged with a `relevance` field (`anyone`, `female`,
`male`) that narrows what is *suggested* without restricting what search
returns — someone reading up on a partner still gets the real answer. Five
men's answers were added this session.

If you want this content on the web, export it from these files rather than
rewriting it. And please don't put a general LLM in front of health questions:
it would contradict the app's core safety property, and it makes the web the
weakest link in any regulatory conversation.

---

## 4. Does `vida-differential` suggest diagnoses?

**I can't tell you — it doesn't exist on the app side.** `grep -ri differential`
across the whole repository returns nothing. It's a website/Base44 component
I have no visibility into, so this question has to go to whoever wrote it.

What I *can* give you is the rule it has to satisfy, because the app is
absolute about it:

> Vida never names a condition. Not as a suggestion, not as a ranked list, not
> as a "this could be".

`AskGuardrails` refuses on phrases including `"do i have"`, `"could i have"`,
`"might i have"`, `"what's wrong with me"`, `"diagnose"`, `"is it cancer"`,
and returns scripted text: *"Naming a condition takes an examination, usually
tests, and a clinician who can weigh everything together."*

The app's Pattern Map gets as close as the product ever goes, and it only
reports **correlations between the member's own logged signals** — "your
headaches cluster on days after under six hours' sleep". Never a cause, never
a condition.

So: **if `vida-differential` produces anything resembling a differential
diagnosis, it must not ship to users.** Two products under one brand
disagreeing about whether an app can tell you what you have is worse than
either position alone, and it's the kind of thing that attracts regulatory
attention. If it's an internal triage or content-routing tool, that's fine —
but it needs to be clearly not user-facing.

---

## Next steps, in order

1. **Check whether `sync_keys` exists** (§2). Everything about web read access
   depends on it.
2. **Capture the existing tables as a baseline migration.** The live schema is
   not in version control; don't add to it until it is.
3. **Decide the two escrow edge cases** (§1): web-first signup, and whether
   web check-in writing is gated on passphrase entry.
4. **Build web read access on the escrow path**, not on direct table reads.
   Prove it end to end with one member's `check_ins` before building UI on top.
5. **Port the Q&A library and the guardrail ladder** from the app files (§3).
   Same content, same refusals.
6. **Resolve `vida-differential`** (§4) before anything user-facing ships.
7. **Dual-write during cutover.** The app is live on this project; a big-bang
   switch means a window where web writes somewhere the app can't see, and
   encrypted rows can't be reconciled afterwards because you can't read them.

## Auth, for completeness

The app uses `auth.signUp(email:password:)` and
`auth.signIn(email:password:)` against the same `auth.users`, plus
`resetPasswordForEmail`. **Every account needs a password.** A member who
registers via magic link has none and simply cannot sign in on iOS. Magic
link is fine as an additional option; it cannot be the only one.
