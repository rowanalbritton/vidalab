Work prompt for the next agent run on VIDA LAB (written 2026-09-29). The previous prompt is in docs/archive/XCODE_AGENT_PROMPT_2026-09-29.md.

## Start here

1. Run `git pull origin rowan-local` in `~/Desktop/vida lab/VIDA_LAB_rowan-local`.
2. Read CLAUDE.md, LAUNCH_CHECKLIST.md and docs/AGENT_REPORT_2026-09-29.md, in full. They hold the current state, the design rules, the simulator tips and Rowan's remaining steps.
3. Rowan may be away and unable to approve anything. Work through the tasks below in order, and keep going until they are done.

## Already done (don't redo)

- All tests pass, and a Release archive builds.
- Forest is the default look, with a one-time migration of older saved looks.
- The Today arch is bigger.
- "Add a meal" on Today is fixed.
- Fitness is in the privacy manifest (7 App Privacy types).
- All on-screen em dashes are removed.
- The App Review notes in ASC_PASTE_THIS.md are updated.
- Headlines have the pale moss italic accent (`Vida.headline`).
- Community matches reference 06.
- Patterns shows the constellation first, then the plate (reference 02).
- The Lab Notes recap is fixed for Forest.
- VoiceOver labels are added.
- The web members' manage link opens vidalab.co/support.
- The docs are updated.
- The live privacy, terms and support pages are verified.

## Rules

- Build after every change, and fix what you broke with the smallest change.
- Make small commits. Run `git pull` before each commit, push to rowan-local after each task, and confirm with `git ls-remote origin rowan-local`.
- Keep the approved Forest design and every feature: the six tabs, Community, Research Library, Treatments, Lab Notes, meditation, the diary, the share card and the concierge. Use the Vida tokens, never hard-coded colours.
- No em dashes in user-facing copy.
- No live services and no deploys: no Supabase, Base44, website, RevenueCat or App Store Connect, and no uploads.
- Never print, move or commit keys. Secrets.plist stays gitignored. No new packages.
- Don't sign in to the live app. Use the debug preview mode instead: `-VidaPreview YES -VidaSkipWelcome YES -VidaTab <tab>`.
- If other sessions are using the iPhone 17 simulators, use the existing "VIDA screenshots" simulator or create your own. Always pass a device ID. Wait 15 to 20 seconds after launch before a screenshot, and wrap simctl calls in a timeout.
- Log every task in docs/AGENT_LOG.md with the date, file:line, and anything you couldn't do.

## Tasks

1. **Screen-by-screen Forest check against design-reference/ (00 to 16).**
   - Read design-reference/VIDA-LAB-Xcode-Manual.md first.
   - For every reference screen, screenshot the same screen in the simulator, with the simulator in light mode (Forest must still show), and compare colour, type, spacing, components and copy. Fix differences with the tokens. Make one commit per screen, with before and after screenshots in docs/screenshots/forest-check-<date>/.
   - Screens:
     - Today, including whether the progress card overlaps the bottom of the arch as in 01
     - the Patterns top, threads and plate
     - Ask
     - Community
     - Lab Experiments and Doctor Prep
     - My Library and Research Library
     - the Vida menu
     - the Diary
     - the end of check-in
     - the share card
     - the Appointment Concierge
     - light mode (16)
   - Also check the sheets: check-in, paywall, settings, meditation and the Lab Notes recap.
   - Check the canvas's morning, evening and night light shifts. If the canvas reads the clock, add a debug-only way to set the hour, like the other `-Vida` launch options, and screenshot one screen at each time of day.
   - Log which screens matched and which you changed.

2. **App Store screenshot drafts.**
   - Use the preview mode to capture Today, Patterns, Ask, Lab, Library and the paywall.
   - Take them at 6.9" iPhone (iPhone 17 Pro Max or 18 Pro Max), 6.5" iPhone (an iPhone 11 Pro Max or XS Max device type, if the runtime supports one; otherwise say so) and 13" iPad Pro, in Forest.
   - Save them to docs/screenshots/app-store-draft/<size>/ with clear file names. Don't upload anything.

3. **Final checks.**
   - Re-run VIDALABTests and a Release archive (don't upload), and log the results.

4. **Keep Rowan's App Store steps current.**
   - Update the ordered list in LAUNCH_CHECKLIST.md and the report so it reflects what is now done.
   - Tick only the items you actually verified, each with a dated note.

5. **Report.**
   - Write docs/AGENT_REPORT_<today's date>.md with:
     - what changed (file:line)
     - which screens match the references
     - the test and archive results
     - anything you couldn't do
     - Rowan's remaining steps, in order, with where to do each one
   - Commit, push, and confirm in one line that it's pushed.
