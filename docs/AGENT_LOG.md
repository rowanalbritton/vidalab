# Agent log

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
