# Agent report, 2026-09-29

Claude worked through XCODE_AGENT_PROMPT.md on Rowan's Mac, using xcodebuild and the simulator. All work is on `rowan-local` in rowanalbritton/vidalab. The line-by-line detail is in docs/AGENT_LOG.md.

## Results

- **Unit tests:** pass. 166 passed before the copy changes and 165 after, with none failing.
- **Release archive:** builds (not uploaded). It is signed for development locally, which is normal. Xcode switches it to production when you choose Distribute App > App Store Connect.
- **Build:** passes after every change.

## What changed in the app

1. **Add a meal on Today.** The "What you ate" heading's add button was never drawn. Once a meal existed, there was no working way to add another. It now reads "Add a meal" (MealLogView.swift:263).
2. **Privacy manifest.** Added Fitness data. Steps and active energy from Apple Health go into the backed-up journal. App Store Connect needs seven data types (APP_STORE_COMPLIANCE.md §1).
3. **Em dashes.** 210 removed from on-screen text and rewritten sentence by sentence.
4. **Headlines.** They end in pale moss Newsreader italic, as in the reference screens (the new `Vida.headline` helper in VidaTheme.swift).
5. **Community** matches reference 06: "Compare notes, *kindly.*", a forest compose circle, and a quiet-panel note.
6. **Monthly Lab Notes recap.** It showed a pale screen in Forest because it used the pre-redesign meaning of `Vida.forest`. It now sits on the Forest canvas.
7. **VoiceOver.** Labels were added to the Back buttons in Doctor Prep and orientation, and to an article's Save button.
8. **Debug-only launch options** for screenshots: `-VidaPreview YES` (sample data, no account), `-VidaTab <tab>` and `-VidaSkipWelcome YES`. None of them are in Release builds.

Docs updated: PLATFORM_SOURCE_OF_TRUTH.md, APP_STORE_COMPLIANCE.md (§1, §4 and §5), ASC_PASTE_THIS.md (review notes) and LAUNCH_CHECKLIST.md (verified items ticked with dates).

## Design match against the reference screens

- **Matched after changes:** 05 Ask Vida (headline accent and dark question cards) and 06 Community (headline, compose button, quiet-panel note, chips).
- **Headline accent applied, not re-screenshotted:** 02 Patterns, 07 Lab, 08 Doctor Prep, 09 My Library, 10 Research Library and 12 Diary.
- **Already matching, no change needed:** the Forest canvas, the floating tab bar, the orbit menu button, the chips, the sliding pill switches, and article titles (already Geist).
- **Not verified:**
  - The Patterns screen order. The redesign's own code puts "This week's plate" above the constellation, while reference 02 shows the constellation first.
  - One screenshot showed "How to read this" drawn over the plate. It may have been caught mid-layout.
  - Today's progress card overlapping the bottom of the arch.
  - Screens 11 and 13 to 16.
- **Why:** the Mac was badly overloaded this afternoon (load average 40 to 90, almost no free memory). Other sessions were also using the iPhone 17 and 17 Pro simulators. App launches and screenshots kept timing out, so the full screen-by-screen pass and task 11 (the App Store screenshot drafts) are not done. Both can be done in a quieter moment with:
  `xcrun simctl launch <device> app.vidalab -VidaPreview YES -VidaSkipWelcome YES -VidaTab patterns`

## Follow-ups done later on 2026-09-29

- **Web members' manage link:** it now reads "Manage your web subscription" and opens https://vidalab.co/support instead of the sales page (VidaLinks.swift, SettingsView.swift).
- **Patterns:** the constellation now comes first and the plate follows, matching reference 02. This was checked in the simulator (docs/screenshots/forest-2026-09-29/patterns-constellation-first.png).

## Your remaining steps, in order

**Before submitting (app and backend)**
1. Tap through the app on your iPhone: every tab, the Vida menu, a check-in, the diary and the share card.
2. Make sure rowan@vidalab.co receives mail, and that the `VIDA_FROM_EMAIL` domain shows Verified in Resend.
3. Switch off the Base44 weekly newsletter timer before Monday 02:00 UTC. The reminder and appointment-reminder timers were already switched off on 2026-09-28.
4. Decide on the waiting items:
   - turn on the website switch
   - remove the fake doctor numbers
   - upload the meditation audio
5. Check that the OpenAI and Anthropic accounts have training on API data turned off.
6. Confirm the RevenueCat webhook URL and that Send Test returns 200.

**App Store Connect**

7. Agreements, Tax and Banking: complete the Paid Applications Agreement.
8. Subscriptions: create one group with `vida_plus_monthly`, `vida_plus_yearly` and `vida_plus_family`. Each needs a name, a description, a price and a paywall screenshot.
9. Users and Access > Integrations: generate an In-App Purchase Key and add it to RevenueCat. In RevenueCat, set the entitlement to `plus` with all three products attached. The code already uses exactly these IDs.
10. App Information: paste the subtitle. Version 1.0: make the three description edits and paste the review notes from ASC_PASTE_THIS.md.
11. Sign-In Information: enter a demo account's full email and password, and check that it really signs in.
12. Age Rating: answer the questions (Medical: Frequent; user-generated content: Yes). Override to 16+ if needed.
13. App Privacy: enter the seven types from APP_STORE_COMPLIANCE.md §1, all linked to the user and none used for tracking.
14. Accessibility: tick the features in APP_STORE_COMPLIANCE.md §6.
15. Screenshots: 6.9" and 6.5" iPhone, and 13" iPad.

**Test and ship**

16. Add a Sandbox tester, turn the StoreKit configuration off in the scheme, and test on your iPhone: buy, relaunch, restore, cancel, second device, and airplane mode.
17. Bump the build number, then Product > Archive > Distribute App > App Store Connect.
18. Install from TestFlight and walk the whole app once, including a purchase.
19. Submit for review.
