# App Store submission answer sheet — VIDA LAB

Everything App Store Connect will ask, with the answer that matches what the app
actually does. Keep this in sync with the code: under-disclosure is the most
common health-app rejection, and the riskiest one legally.

---

## 1. App Privacy (ASC → App Privacy → Data Types)

> ### ⚠️ The live declaration is currently WRONG and will be rejected
>
> App Store Connect currently answers **"Data Not Collected"** for this app.
> That is false, and it is the single most consequential error in the whole
> submission. Signed-in users upload identifiable profile data (email, name,
> user ID) and encrypted check-in content to Supabase on every sync. Apple
> treats encrypted-but-uploaded data as **collected** — encryption governs who
> can *read* it, not whether it was collected.
>
> "Data Not Collected" is also a **binding, exclusive** answer: it asserts that
> nothing at all leaves the device. One upload contradicts it. This is not a
> technicality — a false "Data Not Collected" is the kind of misdeclaration
> that draws a 5.1.1 rejection on the way in and an App Store removal if it
> ships, because the product page would be making a privacy promise the code
> breaks.
>
> **Fix before submitting:** in ASC → App Privacy, switch from "Data Not
> Collected" to "Yes, we collect data" and enter the five types below. They
> must also match `VIDALAB/PrivacyInfo.xcprivacy` in the binary, which already
> declares them correctly — so right now the manifest and the product page
> disagree with each other, and Apple compares the two.
>
> This cannot be fixed from the repo: it is ASC state, not a file. Either set
> it by hand in the ASC UI, or configure API credentials (`asc auth login`) and
> apply it with `asc web privacy pull/plan/apply`.

Declare **four** data types. All are **Linked to You** (they sit against an
account identifier). All are **Not used for tracking** — no ad SDKs, no
analytics SDKs, no data brokers, no cross-app or cross-site profiling. That
answer is true and worth stating plainly on the product page.

### Health & Fitness → Health

- Collected: **Yes**
- Linked to you: **Yes**
- Used for tracking: **No**
- Purpose: **App Functionality**
- Note for the reviewer: entries are encrypted on-device before upload; the
  server holds ciphertext plus the date. Disclosed as collected regardless,
  because it leaves the device and is linked to an account.

### Contact Info → Email Address

- Collected: **Yes**
- Linked to you: **Yes**
- Used for tracking: **No**
- Purpose: **App Functionality** (account creation, sign-in, password reset)

### Identifiers → User ID

- Collected: **Yes**
- Linked to you: **Yes**
- Used for tracking: **No**
- Purpose: **App Functionality** (ties encrypted rows and subscription status
  to the right account)

### Purchases → Purchase History

- Collected: **Yes**
- Linked to you: **Yes**
- Used for tracking: **No**
- Purpose: **App Functionality** (entitlement checks via RevenueCat)

### Do NOT declare

Location, Contacts, Search History, Browsing History, Sensitive Info beyond
health, Diagnostics, Usage Data, Advertising Data — none are collected.

### Health-app specifics

- Apple Health is **read-only** (`requestAuthorization(toShare: [], read:)`).
- HealthKit data is never used for advertising or marketing, and is never sold
  or shared with third parties — required attestations for HealthKit apps.
- Privacy Policy URL is mandatory for HealthKit apps: `https://vidalab.co/privacy`

### Privacy manifest (required since Spring 2024)

`VIDALAB/PrivacyInfo.xcprivacy` ships in the bundle and must stay consistent
with the answers above — Apple compares them, and a mismatch is a rejection.
It declares:

- `NSPrivacyTracking` **false**, with an empty tracking-domains array.
- Five collected types: Health, Email Address, Name, User ID, Purchase History —
  each linked, non-tracking, App Functionality. (The manifest lists Name
  separately; in the ASC questionnaire, Name sits under Contact Info alongside
  Email.)
