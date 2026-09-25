# Supabase-only web-to-iOS parity roadmap

This is the implementation inventory for the supplied website handoff. It
preserves the existing iOS design: items are added only to an existing iOS
screen, and no historical Base44 code or credential is copied into iOS.

## Core account and health-data parity

| Capability | iOS source status | Website handoff status | Required Supabase work |
|---|---|---|---|
| Email/password auth, reset, account deletion | Present | Hybrid / Base44 still present | Convert website AuthContext and all auth pages to Supabase Auth + `profiles`. |
| Profile, interests, gender/cycle preferences | Local iOS profile exists | Uses Base44 user fields | Define explicit field mapping and conflict timestamps; sync only voluntary interests, never infer health interests from gender. |
| Encrypted check-ins | Present in `check_ins` | Website uses plaintext `daily_checkins` | Deploy/test encrypted per-reading event protocol, then implement client-side WebCrypto escrow access. |
| Local offline persistence | Present | Browser behavior not verified | Keep local queues/tombstones and retry protocol in both clients. |
| Favorites | Encrypted `saved_articles` | Plaintext `favorites` wrapper | Decide one encrypted shared contract before merging; do not copy sensitive favorites into a plaintext table. |
| Membership | RevenueCat/StoreKit + entitlement mirror | Historical Base44/Wix flow | Make RevenueCat/Supabase entitlement records the shared authority. |

## Existing iOS feature surface

| Existing iOS screen | Confirmed behavior | Website feature additions that fit without a redesign |
|---|---|---|
| Today / check-in flow | Morning/evening signals, charts, meals, weekly report, Lab Notes | Sync status, check-in calendar action, reminder preference once backend contract is live. |
| Patterns | Local correlations and pattern details | Web Pattern Map parity; no diagnosis/differential output. |
| Ask | Curated safety guardrails and `ask-vida` function | Keep server AI provider key in Edge Functions; carry over only safe/cited behavior. |
| Community | Posts, replies, flags | Supabase RLS/realtime verification; no Base44 entity client. |
| Lab | Experiments, treatments, doctor prep | Experiment results Edge Function, appointments only if existing Lab/Doctor Prep can host them. |
| Library | Articles, search, saved entries, inclusive ranking | Supabase-backed content/feed and voluntary-interest ranking. |
| Settings | Account, privacy, web access, appearance, consent | Reminder preferences and minimal Supabase status controls. |

## Historical server functions

| Historical function | Supabase destination | External prerequisite |
|---|---|---|
| `mobile-checkin`, `mobile-dashboard`, `mobile-favorite-toggle` | RLS table access or authenticated Edge Function | Shared encrypted check-in/favorite contracts. |
| `vida-chat-gate`, `vida-chat-send` | `ask-vida` Edge Function(s) | AI provider secret and existing guardrails. |
| `appointment-concierge`, `body-weather-forecast`, `experiment-results` | Authenticated Edge Functions | AI provider choice, safety prompt review, provider secret. |
| `vida-differential` | Do not expose as diagnostic functionality | Explicit safe-product decision required. |
| `create-checkout`, `check-payment-status`, `payments-webhook` | RevenueCat/payment Edge Functions | Payment/provider configuration and webhook secret. |
| `send-reminders`, appointment reminders/snapshot | Supabase Cron + Edge Functions | Push/email provider, permission copy, scheduling policy. |
| newsletter, unsubscribe, Instagram workflows | Edge Functions/Cron | Email/Instagram provider credentials and product ownership decision. |
| Google Sheets/Drive/Calendar/Tasks/Contacts | Edge Functions | OAuth client, redirect URL, selected scopes, per-user token storage. |
| community flag, newsletter signup | RLS tables + narrow Edge Functions | Existing moderation/email policies. |

## Delivery order

1. **Core contract:** shared Supabase Auth/profile mapping and encrypted check-in sync.
2. **Content:** Supabase Library/content data and inclusive voluntary-interest ranking.
3. **Care tools:** experiments, treatment, doctor prep, and appointment data parity.
4. **Integrations:** Google and exports only after OAuth scopes/secrets are confirmed.
5. **Commerce/workflows:** RevenueCat/payment, reminder, email, and scheduled jobs.
6. **Verification:** synthetic two-account tests, production-safe migration review, root Xcode build, simulator/device tests.

## Rules retained throughout

- No Base44 network request, token, credential, SDK, or proxy in iOS.
- No service-role/Supabase secret in a client app or browser.
- Existing production data is never reset or overwritten wholesale.
- Gender does not infer anatomy, diagnoses, or content interests. General content
  stays available to all; voluntary choices improve ranking only.
- All UI work stays additive inside existing screens; no redesign or new
  navigation structure.
