# VIDA LAB launch checklist

Updated 2026-09-28. This checklist is built from the code on `rowan-local`, the docs in `docs/`, and today's work. Each item says who does it:
- **You** means only Rowan can do it, because it needs her accounts, a legal decision or a real iPhone.
- **Agent** means Claude can do it, either in Xcode or in the project thread.

The work is grouped in the order it should happen. The "Blocks review" items are the ones Apple would reject the app for.

---

## Already done

- [x] Bundle ID `app.vidalab` and team `FQF67NVP7H` are set.
- [x] The redesign is merged into your app, with all six tabs, Community, Research Library, Treatments, Lab Notes and meditation kept. It's on GitHub as `rowan-local`.
- [x] The merged app builds for the iPhone 18 Pro simulator.
- [x] Accounts require a 16+ date-of-birth check, and the birth date is not stored.
- [x] Account deletion works in the app.
- [x] Community has report, block and moderator hide.
- [x] Vida+ purchases go only through Apple, using RevenueCat with StoreKit 2 as a fallback. The StoreKit test file exists.
- [x] Secrets.plist is kept out of git.
- [x] The Supabase keys are added, and deploying the website functions is approved.

---

## Stage 1: Make sure the new build is right (this week)

- [ ] **You:** run the merged app on the simulator, then on your iPhone, and tap through every tab and the Vida menu. It has only been compiled so far, not clicked through. Use the `ios-design-refresh/screens` images as the reference, and report anything that looks off.
- [x] **Agent:** fix whatever you find, then archive a Release build (Product > Archive) to confirm it compiles for release. *Done 2026-09-29: Release archive builds; not uploaded.*
- [x] **Agent:** run the unit tests (VIDALABTests) and fix any failures the merge caused. *Done 2026-09-29: all tests pass (166, and 165 after the copy changes, with none failing).*
- [ ] **Agent:** commit the files that are saved but not yet committed:
  - the three Supabase timer files
  - the appointment-reminders security check
  - the checkout routing change in `vidalabwebsite`
- [ ] **You:** decide on your unsaved legal page edits in `VIDA_LAB_RECOVERED`.
- [x] **Agent:** replace the outdated docs so no future agent is misled (XCODE_AGENT_PROMPT.md now holds the current work prompt): *Done 2026-09-29: PLATFORM_SOURCE_OF_TRUTH.md and APP_STORE_COMPLIANCE.md §4 and §5 updated.*
  - `XCODE_AGENT_PROMPT.md` still points at `VIDA_LAB_RECOVERED`, so swap it for the new `CLAUDE.md`.
  - `docs/PLATFORM_SOURCE_OF_TRUTH.md` still says the account is optional and lists the old cream palette.
  - `docs/APP_STORE_COMPLIANCE.md` §4 says there's no Apple or Google sign-in, but both exist now.
  - `docs/APP_STORE_COMPLIANCE.md` §5 says there's no web checkout, but there is one on the website.

## Stage 2: Finish the backend move (in progress)

- [x] **Agent:** deployed the 12 website functions to Supabase (2026-09-28). The scheduled ones refuse callers without the cron secret.
- [ ] **Agent:** turn on `SUPABASE_FUNCTIONS_LIVE` in the website code. Checkout stays on Base44. This needs Rowan's approval on her Mac.
- [x] **Agent:** started the three Supabase timers (check-in reminders every 30 minutes, appointment reminders hourly, the newsletter Mondays 02:00 UTC).
- [x] **Agent:** confirm each timer has run once successfully. *Done 2026-09-29: reminders and appointment reminders ran at 22:00 UTC on 2026-09-28 and returned 200. The newsletter first runs Monday 02:00 UTC.*
- [ ] **You:** switch off the Base44 **weekly newsletter** timer before Monday 02:00 UTC. The send-reminders and send-appointment-reminders timers were already switched off on 2026-09-28. Leave the Instagram post on.
- [ ] **You:** make sure `VIDA_FROM_EMAIL` uses a domain that shows **Verified** in Resend, or reminder emails won't send.
- [ ] **Agent:** set up the meditation audio. Apply the storage bucket migration and upload the rendered guide audio, so sessions don't fall back to the phone's own voice.
- [ ] **You:** confirm the RevenueCat webhook points at `https://lhorsiwwnqzkvunuazry.supabase.co/functions/v1/revenuecat-webhook` and that Send Test returns 200.

## Stage 3: Website and legal pages (blocks review)

Apple opens these links from the paywall and compares the privacy policy against what the app does.

- [x] **Verified 2026-09-29:** `https://vidalab.co/privacy`, `/terms` and `/support` load real pages when signed out.
- [x] **Agent:** the privacy URL in `ios-vida-signals/metadata/app-info/en-US.json` is now `https://vidalab.co/privacy`.
- [x] **Verified 2026-09-29:** the live privacy policy and terms carry the five updates from `docs/LEGAL_PAGE_UPDATES_NEEDED.md`: 16+, OpenAI and Anthropic named, in-app deletion, Apple and Google sign-in, and location, appointments and meditation. Stripe is named for website payments, and the contact address is rowan@vidalab.co.
  1. The age goes from 13 to 16.
  2. The AI providers (OpenAI and Anthropic) are named.
  3. In-app account deletion is described.
  4. Apple and Google sign-in are covered.
  5. Location, appointment requests and meditation are covered.
