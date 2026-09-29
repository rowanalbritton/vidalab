# VIDA LAB iOS: the complete redesign manual for Xcode

This manual covers every screen in your app, the ones you already have and the ones added in this redesign, all in the finalized Forest design. The pictures are in the `screens` folder, numbered to match the sections below.

**Nothing is removed.** Every tab, card, button, limit, upgrade prompt and piece of copy in your screenshots stays. Only the look changes: the Forest palette, Geist type, the floating tab bar, the Vida menu, and calmer motion.

---

## 0. Read this first: your Mac has screens GitHub doesn't

I compared your 11 screenshots with the code on GitHub. Most screens match, but three things on your phone are **not on GitHub**, so they must only exist on your Mac:

1. **The Community tab.** This includes topic filters, the compose button, the safety note, and the "Couldn't load" state.
2. **The Library's "My Library / Research Library" switch.** This includes the Research Explorer card, Latest VIDA LAB articles with save and share, and "Search published research".
3. **The six-item tab bar.** It has Today, Patterns, Ask, Community, Lab and Library. GitHub has five items, without Community.

This matters because you shouldn't just switch your Mac to the redesign branch. If you did, Xcode would show the GitHub version, and those three things would seem to disappear. They would still be safe, but they'd be hidden until you switched back. Use one of the two routes below.

### Route A (easiest): send me your Mac version
1. In Xcode, open Source Control, then Commit, and commit everything.
2. Open Source Control, then Push, and push to a new branch called `rowan-local`.
3. Tell me in the thread that it's pushed.

I'll merge the redesign into your version myself and restyle Community and the Research Library to match. Then you pull one branch and build.

### Route B: do it in Xcode yourself
1. Commit your current work on your Mac first, so it's saved.
2. In Terminal, in your `vida-lab` folder:
   ```
   git fetch origin
   git merge origin/claude/project-thread-w34i1j
   ```
3. Git may report conflicts, most likely in these files:
   - `ContentView.swift`
   - `LibraryView.swift`
   - `HomeView.swift`

   Don't resolve them by hand. Paste the prompt in section 6 into Xcode's coding assistant, which will keep both your features and the new design.
4. Clean the build folder (Shift Command K), then Run (Command R) on an iOS 18 simulator.

---

## 1. The finalized design system

Use these tokens everywhere. They already live in `Utilities/VidaTheme.swift` on the redesign branch as `Vida.cream`, `Vida.paper` and so on. Every colour switches automatically between Forest (dark, the default) and Daylight (light).

### Colours

| Token | Forest (dark) | Daylight (light) | Used for |
| --- | --- | --- | --- |
| `Vida.cream` | #0F1C16 | #F7F2E9 | Page background base |
| `Vida.paper` | #17281F | #FEFCF7 | Cards |
| `Vida.shell` | #22352B | #E9E3D7 | Chips, quiet panels, icon circles |
| `Vida.forest` | #EEF3EC | #1E3A2B | Headlines, primary buttons, selected pills |
| `Vida.onForest` | #0F1C16 | #F7F2E9 | Text on primary buttons |
| `Vida.moss` | #8CC7A1 | #3C6B4F | Links, accents, "Worth watching" |
| `Vida.sage` | #5E7A68 | #A3B3A3 | Quiet accents, send button |
| `Vida.sky` / `skyDeep` | #86B3CF / #A3CDE6 | #8FB6CE / #5D8BA9 | Second thread colour, steady signals |
| `Vida.blush` | #D3A496 | #D9B8AE | Cycle, harder weeks |
| `Vida.ink` | #EEF3EC | #243029 | Body text |
| `Vida.inkSoft` | #B0BDB3 | #5A655E | Secondary text |
| `Vida.taupe` | #96A399 | #756A59 | Eyebrows, labels, chevrons |
| `Vida.hairline` | #2A3D33 | #D3CBBD | Card borders, dividers |

**Background.** Every screen sits on `VidaCanvas()`, a deep green gradient with slow drifting pools of moss light. It's cooler in the morning and has a faint warm glow in the evening. Never use a flat colour behind a tab.

### Type

