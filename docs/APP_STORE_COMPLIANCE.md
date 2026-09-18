# App Store submission answer sheet — VIDA LAB

Everything App Store Connect will ask, with the answer that matches what the app
actually does. Keep this in sync with the code: under-disclosure is the most
common health-app rejection, and the riskiest one legally.

---

## 1. App Privacy (ASC → App Privacy → Data Types)

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

---

## 2. Age rating — targeting 16+

In the ASC age-rating questionnaire:

- **Medical/Treatment Information** → **Frequent/Intense** (this is what
  produces the 16+ result; the app is built around symptom tracking)
- **Sexual Content or Nudity** → None
- **Profanity or Crude Humor** → None
- **Alcohol, Tobacco, or Drug Use or References** → None
- **Horror/Fear Themes**, **Violence** (all forms), **Gambling**,
  **Contests** → None
- **Unrestricted Web Access** → **No** (outbound links are fixed: our own site,
  Apple's subscription settings)
- **User Generated Content** → **No** (entries are private to the author; there
  is no sharing, feed, or messaging)

Both legal pages now state a **16+** floor and explain why (health data
consent age in much of Europe), so the rating, the Terms, and the Privacy
Policy agree with each other.

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
In-App Purchase** via RevenueCat. No external purchase links, no web checkout —
a first submission is the wrong place to test the external-link boundary.

Already in the binary, on the paywall:

- Title, price, and duration per plan, read live from the store (never
  hardcoded, so every currency is correct)
- Auto-renewal terms: charge at confirmation, renewal within 24 hours of period
  end, cancel at least 24 hours before, managed in Settings → Apple Account →
  Subscriptions
- **Restore purchases** button, present in the failure state too
- Functional **Terms of Use** and **Privacy Policy** links (also in Settings)

Still to fill in on the ASC side:

- **Privacy Policy URL**: `https://vidalab.co/privacy`
- **Terms of Use (EULA) field**: `https://vidalab.co/terms` — if left blank,
  Apple's standard EULA applies and the custom terms are not the operative ones
- Subscription group with product IDs exactly: `vida_plus_monthly`,
  `vida_plus_yearly`, `vida_plus_family`
- Localized display name, description, and review screenshot per product

Both URLs must resolve before submission — a 404 on either is a rejection.

---

## 6. Review notes (paste into App Review Information)

> VIDA LAB is a wellness journaling app for people managing chronic illness. It
> surfaces correlations in a user's own logged data ("patterns worth noticing")
> and never diagnoses, treats, or claims causation.
>
> Health entries are encrypted on-device with AES-GCM before any upload; the
> key is held only in the user's Keychain, so our servers store ciphertext and a
> date and cannot read symptom content. This is why the App Privacy answers
> declare health data as collected and linked, but not used for tracking.
>
> An account is optional — the app is fully functional signed out. Apple Health
> access is read-only. Account deletion is available in-app at
> Settings → Delete account and data.
>
> Vida+ is an auto-renewing subscription sold only through In-App Purchase.
> Free tier: 30-day history, 3 insights, 5 questions/day, 2 experiments, 1
> Doctor Prep. Viewing an already-generated report is never paywalled.
