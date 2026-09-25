# VIDA LAB — publish sequence

The order matters. Several of these steps are **permanent** or block the ones
after them, so doing them out of order costs days. Each step says who does it
and what "done" looks like.

Companion docs: `APP_STORE_COMPLIANCE.md` (the ASC answer sheet — every
questionnaire answer lives there, not here).

---

## Stage 0 — Decide the bundle ID (do this first, it is irreversible)

**Decided: `app.vidalab`** (confirmed 2026-09-18). No change to
`co.vidalab.app`.

**Once a build is uploaded to App Store Connect, the bundle ID is permanent for
that app record.** Changing it later means a brand-new App Store listing, new
reviews, new downloads, and every existing install orphaned.

- [x] Confirm the final identifier before anything is uploaded. → `app.vidalab`
- [ ] If it changes: 6 entries in `VIDALAB.xcodeproj/project.pbxproj`
      (app Debug/Release, tests Debug/Release, UI tests Debug/Release), plus the
      RevenueCat dashboard app entry, plus the ASC app record.

Done when: the identifier in the project, RevenueCat, and ASC are identical and
nobody intends to change it again.

---

## Stage 1 — Make the public URLs real (blocks submission)

Apple checks these. A 404 on either is a rejection, and the reviewer will hit
them from the paywall.

**Hosting changed 2026-09-18: `vidalab.co` moved off Netlify onto Base44.**
`site/` and `netlify.toml` were removed from this repository the same day —
Base44 now owns the live build and DNS for the domain, and is still building
the site's content. The `/privacy` and `/terms` pages that used to live in
this repo's `site/legal/` need to exist on Base44 instead; confirm with
whoever operates the Base44 project that they've been carried over (or
rebuilt) there.

- [ ] **Confirm Base44 serves real content at `/privacy`, `/terms`, and
      `/support`.** As of this check they all return the generic Base44 app
      shell instead of actual pages — the site is still mid-build there.
- [ ] Verify once Base44's build is live: `https://vidalab.co/privacy`,
      `https://vidalab.co/terms`, `https://vidalab.co/support` all return 200
      with the correct content, and `/privacypolicy` 301s to `/privacy`.
- [ ] **Create the `support@vidalab.co` mailbox** and send a test message to it.
      It is the only address in the app, the site, and both legal documents, and
      App Review does email it.

Done when: all three URLs load on a device you are not signed into, and the
mailbox receives mail.

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
