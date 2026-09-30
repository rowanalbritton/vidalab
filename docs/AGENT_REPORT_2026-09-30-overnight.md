# Agent report, 2026-09-30 (second overnight run)

This run followed Rowan's overnight list. All app changes are on `rowan-local`. The earlier report from tonight is docs/AGENT_REPORT_2026-09-30.md.

## Results

- **Unit tests:** 175 of 175 pass. 9 of them are new: 7 for tonight's changes and 2 for the Ask filter.
- **UI flow tests:** 9 new tests in VIDALABUITests/VidaFlowTests.swift, all passing:
  - every tab opens
  - the check-in opens and closes
  - the Vida menu opens the Diary
  - the share card opens
  - Ask answers from the library
  - the Health Snapshot shows the Concierge
  - the paywall has Restore purchases and the Terms and Privacy links
  - Settings reaches Delete account (not tapped)
  - sign-in offers Apple, Google and the 16+ date of birth

  The tests never buy, restore, post or delete anything.
- **Launch performance:** the existing launch timing test passes.
- **Release archive:** succeeds (not uploaded). Debug launch options and log messages are absent from the binary.

## Bugs found and fixed

1. **Ask refused its own suggested questions.** "Why am I so exhausted during my period?", a Start here suggestion, matched the diagnosis phrase "am i" and was answered with "Vida can't tell you what you have".
   - "am i" and "is this" now count only at the start of a question (AskGuardrails.swift).
   - Tests check that every suggestion gets answered, and that real diagnosis requests ("Am I sick?", "Is this endometriosis?", "Do I have PCOS?") are still refused.
2. **Missing VoiceOver label:** the avatar button that opens Settings had no label. It now reads "Settings" (HomeView.swift).
3. **Performance:** the pattern analysis ran again on each of about 22 reads per screen. It is now cached until the logs change (VidaStore.swift `links`).
4. **Logs:** every print and NSLog is now debug-only. Error details (which can quote server responses) never reach device logs in Release.

## Checks with nothing to fix

- **Offline:** every network screen shows a calm message instead of hanging.
  - Community: "Couldn't load. Pull to try again."
  - Research Library: an error view with a retry.
  - Vida+ tools: "You seem to be offline. Check your connection and try again."
  - Paywall: "We couldn't reach the App Store just now, so we won't guess at a price."
  - Meditation: falls back to the on-device voice.

  I couldn't switch the network off: the simulator shares the Mac's connection, and turning off your Mac's Wi-Fi is a system setting I'm not allowed to change. This was checked in code and on the Community failure screen.
- **iPad (13"):** Today, Patterns, Ask, Community, Lab, Library, the Diary, the Vida menu, the share card, the check-in and the Health Snapshot all lay out correctly. Sheets open as centred iPad cards and scroll.
- **Copy:** no claims of cause or diagnosis about the member. Every "cause" is general physiology in the research library, such as prostaglandins causing cramps. Pattern language stays phrased as correlation.
- **Secrets.plist:** it has never been in git history and is ignored. It is in the app bundle, which is expected: it holds only the public Supabase anon key and the RevenueCat app key, both designed to live inside apps.

## For Rowan's judgement

- **Diary storage.** Diary entries never leave the phone, since no sync or upload code reads them. On the phone they sit in the app's saved data, which iOS encrypts at its standard level (after the first unlock since restart). The app does not add its own encryption, as it does for backed-up check-ins. The privacy policy only promises "stays on this phone", which is accurate. If you'd like the diary encrypted as strongly as possible on the device, that's a small change (a file with complete file protection). Say if you want it.

## Waiting on Rowan

1. **Community Block.** The migration is written: `supabase/migrations/20260930020000_community_blocks.sql` in the website folder. It adds the private block list, the three functions the app calls, and read rules that hide blocked authors from the person who blocked them. It is adapted to the live uuid ids and the admin check. It has not been applied yet, because Rowan's own "add the block fix" message hadn't reached this Mac when this report was written. Until then, the Block button fails.
2. **Community writes.** Post once from the app to confirm writing works. The two-member rules test was blocked by the permission check.
3. **Website folder commits.** The Community and Block migrations, the rules backup, the timer migration and the checkout routing change are saved in ~/Developer/vida-lab/vidalabwebsite but not committed. Commits in that folder are blocked for this agent.
4. **Earlier items:** the Base44 newsletter timer (before Monday), the website switch, the placeholder doctor numbers, the meditation audio, then the App Store steps in docs/AGENT_REPORT_2026-09-30.md.


## Later: Block fix applied (Rowan's "add the block fix", 2026-09-30)

- **Applied:** `supabase/migrations/20260930020000_community_blocks.sql` (website folder), in one transaction.
- **Verified (read-only):**
  - `community_blocks` exists
  - all 4 functions exist
  - 12 community rules are in place
  - both read rules now hide authors the viewer has blocked (moderators still see everything)
  - members have no direct access to the block list
- **Not verified:** a live block by a signed-in member. That test needs the kind of rolled-back write the permission check blocked earlier, so try Block once from the app.

## Later: more screens checked (working on alone, as Rowan asked)

- **Treatments restyled** (TreatmentLogView.swift). It had the system title font and a stock "sign in" placeholder. It now has the TREATMENTS top-bar title, the headline "Track what you're *trying.*", a quiet-panel sign-in note, and a forest + button, dimmed when signed out.
- **Sign-in headline** now has the italic accent: "Your patterns, *kept private.*"
- **Checked in Forest, no changes needed:** Settings, the weekly report, Meditation, onboarding, the app tour and sign-in. Screenshots are in forest-check-2026-09-29/.
- **New debug-only options:** -VidaOpenSettings, -VidaOpenReport, -VidaOpenMeditation, -VidaShowOnboarding, -VidaShowTour and -VidaShowSignIn.
- **Tests:** 175 unit tests plus the sign-in UI test pass (176 of 176).


## Later: diary locked (Rowan's "lock the diary", 2026-09-30)

- **Its own file:** the diary moved out of the app's shared UserDefaults snapshot into its own file per account, `Application Support/Diary/`. The file and its folder use complete file protection, so iOS keeps them encrypted and unreadable whenever the phone is locked (`Models/DiaryVault.swift`, `VidaStore.swift`).
- **Existing entries:** they move into the vault the first time the app opens, and then leave the snapshot. If the vault can't be written, the diary stays where it was rather than being lost.
- **Locked-phone safety:** if the app ever starts while the phone is locked, the diary is left untouched (never overwritten with an empty list) and opens as soon as the app becomes active.
- **Account deletion** also deletes the diary file.
- **Background readers:** nothing reads the diary in the background (there are no widgets, background refresh or notification handlers).
- **Tests:** 179 of 179 pass, including 4 new ones for the vault.
- **Privacy wording:** unchanged and still accurate ("stays on this phone"). The app now also guarantees it is encrypted whenever the phone is locked.
