# VIDA LAB — Platform Source of Truth

Updated: 2026-09-17

This repository is the canonical technical source for VIDA LAB across GitHub, Netlify, Rork, Supabase, RevenueCat, and the iOS app. Product changes should be reflected here first.

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

Canonical palette mirrors `ios-vida-signals/VIDALAB/Utilities/VidaTheme.swift`: Cream `#F7F2E9`, Paper `#FEFCF7`, Forest `#1E3A2B`, Moss `#3C6B4F`, Sage `#A3B3A3`, Taupe `#756A59`, Ink `#243029`, Ink soft `#5A655E`, Hairline `#D3CBBD`.

Visual direction: warm paper, botanical forest, editorial serif headlines, restrained sans-serif UI, flat cards, hairline borders, no glossy gradients, no alarmist health imagery.

## Repository map / ownership

- `ios-vida-signals/` — canonical native iOS product; Rork may work on this surface.
- `site/` — canonical production public website; Netlify publishes this directory. The September 2026 web redesign has been merged here.
- `website/` — archived/reference prototype for the redesign; do not deploy it separately.
- `supabase/` + `backend/` — canonical backend schema/types and migrations.
- `site/legal/` — the single canonical source for the Privacy Policy and Terms of Use, published at `/privacy` and `/terms`. There must be exactly one copy of each document: duplicates drift, and a legal page that contradicts another is worse than no page. The former `legal/` directory and `/privacypolicy` page were folded into these; `/privacypolicy` now 301s to `/privacy`.
- `netlify.toml` — Netlify deployment contract.
- `rork.json` — Rork project map.
- `docs/PLATFORM_SOURCE_OF_TRUTH.md` — cross-platform product contract (this file).

## iOS product contract

Tabs/features: Today, Patterns, Ask, Lab (Experiments + Doctor Prep), Library, Weekly Reports, Settings. Account is optional; local use must continue without sign-in. Apple sign-in enables optional encrypted Supabase backup. HealthKit is read-only. Manual entries win over imported data.

Personal pattern language must say correlations/signals/patterns "worth noticing," not causes or diagnoses. Ask Vida must remain grounded in logged history and retain safety/urgent-care guardrails.

## Privacy contract

Sensitive entry content is encrypted on-device with AES-GCM before remote upload. The data key remains client-side/iCloud Keychain; the server must not receive a plaintext health-entry key. Supabase stores ciphertext plus minimal routing/sync metadata. Saved article references are potentially health-revealing. Do not add plaintext symptom, diagnosis, note, experiment, or Doctor Prep content to analytics, logs, forms, Netlify functions, or Supabase tables without an explicit architecture/privacy review.

## Supabase contract

Supabase project reference configured in `.mcp.json`: `lhorsiwwnqzkvunuazry`.

Current public tables represented by generated `backend/types.ts`: `profiles`, `check_ins`, `experiments`, `doctor_preps`, `saved_articles`, `entitlements`, `entitlement_log`.

Schema changes must be made through migrations and then regenerate `backend/types.ts`. RLS/auth assumptions must stay aligned with the iOS sync implementation. Never commit service-role keys, RevenueCat secrets, Apple private keys, or user data.

## RevenueCat / membership contract

VIDA+ is the premium tier. Current product identifiers documented by the app are `vida_plus_monthly`, `vida_plus_yearly`, `vida_plus_family`. Entitlement checks must fail safely and should not silently downgrade a user because of a transient network/provider failure.

## Website / Netlify contract

`https://vidalab.co` is the canonical public website domain. `www.vidalab.co` should redirect to the apex domain. All production canonical tags, app links, privacy links, terms links, and public references should use `https://vidalab.co`.

Netlify deploys from repository root using `netlify.toml`, with production publish directory `site`. `/privacy` and `/terms` must remain stable public URLs because the iOS app links to them. The website is a public education/discovery layer and should not collect health/symptom data.

Primary website journeys: discover an article/topic → understand the evidence → subscribe → discover/download the app. Newsletter forms should collect email only, not health details.

## Editorial taxonomy

Core channels: Emerging Medicine; Women's Health; Neurology & Migraine; Autoimmune Disease; Chronic Illness; Diagnostics; Digital Health; Biomedical Engineering. Every research article should make clear: what changed; what the evidence actually shows; what is available now; what remains experimental; what is unknown; sources.

## Cross-platform change checklist

Before shipping a change, ask whether it affects: product name/copy, feature names, URLs, privacy model, database schema, membership/product IDs, legal language, app-to-web links, or brand tokens. If yes, update this document and every affected surface in the same change set.
