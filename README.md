<div align="center">

# VIDA LAB

**Patterns worth noticing.**

A calm, private companion for living with chronic illness.
Not a period tracker. Not a diagnosis tool. Just you, your data, and what it's trying to tell you.

*[App Store badge placeholder — add after release]*

</div>

---

## Why VIDA LAB exists

Chronic illness appointments start the same way: *"How have you been since last time?"* — and your brain blanks. VIDA LAB fixes that.

- **Log how you actually feel** in under a minute a day — symptoms, energy, sleep, notes. Apple Health quietly fills in the rest.
- **See patterns, not noise.** A personal pattern map built entirely on-device surfaces *correlations worth noticing* — never causes, never diagnoses.
- **Walk in prepared.** Doctor Prep turns your last 12 weeks into a plain-language summary you can hand over at the appointment.
- **Your symptoms stay yours.** Every entry is encrypted on your phone before it leaves it. We can't read them. No one can.

> *"It's not a medical record. It's the story of your month, in your words."*

### The privacy difference, in one paragraph

Symptom data is health data, so VIDA LAB treats it that way: entries are sealed with AES-GCM **on-device** before upload, and the key lives in your iCloud Keychain — our servers store ciphertext, a date, and your user ID. **Nothing else.** We never receive the key, so we mathematically cannot read your entries — and we say the quiet part out loud in our [privacy policy](site/legal/privacy.html): if you lose your device *and* your iCloud Keychain, that backup is unrecoverable by anyone, including us. There is no master key and no reset link.

---

## What it does

| Tab | Purpose |
| --- | --- |
| **Today** | Quick daily check-ins — symptoms, energy, sleep, notes. Optional Apple Health read-only import fills in what you'd rather not type. |
| **Patterns** | A personal pattern map built on-device. Vida surfaces *correlations worth noticing* — never causes, never diagnoses. |
| **Ask** | Ask Vida questions about your logged history. Answers are drawn from your own entries, cite them, and refuse cleanly outside what the data supports. Emergency keywords always break through to crisis resources first. |
| **Lab** | Two tools: **Experiments** (try one change at a time, track what happens) and **Doctor Prep** (a plain-language 12-week summary for appointments). |
| **Library** | Curated, science-referenced reading on symptom categories, plus saved articles. |

Weekly Reports turn a week of check-ins into something readable — exportable via Mail.

<!-- Screenshots: add 3–6 framed iPhone screenshots here after TestFlight.
Suggested set: 1) Today check-in, 2) Pattern map, 3) Doctor Prep summary, 4) Ask Vida answer with citations.
Use a table of <img> tags at ~250px width each for even spacing. -->

| | | |
|:---:|:---:|:---:|
| *Screenshot: Today* | *Screenshot: Patterns* | *Screenshot: Doctor Prep* |

### Membership

| | Free | Vida+ |
| --- | --- | --- |
| History | 30 days | Full 12-week archive |
| Insights | 3 | Unlimited |
| Ask Vida | 5 questions/day | Unlimited |
| Experiments & Doctor Prep | Limited | Unlimited |

Powered by RevenueCat with native App Store subscriptions (monthly, yearly, and family plans). Report *viewing* is never paywalled, and if an entitlement check fails, the app keeps your last known tier — never a silent downgrade.

### Sync & accounts

- **A Supabase account protects access to the app.** Email/password sessions persist securely and refresh automatically.
- Signing in enables silent encrypted backup to Supabase — additive, conflict-tolerant, and never blocking: local entries always win, retries are idempotent, and a failed sync never interrupts logging.
- Restoring on a new device pulls your encrypted backup down and decrypts it locally before your first push.
- Deleting your account deletes remote rows and destroys the encryption key, making any remaining ciphertext permanently unreadable.

---

## Under the hood

For the engineers:

- **SwiftUI** (iOS 18+), MVVM, `@Observable` state, adaptive cream/forest design system in `Utilities/VidaTheme.swift`
- **HealthKit** — read-only import (`toShare: []`); sleep, symptoms, and activity flow in, never out. Manual entries always win over imported data.
- **RevenueCat** (`purchases-ios-spm`) — StoreKit 2 subscriptions behind a `MembershipService` protocol seam, so the provider is swappable and testable. Debug builds hit the sandbox/test store; release builds use App Store credentials automatically.
- **Supabase** — native Auth plus Postgres row-level security for encrypted backups. Every policy binds rows to the signed-in user's `auth.uid()`.
- **CryptoKit** — AES-GCM sealing per entry, HMAC-SHA256 per-user article references (saved-article IDs are hashed because article titles are health-revealing too).
- **Keychain** — iCloud-synchronizable 256-bit data key plus auth tokens; never UserDefaults.

