# Agent report, 2026-09-30 (overnight run)

Claude worked on Rowan's Mac with xcodebuild and its own simulators ("VIDA screenshots", an iPhone 17 Pro, and "VIDA small", an iPhone SE 3rd generation). Everything is on `rowan-local`. Earlier reports: docs/AGENT_REPORT_2026-09-29.md and docs/AGENT_REPORT_2026-09-29-evening.md.

## What changed

- **Today card (Rowan's choice):** it reads "1 of 2", which check-in is open, and has a Check in button (HomeView.swift `todayHero`).
- **Patterns order:** map, then Vida+, then threads, then the plate, as in references 03 and 04 (PatternMapView.swift).
- **Concierge wording:** the brushed-off lines now read "If a test or referral isn't offered." instead of "If you hear A test…", on screen and in the shared snapshot (AppointmentConcierge.swift `ScriptLine.lead`, DoctorPrepView.swift).
- **Largest text sizes:**
  - **Arch photo:** it now fills its window as an overlay (HomePhotoHeader.swift). Before, a wide photo could widen the whole Today page past the screen edge, at any text size.
  - **Check-in card:** it stacks its button at accessibility sizes.
  - **Arch height:** it grows 150 pt at those sizes, so the greeting clears the Field Note.
  - **Switches and tab labels:** the Lab and Library switches and the tab labels shrink to one line instead of breaking mid-word.
- **Copy:**
  - "Vida+ simply removes the ceilings." is now "Vida+ removes the ceilings." (PaywallView.swift).
  - "or just continue" is now "or continue" (CheckInFlow.swift).
- **Preview mode (Debug only):**
  - It includes sample diary pages and a finished Health Snapshot, and hides the first-week guide.
  - It leaves today's evening check-in open.
  - It keeps its data even when the simulator has a signed-in account.
  - New options: `-VidaScrollY`, `-VidaOpenDiary`, `-VidaOpenCheckIn`, `-VidaCheckInJournal`, `-VidaOpenSnapshot` and `-VidaOpenPaywall`.
  - None of these are in the Release binary (checked with `strings`).

## The 17 reference screens

| Ref | Screen | Result |
| --- | --- | --- |
| 00 | Overview | n/a |
| 01 | Today | Matches (arch, Field Note, greeting, "1 of 2" card with Check in, overlapping the arch) |
| 02 | Patterns top | Matches |
| 03 | Vida+ and threads | Matches |
| 04 | The plate | Matches (plate, then a chapter per colony) |
| 05 | Ask | Matches |
| 06 | Community | Matches visually. The feed can't load: see Backend below. |
| 07 | Lab, Experiments | Matches |
| 08 | Lab, Doctor Prep | Matches |
| 09 | My Library | Matches (Rowan's extra cards kept) |
| 10 | Research Library | Matches |
| 11 | Vida menu | Matches |
| 12 | Diary | Matches (date pages, check-in chips, Write today, search) |
| 13 | End of check-in | Matches ("Anything else about today you want to remember?", with Skip and Save to diary) |
| 14 | Share card | Matches |
| 15 | Appointment Concierge | Matches ("If you feel brushed off", with the wording fixed) |
| 16 | Light mode | Matches |

Screenshots: docs/screenshots/forest-check-2026-09-29/ (all screens), accessibility-2026-09-30/ (largest text) and small-phone-2026-09-30/ (iPhone SE).

## App Store screenshot drafts

These are in docs/screenshots/app-store-draft/: iphone-6.9 (1320×2868) and ipad-13. Each set has Today (with the new card), Patterns, Ask, Lab, Library and the paywall, in Forest at an evening hour. The first-week card no longer appears, so nothing needs cropping.

## Accessibility (what the app can honestly claim)

- **Contrast:** body and label colours (ink, inkSoft, taupe, moss and the headline accent) are 4.96 to 15.6 to 1 on every Forest and Daylight surface, which passes WCAG AA. `sage` (2 to 3.7 to 1) is only used for decorative icons next to text, never for text itself.
- **VoiceOver:** every icon-only button has a label. Three were added on 2026-09-29, and the rest already had one.
- **Larger Text:** the six tabs reflow at the largest accessibility size with nothing clipped. Today needed the fixes above.
- **Dark Interface:** Forest is dark by default, and Daylight is available.
- **Reduced Motion:** parallax, scroll effects and drifting backgrounds switch off. This was checked in code, not on a device.
- **Features to tick in App Store Connect:** VoiceOver, Larger Text, Dark Interface, Sufficient Contrast and Reduced Motion. Check APP_STORE_COMPLIANCE.md §6 before ticking, and only tick what you are comfortable standing behind.

## Small phone (iPhone SE, 4.7")

All six tabs and the paywall fit. Today's arch uses its 440 pt minimum, and the check-in card stays visible above the tab bar. No fixes were needed.

## Backend: Community "Couldn't load"

- **Cause:** the live database still has the website's older community columns (`content`, `user_id`, `created_date`). The app, the website and the Base44 server code all expect `body`, `author_id` and `created_at`, so every feed request returns 400 "column body does not exist".
- **What happened when Rowan's go-ahead came:** the approved fix (`20260924140000_reconcile_community_schema.sql`) was run. It stopped, because the live tables have 12 security rules and one depends on the owner column's type. Postgres rolled it back, so nothing changed (0 posts and 0 replies before and after).
- **Needed:** a new migration that drops the 12 community rules, renames the columns, recreates the rules to match the app's version, and applies the owner-column grant. It is waiting on Rowan's "write and apply the full community fix".

## Tests and archive

- **Unit tests:** `** TEST SUCCEEDED **`. 166 passed and none failed.
- **Release archive:** `** ARCHIVE SUCCEEDED **` (not uploaded).

## Rowan's remaining steps, in order

1. Decide on the full community fix above. Until it's done, Community can't load for anyone, App Review included.
2. Tap through the app on your iPhone.
3. Make sure rowan@vidalab.co receives mail, and the Resend domain shows Verified.
4. Switch off the Base44 weekly newsletter timer before Monday 02:00 UTC.
5. Decide on the website switch, the placeholder doctor numbers and the meditation audio upload.
6. Check that the OpenAI and Anthropic accounts have training on API data turned off.
7. Confirm the RevenueCat webhook sends a test with a 200 response.
8. App Store Connect: complete the Paid Applications Agreement, tax and banking.
9. Create the three subscriptions, each with a paywall screenshot (app-store-draft/iphone-6.9/06-paywall.png).
10. Create an In-App Purchase Key, add it to RevenueCat, and set the entitlement to `plus` with all three products.
11. Paste the text from ASC_PASTE_THIS.md.
12. Enter a working demo account.
13. Age rating: 16+.
14. App Privacy: the seven types.
15. Tick the accessibility features listed above.
16. Upload the screenshots for 6.9" iPhone and 13" iPad.
17. Sandbox purchase test on your iPhone, with the StoreKit configuration off in the scheme.
18. Bump the build number, then Archive > Distribute > App Store Connect.
19. Walk the whole app once in TestFlight.
20. Submit for review.


## Later: Community database fixed (Rowan's go-ahead, 2026-09-30 00:33 UTC)

- **Applied:** `supabase/migrations/20260930003000_community_rename_columns_keep_policies.sql` in the website folder, in one transaction.
  - It renames `content` to `body`, `created_date` to `created_at`, `updated_date` to `updated_at`, and `user_id` to `author_id`, on both community tables.
  - The author column keeps its uuid type and its link to accounts.
  - The community tables get their own updated_at trigger.
  - The same 12 security rules are recreated on the new names.
  - Members can no longer read `author_id`.
- **Backup of the old rules:** `supabase/backups/community_policies_2026-09-30.json` in the website folder.
- **Verified:**
  - the new columns and types
  - 6 rules per table
  - the select grant excludes author_id
  - a signed-in member can read the feed
  - signed-out requests are refused (401), as expected, because Community is members-only
  - 0 posts before and after
- **Not verified:** a live write test (create, edit and delete as two members, rolled back) was blocked by the permission check, so it wasn't run. Post once from the app to confirm.
- **Not committed:** the migration and backup files are saved in the website folder. Earlier commits in that folder were blocked, so they, the timer migration and the checkout routing change are all waiting to be committed there.
- **Also missing from the live database:** the app's block-author feature. `community_blocks` and `block_community_author` were never applied, so "Block" will fail until the app migration `20260924120000_add_community_blocks.sql` is adapted, since its table stores text ids and the live author column is a uuid.
