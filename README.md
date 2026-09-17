# VIDA LAB

Patterns worth noticing — a calm, private companion for living with chronic illness.

VIDA LAB is not a period tracker and not a diagnosis tool. It's a place to log how you actually feel, see patterns over time, and walk into appointments with your month in hand.

## What it does

| Tab | Purpose |
| --- | --- |
| **Today** | Quick daily check-ins — symptoms, energy, sleep, notes. Optional Apple Health read-only import fills in what you'd rather not type. |
| **Patterns** | A personal pattern map built on-device. Vida surfaces *correlations worth noticing* — never causes, never diagnoses. |
| **Ask** | Ask Vida questions about your logged history. Answers are drawn from your own entries, cite them, and refuse cleanly outside what the data supports. Emergency keywords always break through to crisis resources first. |
| **Lab** | Two tools: **Experiments** (try one change at a time, track what happens) and **Doctor Prep** (generate a plain-language summary of your last 12 weeks to bring to an appointment). |
| **Library** | Curated, science-referenced reading on symptom categories, plus saved articles. |

Weekly Reports turn a week of check-ins into something readable — exportable as a PDF-style report via Mail.

## Privacy by architecture

Symptom data is health data, so VIDA LAB treats it that way:

- **Client-side encryption.** Every check-in, experiment, and doctor prep is encrypted on-device with AES-GCM *before* it leaves the phone. The key lives in your iCloud Keychain — VIDA LAB's servers never receive it and mathematically cannot read your entries.
- **What's uploaded:** ciphertext, the entry date, and your user ID. That's all.
- **The trade-off, stated honestly:** if you lose your device *and* your iCloud Keychain, your encrypted backup is unrecoverable — by you, and by us. There is no master key and no reset link.
- **Apple Health is read-only** (`toShare: []`) — data flows in, never out.
- Deleting your account deletes remote rows and destroys the encryption key, making any remaining ciphertext permanently unreadable.

## Sync & accounts

- **An account is optional.** Everything works fully on-device with no sign-in.
- Signing in (Apple, via Rork Auth) enables silent encrypted backup to Supabase. Sync is additive and conflict-tolerant: local entries always win, retries are idempotent, and a failed sync never interrupts logging.
- Restoring on a new device pulls your encrypted backup down and decrypts it locally before your first push.

## Membership

VIDA LAB is freemium, powered by RevenueCat with App Store in-app purchases:

- **Free** — 30-day history, 3 insights, 5 questions a day, 2 experiments, 1 Doctor Prep, 1 report week.
- **Vida+** — full 12-week archive and unlimited tools, with monthly / yearly / family plans.

Report *viewing* is never paywalled. If an entitlement check fails, the app keeps your last known tier — never a silent downgrade.

## Tech stack

- **SwiftUI** (iOS 18+), MVVM, `@Observable` state
- **HealthKit** — read-only import (sleep, symptoms, activity)
- **RevenueCat** (`purchases-ios-spm`) — StoreKit 2 subscriptions
- **Supabase** — Postgres + RLS-backed storage for encrypted backups (RLS keys off the Rork Auth JWT `sub`, not `auth.uid()`)
- **CryptoKit** — AES-GCM sealing, HMAC-SHA256 per-user article references
- **Keychain** (iCloud-synchronizable) — encryption key + auth tokens

### Project layout

```
VIDALAB/
├── ContentView.swift      # Root tabs, app-level lifecycle (sync, entitlement, health refresh)
├── Models/                # VidaStore (single source of truth), PatternEngine, guardrails, libraries
├── Views/                 # One view per screen; data reached via @Environment(VidaStore.self)
├── Services/              # Auth, HealthKit, RevenueCat, Supabase, AES-GCM crypto, sync engine
└── Utilities/             # Theme (cream/forest palette) and links
```

Persistence is deliberately simple: the entire local state lives in one `Codable` snapshot (`vida.snapshot.v1`), with auth tokens and the sync key in the Keychain.

## Development

```bash
open VIDALAB.xcodeproj   # Xcode 16+, iOS 18+ SDK
```

- Debug builds talk to the RevenueCat **sandbox/test store**; release builds use App Store credentials (selected automatically at compile time).
- Sync only activates for signed-in users and fails silently by design — check Settings for sync status.
- Product IDs must match between RevenueCat and App Store Connect exactly: `vida_plus_monthly`, `vida_plus_yearly`, `vida_plus_family`.

## Legal

- [Privacy Policy](legal/privacy.html) — includes a plain-language explanation of the encrypted backup model and its limits.
- [Terms of Service](legal/terms.html) — see §4, "Your data, and the limits of recovery."

This app supports wellness reflection. It does not diagnose, treat, or replace medical care — if something feels urgent, contact a clinician.
