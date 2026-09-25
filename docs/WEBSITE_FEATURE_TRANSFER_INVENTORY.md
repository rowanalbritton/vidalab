# VIDA LAB website handoff — Supabase-only feature inventory

Source reviewed: `vidalabwebsite.zip` supplied on 2026-09-22.  This is a
feature inventory and migration boundary, not executable application code.

## Non-negotiable boundary

The iOS app must use **only** the VIDA LAB Supabase project:

- Supabase Auth is the one account system. The iOS app and website must use
  the same `auth.users.id` / JWT, then read the corresponding `profiles` row.
- User data belongs in Supabase tables protected by RLS. The mobile app uses
  the anonymous/public client key and the signed-in member's JWT only.
- Server-only work belongs in Supabase Edge Functions, database functions, or
  scheduled Supabase jobs. Service-role credentials and third-party secrets
  never ship in the app.
- No `base44` package, API URL, entity client, auth token, or function call is
  permitted in iOS. Existing Base44 source is historical behavior to port,
  never a runtime dependency.

## What the handoff contains

The web archive is a **hybrid migration snapshot**, not a completed Supabase
website. It includes a Supabase client and `src/lib/supabase` entity wrapper,
but `DailySignals.jsx`, `AuthContext.jsx`, and many other components still
call Base44. Those are outstanding web migration tasks.

### Shared account and data contracts

| Feature | Current Supabase destination | Required parity rule |
|---|---|---|
| Accounts and profile | `auth.users`, `profiles` | One Supabase identity on web and iOS; profile data is read from `profiles`, never a Base44 user object. |
| Membership | `entitlements`, `profiles.membership` | RevenueCat/webhook is the authority; clients only read entitlement state. |
| Web-style daily check-ins | `daily_checkins` | Preserve the existing row fields and historical records. Add an idempotency key before retry-capable clients write. |
| Encrypted iOS daily logs | `check_ins` | Preserve existing encrypted rows and the iOS key-escrow model. A website cannot read or write the ciphertext without the member's unlocked escrow key. |
| Favorites | `favorites` / encrypted `saved_articles` | Do not merge plaintext web favorites into encrypted iOS records without an agreed encrypted compatibility contract. |
| Experiments, treatments, appointments | Existing user-owned Supabase tables | Each table needs authenticated RLS and the same user UUID. |
| Community | `community_posts`, `community_replies`, `community_flags` | Keep moderated-content restrictions and RLS. |
| AI consent and Ask Vida | `ai_processing_consents`, `ask-vida` Edge Function | Preserve guardrails and cited-answer behavior; never put an AI provider key in iOS. |

### Website features found in the archive

- Daily Signals: full check-in, micro check-in, trends/charts, monthly report,
  practice correlation, Vida Rewind, reminders, exports, Google Calendar,
  Google Sheets and Drive.
- Health content: Library, resource/article types, saved content, research,
  explainers, disease reports, newsletters, Body Weather and Pattern Map.
- Care tools: treatment log, experiments and adherence, doctor finder,
  appointment concierge, doctor preparation, calendar/contact sync.
- Community: posts, replies, flags, moderation concepts.
- Account and commerce: email/password and OAuth flows, profile onboarding,
  membership purchase/status, account deletion, notifications.
- Server workflows: AI chat/guardrails, results/forecast generation,
  reminder and newsletter jobs, payments, Google integrations, exports and
  social/email integrations.

## Base44 function port map

The following Base44 implementations were found. Each needs a separate,
reviewable Supabase replacement before it can be used by either client.

| Historical Base44 function | Supabase-only replacement |
|---|---|
| `mobile-checkin`, `mobile-dashboard`, `mobile-favorite-toggle` | Direct RLS-protected table access where sufficient; otherwise authenticated Edge Functions. |
| `vida-chat-gate`, `vida-chat-send` | Authenticated `ask-vida` Edge Function(s) with the existing health guardrails and server secrets. |
| `appointment-concierge`, `body-weather-forecast`, `experiment-results` | Authenticated Edge Functions with a provider key stored as a Supabase secret. |
| `vida-differential` | Do not port as user-facing diagnosis logic. Preserve the app's non-diagnostic safety boundary. |
| `create-checkout`, `check-payment-status`, `payments-webhook` | RevenueCat/payment Edge Function plus webhook verification; update entitlements server-side. |
| `send-reminders`, appointment reminders/snapshot, newsletter, Instagram | Scheduled Supabase jobs/Edge Functions and the chosen provider APIs; no client-side secrets. |
| `newsletter-signup`, `unsubscribe`, `flag-community-content` | RLS tables plus narrow authenticated/server Edge Functions. |
| Google Calendar/Sheets/Drive functions | Edge Functions using per-user OAuth grants stored server-side. |

## Implementation order

1. Finish the website's Supabase Auth conversion so it uses the same Supabase
   project and profile rows as iOS.
2. Establish one explicit shared check-in contract. Do **not** overwrite or
   reinterpret existing encrypted `check_ins` data. The existing draft
   `supabase/migrations/DRAFT_ios_shared_checkin_sync.sql` is intentionally
   not production-ready because browser decryption and conflict semantics
   still require agreement.
3. Convert web entity calls from Base44 to the supplied Supabase wrappers,
   table-by-table, verifying RLS with two test accounts.
4. Port server functions in priority order to Edge Functions and configure
   secrets only in Supabase.
5. Retire Base44 only after all clients use Supabase, historical data is
   verified, and no web deployment contains Base44 imports or configuration.

## Inclusive content behavior

Content ranking uses voluntary interests, selected conditions, symptoms, and
goals—not a gender-derived inference. General content stays visible to all.
Women’s- and men’s-health material can be prioritized when a member chooses
those interests, while nonbinary, undisclosed, and incomplete profiles receive
a balanced general feed. Search and the complete Library remain available.

