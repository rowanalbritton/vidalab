# VIDA LAB iOS: context for coding agents

Read this before changing anything. It reflects the state of the project on 2026-09-28.

## What this is

VIDA LAB is a private wellness reflection app for people living with chronic illness. It's built with SwiftUI and is paired with the website vidalab.co. Members log daily check-ins, see patterns in their own data, ask questions of a cited research library, and run small self-experiments. They also prepare for doctor appointments, keep a diary, meditate, and talk in a moderated community.

It is educational and wellness software. It never diagnoses, treats or claims causation. Pattern language must always be phrased as correlation: "worth noticing", "moved together", never "causes".

Owner: Rowan Albritton. Contact everywhere: support@vidalab.co.

## Where things live

- **Repo:** `rowanalbritton/vidalab`
  - `rowan-local` is the current working branch. It holds the merged redesign plus all of Rowan's features.
  - `website` holds the vidalab.co code and the Supabase Edge Functions the site uses.
  - `main` and `app-store-readiness` are older.
- **Mac folder:** `~/Desktop/vida-lab/vida lab/VIDA_LAB_rowan-local/`
  - Open `ios-vida-signals/VIDALAB.xcodeproj`.
  - `VIDA_LAB_RECOVERED` is the pre-merge backup. Do not edit it.
- **Website code on the Mac:** `~/Desktop/vida-lab/vidalabwebsite`
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
- Diary (`DiaryView`, `Models/Diary.swift`). It's on-device, and each day's check-in shows beside the writing.
- Pattern Map: the constellation, Vida+ upsell, threads, and the specimen plate story.
- Ask Vida: answers come from `AskVidaLibrary` first. OpenAI is used only after a one-time consent prompt, through the `ask-vida` Edge Function.
- Doctor Prep: the Health Snapshot plus the Appointment Concierge ("Say it in one breath" and "If you feel brushed off"). The concierge can also find doctors (`CareFinderService`) and save appointment requests.
- Vida+ tools: Body Weather, Vida Differential and Concierge insights. With consent, these send check-in summaries to Anthropic.
- Meditation (`MeditationViews`, `GuidedSessions.swift`). The guide voices are AI-generated with Kokoro-82M. Audio downloads from a Supabase storage bucket, with on-device TTS as a fallback.
- Community: posts, replies, topics, report and block, and guidelines.
- Other screens: Share card (`ShareSnapshotView`, a 1080×1920 story image), Weekly report, Lab Notes, Meals, Body metrics, Apple Health import (read-only), Web access, Welcome and tour.

## Design system (finalized; do not drift)

Tokens live in `Utilities/VidaTheme.swift` and `Utilities/VidaMotion.swift`. Always use the tokens, never hard-coded colours, so light mode keeps working.

- **Look:** Forest (dark green) is the default look. Daylight (cream) is the light alternative, chosen under Settings > Appearance.
- **Colours:** `Vida.cream`, `paper`, `shell`, `forest`, `onForest`, `moss`, `sage`, `sky`, `skyDeep`, `blush`, `ink`, `inkSoft`, `taupe` and `hairline` all adapt to both looks.
- **Type:** Geist for everything, with Newsreader italic reserved for accent words.
  - Headlines use `Vida.display` with `Vida.displayTracking` and a `Vida.serifItalic` accent on the last words.
  - Eyebrows use `Eyebrow(text:)`, and section titles use `SectionHeading(eyebrow:title:)`.
- **Components:**
  - Cards: `.paperCard()`, radius 22.
  - Quiet panels: `Vida.shell` at 60% opacity, radius 18.
  - Chips: `SelectChip`.
  - Primary buttons: a forest capsule with `onForest` text.
  - Segmented switches: a sliding forest pill using `matchedGeometryEffect`.
- **Screen chrome:**
  - Every tab screen applies `.vidaScrollChrome("Title")` and `.vidaMenu()` inside its `NavigationStack`, with `VidaCanvas()` or `.vidaBackground()` behind it.
  - The floating glass tab bar is `VidaTabBar` in `ContentView.swift`.
- **Motion:** use the `Vida.Motion` tokens. Reduce Motion must switch off parallax, scroll effects and drifting backgrounds.
- **Reference:** the images live in `ios-design-refresh/screens` in the project files, numbered 01 to 16.

## Accounts, privacy and money

- **Accounts:** sign-in is required. The options are Apple, Google, and email with a date-of-birth check for 16+. The birth date is not stored; only `age_confirmed_16_plus` is saved.
- **Encryption:** health entries are encrypted on the device (AES-GCM) before they are uploaded. Never add plaintext symptom, note, meal, experiment or Doctor Prep content to logs, analytics or tables.
- **Community privacy:** community tables can't be encrypted. Never `select *` on them, and never expose `author_id`.
- **In-app purchases:** Vida+ is sold in the app only through Apple In-App Purchase, via RevenueCat, with StoreKit 2 as a fallback.
  - Products: `vida_plus_monthly`, `vida_plus_yearly`, `vida_plus_family`.
  - Entitlement: `plus`.
  - The app may recognise a web purchase through `WebMembershipService`, but it must never link to or mention buying on the website.
- **Website checkout:** it stays on Base44's Wix checkout, by Rowan's decision on 2026-09-28. The `create-checkout`, `check-payment-status` and `payments-webhook` functions are intentionally not on Supabase.
- **Account deletion:** it is in the app at Settings > Delete account and data, and it runs through the `delete-account` Edge Function.

## Backend status (2026-09-28)

- The website's Edge Functions were ported from Base44 to Supabase, and the secrets have been added. Deploying 12 of them to live Supabase has been approved, and the timers that send reminders, appointment reminders and the newsletter are being moved at the same time.
- Base44's matching timers are switched off only after each Supabase job has run once successfully.
- The daily Instagram post and the six Google features stay on Base44.

## House rules

- Don't remove features, and don't redesign approved screens. Change only what was asked.
- Don't use em dashes in any user-facing copy.
- Copy should be calm, precise, warm and plain. Avoid alarmist health language and anything that implies a diagnosis.
- Build after every change (Cmd+B). Fix errors with the smallest change that keeps behaviour and design intact.
- Don't touch the RevenueCat dashboard or App Store Connect, and don't deploy to Supabase, unless Rowan asks.
- Don't add third-party packages without asking.
- End every task with a short list of what you changed, with file and line, and anything you couldn't do.

## Launch

The full launch checklist is in `LAUNCH_CHECKLIST.md` at the repo root. Work from it, and tick items off there as they're verified.
