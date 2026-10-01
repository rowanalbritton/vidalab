# VIDA LAB iOS: context for coding agents

Read this before changing anything. It reflects the state of the project on 2026-09-29. The latest agent report is `docs/AGENT_REPORT_2026-09-29.md`, and the running log is `docs/AGENT_LOG.md`.

## What this is

VIDA LAB is a private wellness reflection app for people living with chronic illness. It's built with SwiftUI and is paired with the website vidalab.co. Members log daily check-ins, see patterns in their own data, ask questions of a cited research library, and run small self-experiments. They also prepare for doctor appointments, keep a diary, meditate, and talk in a moderated community.

It is educational and wellness software. It never diagnoses, treats or claims causation. Pattern language must always be phrased as correlation: "worth noticing", "moved together", never "causes".

Owner: Rowan Albritton. Contact everywhere: rowan@vidalab.co.

## Where things live

- **Repo:** `rowanalbritton/vidalab`
  - `rowan-local` is the current working branch. It holds the merged redesign plus all of Rowan's features.
  - `website` holds the vidalab.co code and the Supabase Edge Functions the site uses.
  - `main` and `app-store-readiness` are older.
- **Mac folder:** `~/Desktop/vida lab/VIDA_LAB_rowan-local/`
  - Open `ios-vida-signals/VIDALAB.xcodeproj`.
  - `VIDA_LAB_RECOVERED` is the pre-merge backup. Do not edit it.
- **Website code on the Mac:** `~/Developer/vida-lab/vidalabwebsite`
- **Supabase project ref:** `lhorsiwwnqzkvunuazry`
- **Older repo:** `rowanalbritton/vida-lab` is an older copy where the redesign was first built. Do not work there.

## Build settings to respect

- iOS 18 minimum, Swift 5 mode, universal app (iPhone and iPad).
- Bundle ID is `app.vidalab`, and it is permanent. Team is `FQF67NVP7H`.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Value types used off the main actor are marked `nonisolated`. Keep that pattern.
- `MemberImportVisibility` is on, so import every module a file uses.
- File-system synchronized groups are on. New files in `VIDALAB/` join the target automatically, so never hand-edit `project.pbxproj` to add files.
- Fonts (Geist and Newsreader italic) are registered at runtime in `VidaFonts.register()`. Do not add `UIAppFonts`.
- Keep keys out of git:
  - `VIDALAB/Secrets.plist` holds the local keys (Supabase anon key, RevenueCat key) and is gitignored.
  - `Config.swift` is committed, but only with empty values.
  - Never print, move or commit key values.

## App structure

**Tabs (six, all required):** Today, Patterns, Ask, Community, Lab, Library.
- Lab has three sections: Experiments, Doctor Prep and Treatments.
- Library has two: My Library and Research Library.

**Vida menu:** the orbit mark at the top left of every tab opens "Everything in Vida" (`Views/VidaMenu.swift`). Its groups are:
- Track and reflect: Check in, Diary, Your week, Share
- Understand: Pattern Map, Ask Vida
- Learn: The Library, Research Library, Community
- Care: Appointment Concierge, Experiments
- You: Settings, vidalab.co

Any new feature should get a row there.

**Other features:**
- Daily check-ins (`CheckInFlow`, `MorningCheckInView`). A check-in ends with an optional diary step that has a Skip button.
- Diary (`DiaryView`, `Models/Diary.swift`). It's on-device and never uploaded, and each day's check-in shows beside the writing. Since 2026-09-30 it is stored in its own file per account under complete file protection (`Models/DiaryVault.swift`), so it can't be read while the phone is locked. Never move it back into the UserDefaults snapshot.
- Pattern Map: the constellation, Vida+ upsell, threads, and the specimen plate story.
- Ask Vida: answers come from `AskVidaLibrary` first. OpenAI is used only after a one-time consent prompt, through the `ask-vida` Edge Function.
- Doctor Prep: the Health Snapshot plus the Appointment Concierge ("Say it in one breath" and "If you feel brushed off"). The concierge can also find doctors (`CareFinderService`) and save appointment requests.
- Vida+ tools: Body Weather, Vida Differential and Concierge insights. With consent, these send check-in summaries to Anthropic.
- Meditation (`MeditationViews`, `GuidedSessions.swift`). The guide voices are AI-generated with ElevenLabs (`tools/generate-meditation-audio/generate.py --engine elevenlabs`; Kokoro-82M remains available offline). Audio downloads from a Supabase storage bucket, with on-device TTS as a fallback.
- Community: posts, replies, topics, report and block, and guidelines.
- Other screens: Share card (`ShareSnapshotView`, a 1080×1920 story image), Weekly report, Lab Notes, Meals, Body metrics, Apple Health import (read-only), Web access, Welcome and tour.