- **Headlines:** Geist Light, 30 to 34 pt, tracking -0.8. The last words go in *Newsreader italic* in pale moss (#BFE3CC in Forest), for example "What connects in *your body*" and "Run a study on *yourself.*"
- **Section titles:** Geist Light, 21 pt, with a small tracked eyebrow above ("THREADS", "START HERE"). Eyebrows are Geist SemiBold, 10 to 11 pt, tracking 1.6 to 2, uppercase, in taupe.
- **Card titles:** Geist Medium, 14 to 16 pt. Library and research article titles use Geist Regular at 17 to 20 pt because they're editorial. Your current app uses a serif there; the finalized design moves them to Geist to match everything else.
- **Body:** Geist Regular, 13 to 15 pt, in inkSoft, with line spacing 4.
- **Top bar title:** Geist SemiBold, 12 pt, tracking 2.4, centred ("PATTERN MAP", "ASK VIDA").

### Shape and spacing

- Cards: corner radius 22, a 1 px hairline border, and a soft forest shadow (`.paperCard()`).
- Quiet panels, such as limits, notes and "How to read this": shell colour at 60% opacity, radius 18, no shadow.
- Primary buttons: a capsule in `Vida.forest` with `Vida.onForest` text, Geist SemiBold 15.
- Chips: capsules. Unselected ones use shell. The selected one uses forest with onForest text.
- Segmented switches (Lab, Library): one capsule track with a sliding forest pill (`matchedGeometryEffect`) and a selection haptic.
- Side gutter: 22 pt. Space between sections: 24 to 36 pt.

### Chrome and motion

- **Top bar:** the Vida orbit mark sits top left on every tab and opens the menu. The screen title fades into a frosted bar as you scroll (`.vidaScrollChrome("Title")`).
- **Tab bar:** a floating glass capsule with an icon and label for each tab. The selected tab gets a forest pill that slides, with a light haptic, and the bar hides when the keyboard is up.
- **Motion:** presses sink and ease back, and tabs dissolve into each other. Cards rise in as they scroll into view. Long paragraphs brighten as you read them. Reduce Motion turns all of this off.

---

## 2. Your existing screens, restyled (images 01 to 10)

Each screen below keeps all of its content. The "Change" lines are the only differences.

**01 Today** (`01-today.png`)
- Keep: the check-in progress, "Something worth noticing" cards, and everything below them.
- Change:
  - Your photo sits in an arched window labelled "FIELD NOTE Nº", and a new photo is picked at each launch.
  - The greeting sits on the photo.
  - The progress ring card overlaps the bottom of the arch.
  - Pattern cards become a snapping carousel that tilts.
  - The share icon and your avatar sit top right, and the Vida menu sits top left.

**02 to 04 Patterns** (`02-patterns-top.png`, `03-patterns-vida-and-threads.png`, `04-patterns-the-plate.png`)
- Keep all of these:
  - The constellation of 10 signals with its "25 connections" centre.
  - The highlighted threads.
  - "Tap any thread or signal".
  - The Vida+ card "22 quieter connections are waiting" with Explore Vida+.
  - "Worth noticing" with the strength dots and day counts.
  - "How to read this".
- Change:
  - The constellation sits on a dark card.
  - Nodes use shell circles with a hairline edge. Selected nodes get a moss, blush or ink ring.
  - Threads draw in moss and sky.
  - The Vida+ card becomes a quiet panel with a forest capsule button.
  - Added below the threads: "This week's plate", which pins while one chapter per signal scrolls past.

**05 Ask Vida** (`05-ask-vida.png`)
- Keep:
  - The headline and intro.
  - "5 of 5 questions left today" with the Vida+ link and the reset note.
  - Start here questions.
  - The ask field with its send button.
- Change: the questions become dark cards with a moss arrow. The field floats above the tab bar in a paper capsule, and the send button is sage.

**06 Community** (`06-community.png`)
- Keep:
  - The compose button, now a forest circle top right.
  - The safety note "A space to compare notes, not medical advice" and its privacy wording.
  - The All, General, Sleep, Mood and Nutrition filters.
  - The posts, and the "Couldn't load" state with pull to refresh.
- Change: it gets a headline in the house style ("Compare notes, *kindly.*") and the tracked "COMMUNITY" top bar title. The note becomes a quiet panel, and the filters use the chip style.
- This screen is only on your Mac, so see section 0.

**07 Lab, Experiments** (`07-lab-experiments.png`)
- Keep:
  - The Experiments and Doctor Prep switch.
  - "Run a study on yourself".
  - The "2 experiments at a time" note.
  - "The labs" cards with days, input and outcome.
- Change: the switch gets a sliding forest pill, the cards turn dark, and the metadata turns moss.

**08 Lab, Doctor Prep** (`08-lab-doctor-prep.png`)
- Keep:
  - "Walk in able to explain it".
  - "Prepare for an appointment" and "About five minutes".
  - The free first snapshot note.
  - "What you'll walk out with", all four items.
- Add: every Health Snapshot now ends with the Appointment Concierge (see screen 15).

**09 Library, My Library** (`09-library-my-library.png`)
- Keep:
  - The My Library and Research Library switch.
  - "Real stories meet real science".
  - The filter chips.
  - "For you" matched cards with read times.
  - "Everything, 24 pieces".
  - The floating search field.
- Change: dark cards with a sage left edge, moss category labels, and larger Geist titles.

**10 Library, Research Library** (`10-library-research-library.png`)
- Keep:
  - "Published research, kept current".
  - The Research Explorer card with "Explore on vidalab.co".
  - "Latest VIDA LAB articles" with date, save, share, summary, source and Read article.
  - "Search published research".
- Change: the same card, chip and search styling as My Library. This screen is only on your Mac, so see section 0.

---

## 3. New screens from the redesign (images 11 to 16)

**11 Vida menu.** Tap the orbit mark at the top left of any tab to open "Everything in Vida". The groups expand and collapse:
- Track and reflect: Check in now, Diary, Your week, Share today.
- Understand: Pattern Map, Ask Vida.
- Learn: The Library, Research Library, Community.
- Care: Appointment Concierge, Vida Experiments.
- You: Settings, vidalab.co.

Community and Research Library need adding to this list once your Mac version is merged. The prompt in section 6 does this.

**12 Diary.** Each day is a page. That day's check-in values appear as small coloured chips beside your writing. There's "Write today" with a daily prompt, and you can write for past days, search, edit and delete. Entries stay on the phone.

**13 End of check-in.** Every check-in ends with an optional step: "Anything else about today you want to remember?" Skip is always there. What you write saves to the diary beside that check-in.

**14 Share card.** Tap share on Today.
- Pick one of three cards: Today, My week (the plate), or Field note.
- Pick a background: one of your 12 photos or your own.
- Choose whether your name shows.
- Share a story-sized 1080 × 1920 image with the VIDA LAB wordmark.

**15 Appointment Concierge.** This sits inside each Health Snapshot:
- "Say it in one breath" is a first-person summary built from the Doctor Prep answers.
- "If you feel brushed off" gives calm replies to say back.

Both are included when the snapshot is shared.

**16 Light mode.** The same layouts in the Daylight palette. Choose it in Settings, Appearance, Daylight.

---

## 4. Copy note: em dashes

Your current screens use em dashes in several places, for example:
- "not medical advice"
- "in plain language"
- "at any scale"
- "the full interview"
- "in the structure a clinician expects"

The mockups show them rewritten with commas or colons, and the wording is otherwise unchanged. On GitHub there are about 190 lines with em dashes across the app's text. The Xcode prompt below includes an optional step to do this across the whole app. Skip that step if you'd rather keep them.

---

## 5. After it builds: checklist

1. The app opens in Forest with Geist type. The tab bar shows six items: Today, Patterns, Ask, Community, Lab and Library.
2. Today shows your photo in the arch, and it changes on relaunch. Scrolling settles the arch into a tiny badge next to TODAY.
3. On Patterns, the constellation, the Vida+ card, the threads and "How to read this" are all there. The plate pins while its chapters scroll.
4. On Ask, the question counter, the starters and the ask field all work.
5. On Community, the filters, compose and pull to refresh work, and it matches image 06.
6. On Lab, both halves of the switch work. A new Health Snapshot shows the Concierge.
7. On Library, both halves of the switch work, and Research Library articles save, share and open.
8. The orbit mark on every tab opens the menu, and every row goes where it says.
9. The share card renders and shares.
10. A check-in's diary step saves into the Diary.
11. Daylight mode reads well, and Reduce Motion calms everything.

---

## 6. Prompt to paste into Xcode's coding assistant

Copy everything in the box.

```
You are working in the VIDA LAB iOS app (SwiftUI, iOS 18 target, Swift 5 language mode), project ios-vida-signals/VIDALAB.xcodeproj.

Goal: every screen uses the finalized "Forest" design, and NO existing feature, screen, tab, button, limit, upgrade prompt or copy is removed. The reference images are in the screens folder of this package (01 to 16). Match them.

Context:
- The redesign lives on git branch claude/project-thread-w34i1j.
- This Mac also has local features that are NOT on that branch:
  - a Community tab (topic filters, compose, safety note, error state)
  - a My Library / Research Library switch inside the Library tab (Research Explorer card, Latest VIDA LAB articles with save/share, "Search published research")
  - a six-item tab bar (Today, Patterns, Ask, Community, Lab, Library)
  These must survive.

Project rules:
- SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor. Value types used off the main actor are marked `nonisolated`. Keep that pattern.
- MemberImportVisibility is on: import every module a file uses.
- File-system synchronized groups: new files in VIDALAB/ join the target automatically. Never edit project.pbxproj to add files.
- Fonts are registered at runtime in VidaFonts.register() (Utilities/VidaTheme.swift). Do not add UIAppFonts.

Steps:
1. Merge. If a merge of claude/project-thread-w34i1j is in progress, resolve every conflict by keeping BOTH sides' features:
   - RootTab keeps all six cases, including community (symbol "person.2", title "Community"). mainShell switches to the Community view. VidaTabBar lays out six items.
   - LibraryView keeps the My Library / Research Library switch and both sections, with the redesign's styling applied.
   - HomeView keeps the redesign's arched window, ring card, carousel, share button and .vidaMenu(), plus any local additions.
2. Apply the design system from Utilities/VidaTheme.swift and Utilities/VidaMotion.swift to the local-only screens (Community, Research Library):
   - Background: .vidaBackground() / VidaCanvas().
   - Headline: Vida.display 32 with tracking Vida.displayTracking, with a Vida.serifItalic accent on the last words.
   - Eyebrows: Eyebrow(text:). Section titles: SectionHeading(eyebrow:title:).
   - Cards: .paperCard(). Quiet panels: Vida.shell.opacity(0.6) in a RoundedRectangle(cornerRadius: 18, style: .continuous).
   - Chips: SelectChip. Primary buttons: forest capsule with onForest text.
   - Chrome: .vidaScrollChrome("Community") / .vidaScrollChrome("Research Library") and .vidaMenu() inside each NavigationStack.
   - The compose button is a 40 pt forest circle with "square.and.pencil" in onForest, top trailing.
   - Research article titles use Vida.display(20). Dates and actions use Vida.moss.
   Use only Vida colour tokens, never hard-coded colours, so Daylight mode keeps working.
3. In Views/VidaMenu.swift:
   - Add VidaFeature cases .community ("Community", "Compare notes with other members", symbol "person.2") and .research ("Research Library", "Latest VIDA LAB articles and the Research Explorer", symbol "doc.text.magnifyingglass").
   - Put both in the "Learn" group after .library.
   - .community switches to the Community tab. .research switches to Library and selects the Research Library segment. Use a small shared @Observable or an environment value for the segment; keep it minimal.
4. Build for an iOS 18 simulator. Fix every error and warning with the smallest change that keeps the design and behaviour. Likely suspects:
   - Sendable / actor isolation on EnvironmentKey defaults and closures
   - rotation3DEffect inside scrollTransition
   - onGeometryChange / onScrollGeometryChange signatures
   - tuple comparison in VidaStore.saveDiary
   - missing imports
5. Optional (only if I say "do the dashes"): in user-facing strings only, replace the em dash character (U+2014) with a comma, colon or full stop so each sentence reads naturally. Never change meaning. Leave code comments alone.
6. Walk the checklist:
   - six tabs
   - Today's arch settles on scroll
   - Patterns: constellation, Vida+ card, threads, "How to read this", then the pinned plate
   - Ask counter and field
   - Community filters and compose
   - Lab switch and Concierge in Health Snapshot
   - Library switch and Research Library save/share
   - Vida menu on every tab
   - share card
   - check-in diary step
   - Daylight mode
   - Reduce Motion
7. Do not change colours, fonts, copy, spacing or layout beyond what these steps ask. Never remove a feature. List every change with file and line.
```

---

## 7. What is in this package

| Item | What it is |
| --- | --- |
| `VIDA-LAB-Xcode-Manual.md` | This manual |
| `screens/00-all-screens.png` | All 16 screens on one sheet |
| `screens/01` to `10` | Your existing screens in the finalized design |
| `screens/11` to `16` | Menu, Diary, check-in diary step, share card, Concierge, light mode |
| `XCODE_HANDOFF.md` | The detailed change log from every design round, with the file map |
| `DESIGN_REFRESH.md` | Round-by-round design notes |
| `website-vs-app.md` | Your website features compared with the app |
| Earlier previews | `round4-preview.png`, `scroll-preview.png`, `menu-share-diary-preview.png`, `type-proof.png` |

These mockups were drawn in a browser to show the design precisely. The real app is built from the Swift code, so icons and a few pixel details will differ slightly on the phone. The sample diary entry and concierge wording are placeholders. On your phone, those screens fill with your own entries and answers.

**Still waiting on you.** The Condition Library, Apothecary, Doctor Finder, research papers and Substack feed need the app to load content from your website. That code is written, but I'm holding it back until you type in the thread, in your own words, that the app may load your website content from base44.app.