- One required-reason API: **UserDefaults** with reason **CA92.1** (accessed
  only to read/write this app's own settings). `UserDefaults` is the sole
  required-reason API the app touches — no file-timestamp, disk-space,
  boot-time, or active-keyboard APIs are used.

If a future change adds one of those APIs, or a new SDK, the manifest must be
updated in the same commit.

---

## 2. Age rating: 16+ (decided 2026-09-25)

In the ASC age-rating questionnaire:

- **Medical/Treatment Information** → **Frequent/Intense** (the app is built
  around symptom tracking)
- **Sexual Content or Nudity** → None
- **Profanity or Crude Humor** → None
- **Alcohol, Tobacco, or Drug Use or References** → None
- **Horror/Fear Themes**, **Violence** (all forms), **Gambling**,
  **Contests** → None
- **Unrestricted Web Access** → **No** (outbound links are fixed: our own site,
  Apple's subscription settings)
- **User Generated Content / social features** → **Yes**. The Community tab
  lets members post and reply. Guideline 1.2 requires reporting, blocking, and
  a way to remove objectionable content.
- If App Store Connect's resulting rating is below 16+, use the age-rating
  override to set **16+** so the store matches the account floor.

The in-app floor is **16+**, enforced by a neutral date-of-birth check on
Create account (SignInView). The birth date is not stored; only
`age_confirmed_16_plus` is written to the Supabase user metadata. The Terms and
Privacy Policy on vidalab.co already state 16+, so the rating, the app, and
both legal pages agree.

---

## 3. Account deletion (Guideline 5.1.1(v))

Satisfied in-app: **Settings → Delete account and data**.

The flow deletes the account itself, not just its rows:

1. Server-side `delete-account` function verifies the caller's own session,
   sweeps every table (check-ins, experiments, doctor preps, saved articles,
   entitlements, entitlement log, profile), then deletes the auth user last.
2. The on-device encryption key is destroyed, so any copy that somehow outlives
   the delete is permanently unreadable.
3. Local storage is wiped and the session ends.

If the server step fails, nothing is erased and the user is told so — a
"deleted" account whose data still exists is the one outcome this must never
produce. No email to support is required at any point.

---

## 4. Sign in with Apple (Guideline 4.8)

**Not required.** The app offers email/password only — no Google, Facebook, or
other third-party social login — so the condition that triggers 4.8 is not met.

If Apple or Google sign-in is ever added, Sign in with Apple becomes mandatory,
and the private-relay email must be stored against the **same** account record
rather than creating a second one.

---

## 5. Subscriptions (Guidelines 3.1.1 / 3.1.2)

Vida+ unlocks in-app functionality and is sold **exclusively through Apple
In-App Purchase**. No external purchase links, no web checkout — a first
submission is the wrong place to test the external-link boundary.

**There is no code path that can grant paid access without Apple.** Billing
runs through RevenueCat when an API key is present, and through StoreKit 2
directly (`StoreKitMembershipService`) when it is not. The previous local stub,
which fabricated a successful purchase and a fake transaction id after a short
delay, has been deleted outright — it would have failed review and, worse, lied
to the person tapping Buy. Specifics now guaranteed:

- Purchase always reaches `Product.purchase()` or RevenueCat; unverified
  StoreKit transactions are rejected rather than honoured.
- Restore always calls `AppStore.sync()` (or RevenueCat's restore) and then
  reads real `Transaction.currentEntitlements`.
- A transaction listener runs for the whole process lifetime, so Ask to Buy
  approvals, renewals and refunds land without a relaunch.

Already in the binary, on the paywall:

- Title, price, and duration per plan, read live from the store (never
  hardcoded, so every currency is correct)
- Auto-renewal terms: charge at confirmation, renewal within 24 hours of period
  end, cancel at least 24 hours before, managed in Settings → Apple Account →
  Subscriptions
- **Restore purchases** button, present in the failure state too
- Functional **Terms of Use** and **Privacy Policy** links (also in Settings)

Still to fill in on the ASC side:

- **Privacy Policy URL**: `https://vidalab.co/privacy` — verified live (200)
  and identical to the in-app destination in `VidaLinks.privacy`
- **Terms of Use (EULA) field**: `https://vidalab.co/terms` — if left blank,
  Apple's standard EULA applies and the custom terms are not the operative ones
- **Support URL**: `https://vidalab.co/support`
- **Contact / support email**: `rowan@vidalab.co` — this is the only address
  the app, the site, and both legal documents use. App Review does test contact
  addresses, so it must receive mail before submission. Do not introduce
  `privacy@` or `hello@` aliases unless they are real mailboxes; a bounced
  privacy contact undercuts the deletion and data-rights commitments in the
  policy
- Subscription group with product IDs exactly: `vida_plus_monthly`,
  `vida_plus_yearly`, `vida_plus_family`
- Localized display name, description, and review screenshot per product

Both URLs must resolve before submission — a 404 on either is a rejection.

---

## 6. Accessibility declaration (ASC → App Review → Accessibility)

Apple's rule: only claim a feature if the **common tasks** can be completed
using it — here, onboarding, daily check-in, reading patterns, asking a
question, changing settings, and subscribing.

Answer **Yes** for iPhone and iPad, and tick:

- **VoiceOver** — every control has a label; composite rows are single
  elements with spoken values; trend arrows and status colours are also spoken
  as words; the thinking indicator announces itself.
- **Larger Text** — all app type now scales through `UIFontMetrics`
  (`Vida.sans/serif/number`), capped at 1.6× so the dense pattern and report
  layouts stay readable rather than breaking.
- **Sufficient Contrast** — palette measured against both canvases; the old
  caption taupe (2.5:1) was replaced with one at 4.75:1. Forest 11.1:1,
  inkSoft 5.4:1, moss 5.5:1, clay clears 4.5:1 in both modes.
- **Differentiate Without Color** — status never depends on hue alone: every
  state carries a glyph plus a word, and borders strengthen when the setting
  is on. This matters here because the palette uses green vs terracotta, the
  exact pair red-green deficiency collapses.
- **Reduced Motion** — the drifting backdrop, breathing constellation,
  thinking dots, progress rings, meters and button press-scale all stop or
  settle. Motion sensitivity is a symptom of migraine, POTS and long COVID,
  so this is core audience need, not a checkbox.
- **Dark Interface** — full adaptive palette; Night is a deep green-charcoal
  rather than black, and the preference is forced onto UIKit surfaces too.

Do **not** tick **Captions** or **Audio Descriptions** — the app ships no
audio or video content, so there is nothing to caption. Claiming them would be
inaccurate. **Voice Control** is not claimed either: it is largely inherited
from standard controls, but the custom tab bar and chip controls have not been
verified end-to-end, and an unverified claim is worse than an honest omission.

---

## 7. Review notes (paste into App Review Information)

> VIDA LAB is a wellness journaling app for people managing chronic illness. It
> surfaces correlations in a user's own logged data ("patterns worth noticing")
> and never diagnoses, treats, or claims causation.
>
> Health entries are encrypted on-device with AES-GCM before any upload; the
> key is held only in the user's Keychain, so our servers store ciphertext and a
> date and cannot read symptom content. This is why the App Privacy answers
> declare health data as collected and linked, but not used for tracking.
>
> A free account is required because each member's journal is encrypted and
> backed up to that account. Demo account for review: [EMAIL] / [PASSWORD].
> Apple Health access is optional and read-only. Account deletion is available in-app at
> Settings → Delete account and data.
>
> Vida+ is an auto-renewing subscription sold only through In-App Purchase.
> Free tier: 30-day history, 3 insights, 5 questions/day, 2 experiments, 1
> Doctor Prep. Viewing an already-generated report is never paywalled.