## Design system (finalized; do not drift)

Tokens live in `Utilities/VidaTheme.swift` and `Utilities/VidaMotion.swift`. Always use the tokens, never hard-coded colours, so light mode keeps working.

- **Look:** Forest (dark green) is the default look. Daylight (cream) is the light alternative, chosen under Settings > Appearance.
- **Colours:** `Vida.cream`, `paper`, `shell`, `forest`, `onForest`, `moss`, `sage`, `sky`, `skyDeep`, `blush`, `ink`, `inkSoft`, `taupe` and `hairline` all adapt to both looks.
- **Type:** Geist for everything, with Newsreader italic reserved for accent words.
  - Page headlines use `Vida.headline("Lead words ", accent: "last words.")` with `.tracking(Vida.displayTracking)`. It draws Geist Light plus Newsreader italic in `Vida.headlineAccent` (pale moss, #BFE3CC in Forest).
  - Eyebrows use `Eyebrow(text:)`, and section titles use `SectionHeading(eyebrow:title:)`.
- **Components:**
  - Cards: `.paperCard()`, radius 22.
  - Quiet panels: `Vida.shell` at 60% opacity, radius 18.
  - Chips: `SelectChip`.
  - Primary buttons: a forest capsule with `onForest` text.
  - Segmented switches: a sliding forest pill using `matchedGeometryEffect`. In Lab and Library, the shell hands the switch down through the environment, and each section shows it under its own top bar with `.vidaSectionSwitch()` (Views/Components/SectionSwitchSlot.swift).
- **Screen chrome:**
  - Every tab screen applies `.vidaScrollChrome("Title")` and `.vidaMenu()` inside its `NavigationStack`, with `VidaCanvas()` or `.vidaBackground()` behind it.
  - The floating glass tab bar is `VidaTabBar` in `ContentView.swift`.
- **Motion:** use the `Vida.Motion` tokens. Reduce Motion must switch off parallax, scroll effects and drifting backgrounds.
- **Reference:** the approved screens are in `design-reference/screens` (00 to 16), with notes in `design-reference/VIDA-LAB-Xcode-Manual.md`.
- **Token gotcha:** after the redesign, `Vida.forest` is the *light* text colour in Forest mode, and `Vida.onForest` is dark. Never use `Vida.forest` as a full-screen background. Use `VidaCanvas()` or `.vidaBackground()`. The Lab Notes recap broke this way and was fixed on 2026-09-29.

## Testing in the simulator

- **Debug-only launch options** (compiled out of Release builds):
  - `-VidaPreview YES` shows the tabs with nine weeks of sample data and no account. It's in memory only, and the monthly recap is suppressed.
  - `-VidaTab <home|patterns|ask|community|lab|library>` opens that tab.
  - `-VidaSkipWelcome YES` skips the welcome curtain.
  - `-VidaDebugPlus` unlocks Vida+ screens.
  - `-VidaLabSection <experiments|prep|treatments>` and `-vida.librarySection <myLibrary|research>` pick a section.
  - `-VidaOpenMenu YES`, `-VidaOpenShare YES` and `-VidaOpenPaywall YES` open those screens on Today.
  - `-VidaDaylight YES` shows Daylight, and `-VidaHour <0-23>` pins the canvas's time of day.
- **Example:** `xcrun simctl launch <device-id> app.vidalab -VidaPreview YES -VidaSkipWelcome YES -VidaTab patterns`, then `xcrun simctl io <device-id> screenshot out.png`.
- **Don't sign in to the live app.** Agents must not type a password into it, which is why the preview mode exists.
- **Use your own simulator.** Other sessions may be running the iPhone 17 simulators, and one had the Afterhours app open. `xcrun simctl create "VIDA screenshots" "iPhone 17 Pro" com.apple.CoreSimulator.SimRuntime.iOS-27-0` makes one, and a "VIDA screenshots" device already exists. Always pass a device ID, never `booted`.
- **Waits:** give a launch 15 to 20 seconds before screenshotting (the sample data takes time), and wrap `simctl` calls in a timeout. When the Mac is loaded, they hang.
- **iCloud:** the Desktop syncs with iCloud, so git commits and large file reads sometimes time out. Retry, and check `git ls-remote origin rowan-local` after pushing.

## Accounts, privacy and money

- **Accounts:** sign-in is required. The options are Apple, Google, and email with a date-of-birth check for 16+. The birth date is not stored; only `age_confirmed_16_plus` is saved.
- **Encryption:** health entries are encrypted on the device (AES-GCM) before they are uploaded. Never add plaintext symptom, note, meal, experiment or Doctor Prep content to logs, analytics or tables.
- **Community privacy:** community tables can't be encrypted. Never `select *` on them, and never expose `author_id`.
- **In-app purchases:** Vida+ is sold in the app only through Apple In-App Purchase, via RevenueCat, with StoreKit 2 as a fallback.
  - Products: `vida_plus_monthly`, `vida_plus_yearly`, `vida_plus_family`.
  - Entitlement: `plus`.
  - The app may recognise a web purchase through `WebMembershipService`, but it must never link to or mention buying on the website.
- **Website checkout:** website checkout is a Stripe Payment Link handled by the Base44 `stripe-webhook` function, which stays on Base44. The old Wix functions (`create-checkout`, `check-payment-status`, `payments-webhook`) are unused and intentionally not on Supabase.
- **Account deletion:** it is in the app at Settings > Delete account and data, and it runs through the `delete-account` Edge Function.
- **Web members in Settings:** members who bought Vida+ on the website see "Manage your web subscription". It opens `https://vidalab.co/support`, whose FAQ explains cancelling. It never points to the sales page.
- **Privacy manifest:** `PrivacyInfo.xcprivacy` declares seven types, all linked to the user, none used for tracking, all for App Functionality: Health, Fitness (added 2026-09-29 for steps and active energy), Email, Name, User ID, Purchase History, and Other User Content. App Store Connect must match (`docs/APP_STORE_COMPLIANCE.md` §1). Location, the diary and meditation history stay on the device and aren't declared.

## Backend status (2026-09-29)

- **Deployed to live Supabase on 2026-09-28:** 12 website Edge Functions (appointment-concierge, body-weather-forecast, vida-differential, experiment-results, vida-chat, send-reminders, send-weekly-newsletter, send-appointment-reminders, send-appointment-snapshot, newsletter-signup, unsubscribe, flag-community-content). The scheduled ones reject callers without the cron secret.
- **Supabase cron:** send-reminders runs every 30 minutes, send-appointment-reminders hourly, and send-weekly-newsletter Mondays at 02:00 UTC. The first two ran successfully on 2026-09-28 at 22:00 UTC.
- **Base44:** the send-reminders and send-appointment-reminders timers were switched off on 2026-09-28. Only the weekly newsletter timer is still on, and Rowan must switch it off before Monday. The daily Instagram post, the six Google features and website checkout (`stripe-webhook`) stay on Base44.
- **Waiting on Rowan:** turning on `SUPABASE_FUNCTIONS_LIVE` in the website code, removing the placeholder doctor phone numbers (a backup is at `~/Desktop/vida-lab/doctors_backup_2026-09-28.csv` or wherever that folder now lives), and uploading the meditation audio.
- The live vidalab.co privacy, terms and support pages were verified up to date on 2026-09-29.

## House rules

- Don't remove features, and don't redesign approved screens. Change only what was asked.
- Don't use em dashes in any user-facing copy. All 210 were removed on 2026-09-29. The only ones left are four lone "—" no-value placeholders, which are fine.
- Copy should be calm, precise, warm and plain. Avoid alarmist health language and anything that implies a diagnosis.
- Build after every change (Cmd+B). Fix errors with the smallest change that keeps behaviour and design intact.
- Don't touch the RevenueCat dashboard or App Store Connect, and don't deploy to Supabase, unless Rowan asks.
- Don't add third-party packages without asking.
- End every task with a short list of what you changed, with file and line, and anything you couldn't do.

## Launch

The full launch checklist is in `LAUNCH_CHECKLIST.md` at the repo root. Work from it, and tick items off there as they're verified.
