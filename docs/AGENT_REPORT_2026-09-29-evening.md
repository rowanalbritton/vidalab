# Agent report, 2026-09-29 (evening run)

Claude ran the current XCODE_AGENT_PROMPT.md on Rowan's Mac, using xcodebuild and a dedicated simulator ("VIDA screenshots"). Everything is on `rowan-local`. The earlier report from today is docs/AGENT_REPORT_2026-09-29.md.

## What changed

- **Lab and Library layout** (ContentView.swift LabShell, ResearchLibraryView.swift LibraryShell, and the new Views/Components/SectionSwitchSlot.swift):
  - The section switch now sits under each section's top bar, so the orbit mark comes first and the switch second, as in references 07 to 10. The shells pass the switch down through the environment, and each section places it with `.vidaSectionSwitch()`.
  - Treatments also got the orbit mark (TreatmentLogView.swift).
- **Today:** the progress card rises 64 pt over the foot of the arch, as in reference 01 (HomeView.swift, `todayHero`).
- **Earlier this evening:** Patterns shows the constellation first and the plate below it (reference 02), and web members' "Manage your web subscription" opens vidalab.co/support.
- **Debug-only capture options** (all compiled out of Release builds, see CLAUDE.md):
  - `-VidaLabSection prep` opens Doctor Prep, and `-vida.librarySection research` opens Research Library.
  - `-VidaOpenMenu YES`, `-VidaOpenShare YES` and `-VidaOpenPaywall YES` open those screens.
  - `-VidaDaylight YES` switches to Daylight, and `-VidaHour <0-23>` pins the canvas's time of day.
  - Preview mode now keeps its sample data even when the simulator has a signed-in account.

## Screens against design-reference (00 to 16)

Screenshots are in docs/screenshots/forest-check-2026-09-29/.

| Ref | Screen | Result |
| --- | --- | --- |
| 00 | All screens | Overview only |
| 01 | Today | Matches the layout: arch, Field Note, greeting, and the card overlapping the arch. The card's contents follow the redesign code (ring, days logged, patterns found) rather than the mockup's "1 of 2, Check in" button. Features were kept. |
| 02 | Patterns, top | Matches |
| 03 | Patterns, Vida+ and threads | Not captured separately (below the fold) |
| 04 | Patterns, the plate | Present below the map. The pinned scroll story wasn't captured, because scrolling needs taps. |
| 05 | Ask Vida | Matches |
| 06 | Community | Matches |
| 07 | Lab, Experiments | Matches |
| 08 | Lab, Doctor Prep | Matches, including the Appointment Concierge card |
| 09 | My Library | Matches the header, switch and headline. Your extra cards (Conditions directory, Apothecary, Find a specialist, Rowan's research) sit above "For you", and are kept. |
| 10 | Research Library | Matches |
| 11 | Vida menu | Matches |
| 12 | Diary | Not captured (needs taps) |
| 13 | End of check-in | Not captured (needs taps) |
| 14 | Share card | Matches |
| 15 | Appointment Concierge | Not captured (needs taps) |
| 16 | Light mode | Matches (Today and Patterns in Daylight) |

**Time of day:** the canvas was captured at 8:00, 14:00, 19:00 and 23:00 (canvas-hour-*.png). The morning cool light and the evening ember are subtle, and night is clearly darker. This matches the design intent.

## App Store screenshot drafts

These are in docs/screenshots/app-store-draft/, all in Forest with sample data:
- **iphone-6.9:** iPhone 18 Pro Max, 1320×2868.
- **ipad-13:** iPad Pro 13-inch.

Each set has Today, Patterns, Ask, Lab, Library and the paywall.

There is no 6.5" set, because this iOS 27 simulator runtime has no 6.5" iPhone model. App Store Connect accepts the 6.9" set for iPhone, so a 6.5" set is optional.

The sample person is "Jordan", with generated data. The "Your first week" card still reads 0 of 7 in preview, so crop or scroll past it for the final screenshots.

## Tests and archive

See the end of this file (added after the runs).

## Rowan's remaining steps, in order

1. Tap through the app on your iPhone.
2. Make sure rowan@vidalab.co receives mail, and that the Resend domain shows Verified.
3. Switch off the Base44 weekly newsletter timer before Monday 02:00 UTC. The other two Base44 timers are already off.
4. Decide on the waiting items: turn on the website switch, remove the placeholder doctor numbers, and upload the meditation audio.
5. Check that the OpenAI and Anthropic accounts have training on API data turned off.
6. Confirm the RevenueCat webhook URL, and that Send Test returns 200.
7. App Store Connect, Agreements, Tax and Banking: complete the Paid Applications Agreement.
8. Subscriptions: create one group with the three products, each with a paywall screenshot (docs/screenshots/app-store-draft/iphone-6.9/06-paywall.png works).
9. Create an In-App Purchase Key and add it to RevenueCat. In RevenueCat, set the entitlement to `plus` with all three products attached.
10. Paste the subtitle, the description edits and the review notes from ASC_PASTE_THIS.md.
11. Sign-In Information: a demo account's email and password that really sign in.
12. Age Rating: 16+.
13. App Privacy: the seven types in APP_STORE_COMPLIANCE.md §1.
14. Accessibility declaration: APP_STORE_COMPLIANCE.md §6.
15. Screenshots: upload the drafts (or polished versions) for 6.9" iPhone and 13" iPad.
16. Sandbox purchase test on your iPhone, with the StoreKit configuration off in the scheme.
17. Bump the build number, then Archive > Distribute > App Store Connect.
18. Walk the whole app once in TestFlight.
19. Submit for review.

## Results (end of run)

- **Unit tests:** `** TEST SUCCEEDED **`. 161 passed and none failed, on the VIDA screenshots simulator (iPhone 17 Pro, iOS 27).
- **Release archive:** `** ARCHIVE SUCCEEDED **` (not uploaded). None of the debug launch option names appear in the Release binary, which confirms they are compiled out.

## Later: Today's card now matches the mockup (Rowan's choice)

- The card under the arch shows "1 of 2", which check-in is open, and a Check in button that opens it (HomeView.swift, `todayHero`). When both are done it reads "Both check-ins done today", with no button.
- It replaces the ring-and-stats version. Days logged are still in Settings, and patterns found are on Patterns.
- Preview mode now leaves today's evening check-in open, so the card shows its "1 of 2" state.
- Checked in Forest and Daylight: docs/screenshots/forest-2026-09-29/today-checkin-card.png and today-checkin-card-daylight.png.
- Tests pass: 166 passed and none failed.
