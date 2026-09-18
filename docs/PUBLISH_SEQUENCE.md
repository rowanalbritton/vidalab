# VIDA LAB — publish sequence

The order matters. Several of these steps are **permanent** or block the ones
after them, so doing them out of order costs days. Each step says who does it
and what "done" looks like.

Companion docs: `APP_STORE_COMPLIANCE.md` (the ASC answer sheet — every
questionnaire answer lives there, not here).

---

## Stage 0 — Decide the bundle ID (do this first, it is irreversible)

The project currently builds as **`app.vidalab`**. The intended identifier was
`co.vidalab.app`.

**Once a build is uploaded to App Store Connect, the bundle ID is permanent for
that app record.** Changing it later means a brand-new App Store listing, new
reviews, new downloads, and every existing install orphaned.

- [ ] Confirm the final identifier before anything is uploaded.
- [ ] If it changes: 6 entries in `VIDALAB.xcodeproj/project.pbxproj`
      (app Debug/Release, tests Debug/Release, UI tests Debug/Release), plus the
      RevenueCat dashboard app entry, plus the ASC app record.

Done when: the identifier in the project, RevenueCat, and ASC are identical and
nobody intends to change it again.

---

## Stage 1 — Make the public URLs real (blocks submission)

Apple checks these. A 404 on either is a rejection, and the reviewer will hit
them from the paywall.

- [x] **Site deployed.** `/privacy`, `/terms` and `/support` verified live
      (200), and `/privacypolicy` 301s to `/privacy`.
- [x] **Submitted metadata URLs corrected.** `metadata/app-info/en-US.json`
      carried `http://vidalab.co/privacypolicy` — an `http://` URL pointing at
      the retired path. It now reads `https://vidalab.co/privacy`, which is
      byte-identical to the in-app destination in `VidaLinks.privacy`. The
      marketing and support URLs were also `http://` and are now `https://`.
      See the note below for why the old value was dangerous rather than merely
      untidy.
- [ ] **Create the `support@vidalab.co` mailbox** and send a test message to it.
      It is the only address in the app, the site, and both legal documents, and
      App Review does email it.

### Why the old privacy URL was a real risk

`http://vidalab.co/privacypolicy` did eventually resolve, via a two-hop
redirect: `http` → `https`, then `/privacypolicy` → `/privacy`. "It loads if
you follow it" is a weaker guarantee than it sounds:

- Apple requires the privacy policy URL to serve the policy **directly**.
  Redirect chains are a documented rejection trigger, and an `http://` first
  hop is a plaintext request for a health app's privacy policy.
- The two URLs were also *different strings* — ASC pointed at
  `/privacypolicy` while the app's own Settings and paywall links pointed at
  `/privacy`. A reviewer comparing them sees two policy locations for one app.
- `/privacypolicy` is a legacy path kept alive only by a 301 in `netlify.toml`.
  Anything that depends on a redirect for compliance breaks the day the
  redirect is tidied away.

Done when: all three URLs load on a device you are not signed into, and the
mailbox receives mail.

---

## Stage 1b — Fix the App Privacy declaration (blocks submission)

**App Store Connect currently declares "Data Not Collected". That is false and
must be changed before any submission.** Signed-in users upload email, name,
user ID and encrypted check-in content to Supabase. Apple counts uploaded data
as collected regardless of encryption — encryption decides who can *read* it,
not whether it was collected.

"Data Not Collected" is an exclusive claim: a single upload contradicts it. It
also contradicts `VIDALAB/PrivacyInfo.xcprivacy` inside the binary, which
declares five types correctly — and Apple compares the manifest against the
product page.

- [ ] ASC → App Privacy → switch to "Yes, we collect data".
- [ ] Enter the five types from `APP_STORE_COMPLIANCE.md` §1: Health, Email
      Address, Name, User ID, Purchase History — all Linked, none used for
      tracking, purpose App Functionality.
- [ ] Confirm the saved answers match the manifest exactly.

This is ASC state, not a repo file, so it cannot be fixed from code. Do it in
the ASC UI, or run `asc auth login` and then
`asc web privacy pull → plan → apply`.

Done when: the product page lists five collected types and no longer says
"Data Not Collected".

---

## Stage 2 — Apple Developer enrolment and ASC record

- [ ] Apple Developer Program enrolment complete ($99/yr, can take 24–48h, longer
      for an organisation with a D-U-N-S check).
- [ ] Create the app record in App Store Connect with the Stage 0 bundle ID.
- [ ] Set `DEVELOPMENT_TEAM` in the project (currently empty).

Done when: the app record exists and the team ID is in the build settings.

---

## Stage 3 — Subscriptions (blocks the paywall showing real prices)

The paywall reads prices live from the store. Until these exist it correctly
shows "Prices aren't loading" rather than inventing a number.

- [ ] Create a subscription group, then three products with **exactly** these IDs:
      `vida_plus_monthly`, `vida_plus_yearly`, `vida_plus_family`.
