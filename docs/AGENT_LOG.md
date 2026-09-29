# Agent log

## Summary, 2026-09-29 (see docs/AGENT_REPORT_2026-09-29.md for Rowan's steps in order)

- **Done:**
  - tests pass and the Release archive builds
  - the add-a-meal bug is fixed
  - the docs are updated
  - Fitness is added to the privacy manifest
  - all on-screen em dashes are removed
  - the review notes are updated
  - headlines have the italic accent
  - Community matches the reference
  - the Lab Notes recap works in Forest
  - three VoiceOver labels are added
  - the verified checklist items are ticked
- **Verified from code:**
  - the paywall has Restore purchases, auto-renewal terms, and Terms and Privacy links
  - the product IDs and the `plus` entitlement match the checklist
  - the age gate is 16
  - the live privacy, terms and support pages carry the required updates
- **Not finished:**
  - a full screen-by-screen screenshot pass against references 00 to 16
  - the App Store screenshot drafts (task 11)
  - both were blocked because the Mac was overloaded and other sessions were using the simulators
- **Left for Rowan:** everything marked You in LAUNCH_CHECKLIST.md, in the order listed in the report.

Work from XCODE_AGENT_PROMPT.md, done by Claude on Rowan's Mac with xcodebuild and the simulator (not the Xcode panel).

## 2026-09-29

- **Task 1, tests:** all 166 unit tests in VIDALABTests pass on the iPhone 18 Pro simulator (iOS 27). No test changes were needed.
- **Task 2, Release archive:** `xcodebuild archive -configuration Release` succeeded. It was not uploaded.
  - There are 4 minor warnings (actor isolation in CareFinderService.swift:127 and VidaSyncService.swift:52,56, and an unused `try?` in PushNotificationService.swift:101). They are harmless and were left alone.
  - The archive is signed for development (`aps-environment` development, `get-task-allow` true). That is normal for a local archive. Xcode switches both when you choose Distribute App > App Store Connect.
- **Bug fixed while archiving:** `MealLogView.swift:263`. On Today, the "What you ate" heading passed a Button as the heading's tap action, so the + never appeared, and once a meal was logged, "See all" did nothing. The heading's link now reads "Add a meal" and opens the meal composer.
- **Task 3, docs:**
  - `docs/PLATFORM_SOURCE_OF_TRUTH.md` now says an account is required, lists the six tabs and the Vida menu, and makes Forest the app default (the website keeps cream).
  - `docs/APP_STORE_COMPLIANCE.md` §4 now describes Sign in with Apple as required and done (Apple, Google and email, with Apple token revocation on deletion).
  - §5 now notes that the website sells Vida+ through a Stripe Payment Link, which the app never mentions.
  - **Flag for Rowan:** `SettingsView.swift:550` sends members who bought on the web to `https://vidalab.co/vida-plus` to manage their plan. That page is the sales page. The link only appears for web members, and the demo account won't be one, but a cancel or account page would be safer. Not changed.
- **Task 4, privacy manifest:**
  - **Fixed:** added **Fitness** (linked, not tracking, App Functionality) to `PrivacyInfo.xcprivacy`. Daily steps and active energy from Apple Health become journal readings, which are backed up (encrypted), and step tags can go into Vida+ summaries. `APP_STORE_COMPLIANCE.md` §1 now lists the seven types to enter in App Store Connect.
  - **Correctly not declared:**
    - Location is only used on the device for Apple Maps and is never sent to VIDA LAB.
    - The diary and meditation history stay on the device.
    - Meditation audio downloads carry no account data.
  - **Already covered:** Ask Vida questions sent to OpenAI and check-in summaries sent to Anthropic fall under the Health and Other User Content types. Community posts are Other User Content. The only required-reason API used is UserDefaults, and it is declared.
- **Task 5, em dashes:** all 210 em dashes in on-screen text are gone.
  - 81 lines in the app screens and models were rewritten by hand.
  - The rest were in the content libraries, all rewritten with commas, colons, periods or parentheses and checked sentence by sentence: ScienceLibrary 62, PatternExplainer 43, AskVidaLibrary 24.
  - Kept on purpose: 4 lone "—" placeholders that mean "no value" (WeeklyReport.swift:176, ExperimentsView.swift:511, MealLogView.swift:193, ResearchLibraryService.swift:251), and dashes inside code comments.
  - The build and all tests pass afterwards.
- **Task 6, review notes:** `ASC_PASTE_THIS.md` now covers:
  - the sign-in options (Apple, Google, email)
  - the Community guidelines gate, reporting, blocking and moderation
  - the on-device Diary
  - the share card
  - the AI-generated meditation voices (Kokoro-82M)
- **Task 9, design match, part 1** (reference screens in design-reference/screens):
  - Page headlines now end in Newsreader italic in pale moss, using a new `Vida.headline(_:accent:)` helper (VidaTheme.swift) and the `Vida.headlineAccent` token: Patterns "in *your body*", Ask "about *your body.*", Lab "on *yourself.*", Doctor Prep "to *explain it.*", My Library "*real science.*", Research Library "*kept current.*", Diary "Your *diary*".
  - Community now matches reference 06: the headline "Compare notes, *kindly.*", a forest compose circle, and the note as a quiet panel (shell at 60%, radius 18).
- **Task 7, Forest pass:** the monthly Lab Notes recap (LabNotesView.swift) used `Vida.forest` as a full-screen background. After the redesign, `Vida.forest` is the light text colour in Forest mode, so the recap showed as a pale sheet. It now sits on `VidaCanvas()` with forest text and a forest capsule button.
- **Task 8, VoiceOver:** added labels to three icon-only buttons: Back in the Doctor Prep interview (DoctorPrepView.swift:235), Back in orientation (OrientationView.swift:578), and Save or Remove from saved on an article (LibraryView.swift:797). The other icon-only buttons already had labels.
- **Debug preview mode:** `-VidaPreview YES` shows the tabs with nine weeks of sample data and no account, for simulator screenshots. It is only in Debug builds. It exists because the simulator's live sign-in expired, and entering a password into the live app isn't something the agent may do.

## 2026-09-29, evening run (details in docs/AGENT_REPORT_2026-09-29-evening.md)

- **Patterns:** the constellation now comes before the plate (PatternMapView.swift).
- **Web members' manage link:** it now opens vidalab.co/support and is labelled "Manage your web subscription" (VidaLinks.swift, SettingsView.swift).
- **Lab and Library:** the switch sits under each section's top bar (the new SectionSwitchSlot.swift, plus ContentView.swift LabShell and ResearchLibraryView.swift LibraryShell). Treatments gets the orbit mark.
- **Today:** the progress card overlaps the arch by 64 pt (HomeView.swift).
- **Debug capture options:** VidaLabSection, VidaOpenMenu, VidaOpenShare, VidaOpenPaywall, VidaDaylight and VidaHour. The preview ignores a signed-in simulator account.
- **Screens matched:** 01, 02, 05, 06, 07, 08, 09, 10, 11, 14 and 16. Not captured: 03 and 04 in detail, and 12, 13 and 15, which need taps.
- **App Store drafts:** docs/screenshots/app-store-draft/ (6.9" iPhone and 13" iPad).
- **Checks:** tests pass (161) and the Release archive succeeds.