### Project layout

```
VIDALAB/
├── ContentView.swift      # Root tabs, app-level lifecycle (sync, entitlement, health refresh)
├── Models/                # VidaStore (single source of truth), PatternEngine, guardrails, libraries
├── Views/                 # One view per screen; data reached via @Environment(VidaStore.self)
├── Services/              # Auth, HealthKit, RevenueCat, Supabase, AES-GCM crypto, sync engine
└── Utilities/             # Theme and links
```

Persistence is deliberately simple: the entire local state lives in one `Codable` snapshot (`vida.snapshot.v1`), with auth tokens and the sync key in the Keychain. The sync engine is pull-before-push on first migration, throttled to once per 5 minutes in the foreground, and silent by design.

### Running it in Xcode

Requires **Xcode 16+** (iOS 18 SDK) on macOS.

```bash
cd ios-vida-signals
open VIDALAB.xcodeproj
```

On first open, Xcode resolves two Swift packages over the network — RevenueCat
(`purchases-ios-spm`) and `supabase-swift`. Wait for *Package Resolution* to
finish before building, then pick any iPhone or iPad simulator and run. No
CocoaPods, no `pod install`, no workspace file.

**One required step: create `Config.swift`.** It holds the project's public
credentials, is generated at build time, and is deliberately git-ignored — so a
fresh clone does not contain it and the build fails with
`cannot find 'Config' in scope` until you add it at
`VIDALAB/Config.swift`:

```swift
import Foundation

enum Config {
    static let EXPO_PUBLIC_SUPABASE_URL = ""
    static let EXPO_PUBLIC_SUPABASE_ANON_KEY = ""
    static let EXPO_PUBLIC_REVENUECAT_IOS_API_KEY = ""
    static let EXPO_PUBLIC_REVENUECAT_TEST_API_KEY = ""
}
```

Empty strings compile and run. The app is fully usable signed out, so with no
credentials you get every local feature — check-ins, pattern map, experiments,
Doctor Prep, reports — while accounts and cloud backup report themselves
unavailable instead of hanging or crashing. Fill in the Supabase pair to enable
accounts and encrypted sync; add a RevenueCat key to enable real billing. With
no RevenueCat key the app talks to **StoreKit 2 directly**, which needs App
Store Connect products to show prices.

To run on a physical device, set your team under *Signing & Capabilities* —
`DEVELOPMENT_TEAM` ships empty. The simulator needs no signing. Note that
HealthKit and In-App Purchase both require a paid Apple Developer account, and
Apple Health has no data in the simulator until you add some in the Health app.

### Development notes

- Product IDs must match between RevenueCat and App Store Connect exactly: `vida_plus_monthly`, `vida_plus_yearly`, `vida_plus_family`.
- Sync only activates for signed-in users — check Settings for sync status.
- `Config.swift` is regenerated by the build pipeline; treat any local copy as scratch and keep real secrets out of commits.
- Bundle ID is currently `app.vidalab` and is **permanent once a build reaches App Store Connect** — see `docs/PUBLISH_SEQUENCE.md` Stage 0 before uploading.

---

## Roadmap

- [ ] **App Store release** — final ASC setup, App Privacy questionnaire reflecting the encrypted-sync model
- [x] **RevenueCat webhook** — server-side entitlement writer, deployed (`entitlements` / `entitlement_log`); needs the dashboard URL + secret entry to go live
- [ ] **HealthKit background delivery** — refresh imports without opening the app
- [ ] **Offline sync queue** — queue encrypted uploads when connectivity drops, flush on reconnect
- [ ] **Widgets & Live Activities** — quick log from the Home Screen
- [ ] **iPad layout** — wider pattern map and report views

<!-- Contribution note for when the repo opens up: issues welcome; PRs for small fixes only; all schema changes go through reviewed migrations. -->

---

## Legal

- [Privacy Policy](site/legal/privacy.html) — plain-language explanation of the encrypted backup model and its limits. Published at `vidalab.co/privacy`.
- [Terms of Use](site/legal/terms.html) — see §4, "Your data, and the limits of recovery." Published at `vidalab.co/terms`.

<div align="center">

VIDA LAB supports wellness reflection. It does not diagnose, treat, or replace medical care — if something feels urgent, contact a clinician.

</div>
