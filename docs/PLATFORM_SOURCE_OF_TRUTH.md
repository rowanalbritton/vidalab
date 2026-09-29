# VIDA LAB — Platform Source of Truth

Updated: 2026-09-18

This repository is the canonical technical source for VIDA LAB across GitHub, Base44, Rork, Supabase, RevenueCat, and the iOS app. Product changes should be reflected here first.

## Brand and purpose

**Name:** VIDA LAB  
**Canonical domain:** `https://vidalab.co`  
**Tagline:** Patterns worth noticing.  
**Primary web message:** Real stories. Clear science. Better questions.  
**Positioning:** VIDA LAB makes complicated health research easier to understand and gives people calm, private tools to notice patterns in their own health story.

VIDA LAB has two connected surfaces:
1. **VIDA LAB Web:** public educational content about emerging medicine, diagnostics, biomedical technology, chronic illness, pain, women's health, migraine, autoimmune disease, Long COVID, POTS, fibromyalgia and related topics.
2. **VIDA LAB App (iOS):** private wellness reflection: daily check-ins, personal pattern mapping, Ask Vida, experiments, Doctor Prep, Library and weekly reports.

VIDA LAB is educational/wellness software. It does not diagnose, treat, prescribe, or replace medical care. Editorial content must distinguish established care from experimental research and should cite primary or authoritative sources.

## Design system

Canonical palette lives in `ios-vida-signals/VIDALAB/Utilities/VidaTheme.swift` as adaptive tokens (`cream`, `paper`, `shell`, `forest`, `onForest`, `moss`, `sage`, `sky`, `skyDeep`, `blush`, `ink`, `inkSoft`, `taupe`, `hairline`). **Forest** (dark green) is the default look in the app, and **Daylight** (cream) is the alternative in Settings > Appearance. The website keeps the cream palette (Cream `#F7F2E9`, Paper `#FEFCF7`, Forest `#1E3A2B`, Moss `#3C6B4F`, Sage `#A3B3A3`, Taupe `#756A59`, Ink `#243029`, Ink soft `#5A655E`, Hairline `#D3CBBD`). Type in the app is Geist, with Newsreader italic for accent words.

Visual direction: warm paper, botanical forest, editorial serif headlines, restrained sans-serif UI, flat cards, hairline borders, no glossy gradients, no alarmist health imagery.

## Repository map / ownership

- `ios-vida-signals/` — canonical native iOS product; Rork may work on this surface.
- The public website (`vidalab.co`) moved off Netlify onto Base44 on 2026-09-18, which now owns the live build and DNS for the domain. The former `site/` directory and `netlify.toml` were removed from this repository the same day — there is no local source tree for the website anymore; Base44 is building its content directly.
- `website/` — archived/reference prototype for the pre-Base44 redesign; do not deploy it separately.
- `supabase/` + `backend/` — canonical backend schema/types and migrations.
- Contact address: `rowan@vidalab.co`, everywhere — app, site, Privacy Policy, Terms, and the App Store listing. One address that actually receives mail beats three that merely look tidy; App Review tests them.
- Privacy Policy and Terms of Use content: formerly canonicalized in this repo (removed 2026-09-18 along with `site/`), published at `/privacy` and `/terms`. Base44 is now the source of truth for these pages — confirm with whoever operates the Base44 project that they resolve at those exact paths (the iOS app and App Store Connect both hardcode them).
- `rork.json` — Rork project map.
- `docs/PLATFORM_SOURCE_OF_TRUTH.md` — cross-platform product contract (this file).

## iOS product contract

Tabs (six): Today, Patterns, Ask, Community, Lab (Experiments, Doctor Prep, Treatments), Library (My Library, Research Library). The Vida menu (orbit mark, top left) holds everything else: Diary, Weekly report, Share card, Appointment Concierge, Settings. **An account is required** (updated 2026-09-29): sign in with Apple, Google, or email with a 16+ date-of-birth check. The signed-in journal is encrypted on the device and backed up to Supabase. HealthKit is read-only. Manual entries win over imported data.

Personal pattern language must say correlations/signals/patterns "worth noticing," not causes or diagnoses. Ask Vida must remain grounded in logged history and retain safety/urgent-care guardrails.

## Privacy contract

Sensitive entry content is encrypted on-device with AES-GCM before remote upload. The data key remains client-side/iCloud Keychain; the server must not receive a plaintext health-entry key. Supabase stores ciphertext plus minimal routing/sync metadata. Meal entries are health data and follow the same rule — the `meals` table is ciphertext only. Saved article references are potentially health-revealing. Do not add plaintext symptom, diagnosis, note, meal, experiment, or Doctor Prep content to analytics, logs, forms, Netlify functions, or Supabase tables without an explicit architecture/privacy review.

The one permitted exception is `sync_keys`, which holds the data key *wrapped* under a passphrase-derived key so the website can open the ciphertext. That is not a plaintext key: the passphrase never leaves the device and the server cannot derive it. Any other route to a readable key is a breach of this contract.

Shared tables are the deliberate opposite and must not be confused with the above. `community_posts` and `community_replies` cannot be end-to-end encrypted, because other members have to read them — a key handed to everyone is not encryption. They are protected by the schema instead: the select grant omits `author_id`, so a client cannot deanonymise a post. Never `select *` on those tables, and never add `author_id` to the grant.

## Supabase contract

Supabase project reference configured in `.mcp.json`: `lhorsiwwnqzkvunuazry`.

Current public tables represented by generated `backend/types.ts`: `profiles`, `check_ins`, `experiments`, `doctor_preps`, `saved_articles`, `entitlements`, `entitlement_log`.

Schema changes must be made through migrations and then regenerate `backend/types.ts`. RLS/auth assumptions must stay aligned with the iOS sync implementation. Never commit service-role keys, RevenueCat secrets, Apple private keys, or user data.

## RevenueCat / membership contract

VIDA+ is the premium tier. Current product identifiers documented by the app are `vida_plus_monthly`, `vida_plus_yearly`, `vida_plus_family`. Entitlement checks must fail safely and should not silently downgrade a user because of a transient network/provider failure.

## Website / Base44 contract

`https://vidalab.co` is the canonical public website domain. `www.vidalab.co` should redirect to the apex domain. All production canonical tags, app links, privacy links, terms links, and public references should use `https://vidalab.co`.

As of 2026-09-18, DNS for `vidalab.co` points at Base44 (previously Netlify), and Base44 owns the live build of the site. `/privacy`, `/terms`, and `/support` must remain stable public URLs because the iOS app and the App Store Connect listing both hardcode them — verify they still resolve correctly any time hosting or DNS changes. The website is a public education/discovery layer and should not collect health/symptom data.

Primary website journeys: discover an article/topic → understand the evidence → subscribe → discover/download the app. Newsletter forms should collect email only, not health details.

## Editorial taxonomy

Core channels: Emerging Medicine; Women's Health; Neurology & Migraine; Autoimmune Disease; Chronic Illness; Diagnostics; Digital Health; Biomedical Engineering. Every research article should make clear: what changed; what the evidence actually shows; what is available now; what remains experimental; what is unknown; sources.

## Cross-platform change checklist

Before shipping a change, ask whether it affects: product name/copy, feature names, URLs, privacy model, database schema, membership/product IDs, legal language, app-to-web links, or brand tokens. If yes, update this document and every affected surface in the same change set.