- [x] **Support address:** rowan@vidalab.co, chosen 2026-09-28 and now used in the app, docs and metadata. Make sure that mailbox receives mail, because App Review emails it.
- [ ] **You:** check that the OpenAI and Anthropic accounts have training on API data turned off. The privacy policy wording promises this.

## Stage 4: Content that could embarrass you in review

- [ ] **You:** replace the placeholder Doctor Finder listings on the website database with real practices, or hide the directory for launch. Some listings have fake numbers like (212) 555-0142, and the Appointment Concierge reads from that directory.
- [x] **Agent (optional):** replace em dashes in the app's on-screen copy. There are about 190 lines to change. *Done 2026-09-29: 210 removed. Only 4 lone "—" no-value placeholders remain.*
- [x] **Done 2026-09-30:** the Community database columns were fixed, and the feed loads for signed-in members. Next, post once from the app to confirm writes work.
- [ ] **Agent (needs a go-ahead):** add the missing block-author table and function to the live database, so Block works.

## Stage 5: App Store Connect (blocks submission)

`ASC_PASTE_THIS.md` and `docs/APP_STORE_COMPLIANCE.md` have the exact text for the steps below.

- [ ] **You:** make sure the Paid Applications Agreement, banking and tax are complete. Prices won't load without them.
- [ ] **You:** set up the three subscriptions (`vida_plus_monthly`, `vida_plus_yearly` and `vida_plus_family`) in one group.
  - Each needs a display name, a description, a price and **a paywall screenshot**. The missing screenshots are what's keeping all three at "Missing Metadata" right now.
  - Set the EULA to `https://vidalab.co/terms` and the privacy link to `https://vidalab.co/privacy`.
- [ ] **You:** generate an In-App Purchase Key in App Store Connect and add it to RevenueCat.
- [ ] **You:** in RevenueCat, set the entitlement ID to exactly `plus` and attach all three products to it.
- [ ] **You:** paste in the subtitle, the three description edits and the review notes from `ASC_PASTE_THIS.md`.
- [x] **Agent:** update the review notes to mention the new parts, then give you the final text to paste. The new parts are: *Done 2026-09-29: ASC_PASTE_THIS.md updated; ready to paste.*
  - the diary, which stays on the device
  - the share card
  - AI-generated meditation voices
  - the Community rules
- [ ] **You:** create a demo account that really signs in with email and password, and enter its full email in Sign-In Information.
- [ ] **You:** answer the age rating questions (Medical: Frequent; user-generated content: Yes). Override to **16+** if the result comes out lower.
- [ ] **You:** answer the App Privacy questions from `APP_STORE_COMPLIANCE.md` §1. *Updated 2026-09-29: there are now seven types, because Fitness was added.*
  - Declare Health, Email, Name, User ID, Purchase History and Other User Content.
  - Mark all of them linked to the user and none used for tracking.
- [x] **Agent:** check `PrivacyInfo.xcprivacy` against what the app actually does, including location (only when you tap, and not stored) and the diary (on the device only), and report any mismatch. *Done 2026-09-29: Fitness added. Location, the diary and meditation are correctly not declared. Enter the 7 types listed in APP_STORE_COMPLIANCE.md §1.*
- [ ] **You:** tick the accessibility declaration features listed in §6. *2026-09-30: checked in the app. VoiceOver labels, Larger Text (six tabs at the largest size), Dark Interface, Sufficient Contrast (AA on every text colour) and Reduced Motion (in code). See the 2026-09-30 report.*
- [ ] **You + Agent:** take new screenshots, because the redesign changed every screen. Apple needs 6.9" and 6.5" iPhone sizes, plus 13" iPad because the app is universal. The Agent can capture them from the simulator, and you choose the order and captions. *2026-09-29: drafts for 6.9" iPhone and 13" iPad are in docs/screenshots/app-store-draft/. There is no 6.5" set, because the simulator runtime has no 6.5" model and 6.9" covers iPhone. You still choose the order and add captions.*

## Stage 6: Test the money path on a real iPhone

Use a Sandbox Apple Account (App Store Connect, then Users and Access, then Sandbox).

- [ ] **You:** check each of these:
  - Buying unlocks Vida+.
  - It stays unlocked after force-quitting.
  - Reinstalling and tapping Restore unlocks it again.
  - After cancelling, access lasts until the end of the period.
  - A second device gets the entitlement.
  - In airplane mode, it keeps the last known tier.
- [ ] **You:** turn the StoreKit test file off in the scheme before this test. Otherwise purchases don't reach the sandbox.

## Stage 7: Ship

- [ ] **Agent:** bump the build number, archive and upload.
- [ ] **You:** send it to TestFlight, install it on your iPhone, and walk the whole app once, including a purchase.
- [ ] **You:** submit it for review. It usually takes 24 to 48 hours. If it's rejected, send the rejection text to the thread and the Agent will map it to the fix.

---

## After launch (not blockers)

- Website checkout: it's a Stripe Payment Link handled by the Base44 `stripe-webhook` function, and the old Wix functions are unused. Decide whether to move `stripe-webhook` off Base44.
- The 8 Google and Instagram features: decide which ones to move off Base44.
- iPad split-view layouts, Apple Watch check-ins, and home and lock screen widgets.
- Next ideas: flare mode, haptic breathing, an appointment-day view and voice check-ins.
