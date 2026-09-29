Read CLAUDE.md and LAUNCH_CHECKLIST.md in the repo root before doing anything. They are the source of truth for this project: where things live, the Forest design system, the six tabs, privacy rules and what is left for launch. Rowan is away for a few hours and can't approve anything, so work through the tasks below in order, one at a time, and keep going until they're done.

Rules for this session:
- Build after every change (Cmd+B) and fix what you broke with the smallest change.
- Don't remove features, redesign approved screens, or change copy beyond what a task says. No em dashes in user-facing text.
- Don't touch Supabase, the website, RevenueCat, App Store Connect or signing. Don't add packages. Never print or commit keys.
- Forest is the default look. Use the Vida tokens, never hard-coded colours.
- Tick each finished item in LAUNCH_CHECKLIST.md, and append a line for it to docs/AGENT_LOG.md with the date, what you changed (file:line), and anything you couldn't do.

Tasks:

1. Tests. Run VIDALABTests (Cmd+U). Fix failures caused by the merge or recent changes (Forest default, diary, Library switch, Vida menu). If a test encodes an old decision that has since changed on purpose (for example, the appearance default is now .dark), update the test, and say so in the log.

2. Release build. Product > Archive with the Release configuration to confirm it compiles for release. Don't upload it. Log any warnings that look like real problems.

3. Outdated docs. Update them so no one is misled:
   - docs/PLATFORM_SOURCE_OF_TRUTH.md: the account is required, Forest is the default, the tabs are the six in CLAUDE.md.
   - docs/APP_STORE_COMPLIANCE.md §4: Apple and Google sign-in both exist now.
   - docs/APP_STORE_COMPLIANCE.md §5: the website sells Vida+ through a Stripe Payment Link. The app never links to or mentions it.

4. Privacy manifest. Check VIDALAB/PrivacyInfo.xcprivacy against what the code actually does: location (only when tapped, not stored), diary (on device only), meditation audio downloads, Ask Vida and OpenAI, Vida+ tools and Anthropic, community posts. Report mismatches in the log rather than guessing. Only fix a clear mismatch.

5. Em dashes in on-screen copy. Replace every em dash in user-facing strings (Text, labels, alerts, accessibility labels, notification text) with a comma, colon, period or parentheses, whichever reads most naturally. Leave code comments alone. Build after each file. Log the count per file.

6. Review notes. Update the review notes in ASC_PASTE_THIS.md to also mention:
   - the diary, which stays on the device
   - the share card
   - the AI-generated meditation voices (Kokoro-82M, not real people)
   - the Community rules, and report and block
   - that sign-in is required, with a demo account supplied
   Keep it plain and short. Rowan will paste it herself.

7. Forest pass. Run every screen reachable from the six tabs and the Vida menu in the simulator, with the simulator in light mode. List any screen, sheet or card that still draws a cream, white or paper background in Forest, or text that is hard to read, and fix it with the tokens (VidaCanvas, .vidaBackground(), Vida.* colours). Include sheets: check-in, diary, share card, paywall, settings, meditation, concierge.

8. Accessibility spot check. Test the largest Dynamic Type size and VoiceOver labels on Today, Patterns, Ask, Community, Lab and Library. Fix clipping and missing labels on icon-only buttons.

9. Design match. The approved reference screens are in design-reference/screens (00 to 16), with the notes in design-reference/VIDA-LAB-Xcode-Manual.md. Read the manual, then compare every reference screen with the same screen in the simulator. Fix differences in colour, type, spacing, components or copy with the VidaTheme tokens, keeping every feature, including Community, Research Library, Treatments, Lab Notes and meditation, which the references may not show. Keep the Forest canvas with its morning, evening and night light shifts. Make one commit per screen, and log which screens matched and which you changed.

10. App Store checklist. Work through LAUNCH_CHECKLIST.md from top to bottom.
    - Do every Agent item.
    - For every You item, verify what can be verified from the code, then write Rowan's exact remaining steps and where to do them (App Store Connect, RevenueCat, the demo account, age rating, App Privacy answers).
    - Cross-check docs/APP_STORE_COMPLIANCE.md against the built app: App Privacy answers, 16+, account deletion, sign-in, and the in-app purchase rules (restore purchases, subscription terms, EULA and privacy links on the paywall, no mention of buying on the web).
    - Also check that the `aps-environment` entitlement (currently "development") becomes "production" in the archived build's signing. Xcode normally does this when exporting for the App Store, so only report it if it doesn't.
    - Tick only the items you actually verified, each with a dated note.
    - Already verified on 2026-09-29: https://vidalab.co/privacy, /terms and /support load real pages with rowan@vidalab.co, 16+, Stripe, Anthropic, meditation and in-app deletion.

11. If time remains: App Store screenshots. Capture Today, Patterns, Ask, Lab, Library and the paywall at 6.9" iPhone, 6.5" iPhone and 13" iPad sizes into docs/screenshots/app-store-draft/. In Debug builds, `-VidaTab <tab> -VidaSkipWelcome YES -VidaDebugPlus` opens a tab directly. Don't upload anything.

12. Final log. At the top of docs/AGENT_LOG.md, list every checklist item as done, verified, or left for Rowan. Put her remaining steps in order, with where to do each one.

When you finish, or if you get stuck on something only Rowan can do, stop and make sure the summary from task 12 is at the top of docs/AGENT_LOG.md. Commit and push to rowan-local after each task, then confirm in one line that it's pushed.