- [ ] Per product: localised display name, description, price, and a review
      screenshot (Apple rejects products without one).
- [ ] **Terms of Use (EULA) field** → `https://vidalab.co/terms`. Left blank,
      Apple's standard EULA silently applies and your terms are not operative.
- [ ] **Privacy Policy URL** → `https://vidalab.co/privacy`.
- [ ] Generate an **In-App Purchase Key** and add it to RevenueCat.
- [ ] Paid Applications Agreement signed and banking/tax complete — products
      stay unavailable without it, and the paywall will show no prices.

Done when: the three products read "Ready to Submit" and RevenueCat shows them.

---

## Stage 4 — RevenueCat wiring

- [ ] Dashboard → Integrations → Webhooks → add
      `https://lhorsiwwnqzkvunuazry.supabase.co/functions/v1/revenuecat-webhook`
      with the shared secret, then **Send Test** and confirm a 200.
- [ ] Entitlement identifier must be exactly **`plus`** — the app looks that up
      by name; a different string silently leaves everyone on Free.
- [ ] Attach all three products to that entitlement.
- [ ] Put the production iOS API key in `EXPO_PUBLIC_REVENUECAT_IOS_API_KEY`.

Done when: the test webhook returns 200 and the entitlement lists three products.

Note: if no RevenueCat key is present the app now falls back to **StoreKit 2
directly**, so purchases still work. RevenueCat is preferred because the webhook
is what writes cross-device entitlements server-side.

---

## Stage 5 — Test the money path end to end

Do this on a real device with a **Sandbox Apple Account**, not the simulator.

**First, verify which billing provider the submitted binary actually got.**
The RevenueCat key is injected at build time, so the source cannot tell you
which provider a given build ended up with — only the running build can. Launch
a Debug build and read the one-line log:

```
[Membership] billing provider: RevenueCat · App Store
```

- `RevenueCat · App Store` — production key present, as intended.
- `RevenueCat · Test Store` — a `test_` key. Fine in Debug, **never** in a
  build you submit.
- `StoreKit 2 (direct)` — no RevenueCat key was injected. Purchases still go
  through Apple and still work, but the webhook will not fire, so cross-device
  entitlements will not sync.

A Release build now refuses a `test_` key outright and falls back to StoreKit 2
rather than trusting it, because Test Store purchases complete without money and
without the App Store — shipping one would grant Vida+ to everyone who tapped
Buy. The fallback means the worst case is real billing minus RevenueCat
analytics, never free memberships.

- [ ] Provider line reads `RevenueCat · App Store` before you archive.

- [ ] Purchase → Vida+ unlocks.
- [ ] Force-quit and relaunch → still unlocked (persistence).
- [ ] Delete and reinstall → **Restore purchases** re-unlocks it.
- [ ] Cancel in Sandbox → access continues to period end, then downgrades.
- [ ] Sign in on a second device → entitlement arrives via the webhook.
- [ ] Airplane mode at launch → last known tier is kept, no silent downgrade.

Done when: all six behave as described. This is the area reviewers probe hardest.

---

## Stage 6 — App Store listing

- [ ] Screenshots: 6.9" and 6.5" iPhone are mandatory; 13" iPad is required
      because the app ships as universal (`TARGETED_DEVICE_FAMILY = "1,2"`).
- [ ] Description, subtitle, keywords, promotional text.
- [ ] **App Privacy** answers — copy from `APP_STORE_COMPLIANCE.md` §1.
- [ ] **Age rating** → Medical/Treatment Information: Frequent/Intense → 16+
      (§2). This must agree with the 16+ floor stated in both legal documents.
- [ ] **Accessibility declaration** (§6) — tick only the six features listed
      there. Do not tick Captions or Audio Descriptions.
- [ ] Support URL `https://vidalab.co/support`, contact `support@vidalab.co`.
- [ ] Paste the review notes from §7 into App Review Information.

Because there is no account wall, the reviewer does not need demo credentials —
say so explicitly in the notes so they do not ask for them.

---

## Stage 7 — Submit

- [ ] Archive a Release build and upload (`submitBuild`).
- [ ] TestFlight first: install on a real device and walk the whole app,
      including a purchase, once.
- [ ] Submit for review.

Expect 24–48h. If rejected, the reply usually names a guideline number — map it
back to the relevant section of `APP_STORE_COMPLIANCE.md` before changing code.

---

## Known follow-ups (not blockers)

- **Apple Watch**: not built. A watch app is a separate target and a separate
  product decision — a check-in complication would be the obvious first piece,
  but shipping the phone app should not wait for it.
- **Bundle ID flip** to `co.vidalab.app`, if wanted, must happen in Stage 0.
- **iPad**: supported and laid out in a reading column, but it is a scaled phone
  layout rather than a split-view iPad design. Fine to ship; worth revisiting if
  iPad usage turns out to matter.
