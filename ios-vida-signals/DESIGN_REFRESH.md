# VIDA LAB iOS design refresh

The goal was to make the app feel quieter, richer and more physical, in the spirit of Oura and Hatch, without changing the palette, the voice or the layout Rowan already approved. Everything below builds on the existing `Vida` tokens, so every screen picks up most of it automatically.

## Round two (Forest, Geist, calmer motion)

**Forest is the default.** The app now opens in a deep botanical green that darkens toward the bottom, with a soft pool of moss light at the top and a faint cool pool of sky to one side. Daylight (the warm paper look) and Automatic are still in Settings under Appearance; the dark option is now called Forest.

**Modern type.** Headlines, interface text, numbers and the tab bar use Geist, a contemporary grotesk, set light and slightly tight at large sizes. Newsreader stays only as an italic accent: her name in the greeting, the "LAB" in the wordmark, journal names and pull quotes. DM Sans and the upright Newsreader cuts were removed.

**Calmer motion.** Taps sink a little and ease back instead of snapping, with a softer haptic. Tabs and the Lab segments dissolve into each other with a whisper of blur instead of cutting. Onboarding and orientation steps rise in softly with a blur and settle on a slow spring, and the keyboard on the name step waits for the page to settle before it rises. Sign-in, onboarding and the app fade into each other.

## What changed in round one

**Typography.** The app now renders in the real brand faces instead of the system serif and sans. Newsreader is bundled in two optical cuts: a display cut for anything 24pt and larger (finer hairlines, tighter spacing, drawn for headlines) and a text cut for reading sizes. DM Sans handles interface text. Large headlines use the light display weight through the new `Vida.display(_:)`, which is where most of the "quiet luxury" feeling comes from. Every font still passes through the existing Dynamic Type scaling, and if the font files are ever missing the app falls back to the system faces instead of breaking.

**Floating glass tab bar.** The tab bar is now a frosted capsule that hovers above the content, with a forest pill that slides between tabs and a light selection haptic. Pages scroll all the way to the bottom edge and pass underneath it. It steps aside when the keyboard is up, so the Ask composer sits directly on the keyboard.

**Scroll behavior.** On every tab screen the navigation bar is invisible at rest, so the large serif headline owns the top of the screen. As you scroll, the headline drifts up more slowly than the content, softens and fades, and a frosted bar fades in with the small tracked title (TODAY, PATTERN MAP, and so on). Pulling past the top makes the headline swell very slightly. Cards ease in as they enter from the bottom and ease back as they leave.

**Depth.** Cards keep their paper surface and hairline edge, and gain a two-layer shadow tinted with forest rather than grey, plus a faint top highlight on the edge. At night the shadow is dropped and the highlight does the work. The canvas gets one very soft pool of sage light in the top corner, like a lamp in a room.

**Today hero.** The Today screen opens with the date, a larger light greeting, and a luminous gradient ring showing how much of today is logged, beside two figures: days logged, and either patterns found or days left to a full picture. The ring draws itself in on first open and numbers roll when they change.

**Haptics.** Every button now gives a soft tick on touch-down. Tab and segment changes give a selection tick.

**Accessibility.** Reduce Motion turns off parallax, scroll transitions and the ring draw-in, and keeps simple fades. VoiceOver labels on the tab bar and hero are explicit.

## Files

| File | What it is |
| --- | --- |
| `VIDALAB/Utilities/VidaTheme.swift` | Brand font loading (`VidaFonts`), `Vida.display`, `Vida.serifItalic`, spacing and motion tokens, upgraded `PaperCard` and background |
| `VIDALAB/Utilities/VidaMotion.swift` | New. Scroll chrome, parallax header, scroll reveal, luminous ring, keyboard tracking |
| `VIDALAB/Resources/Fonts/` | New. Geist (5 weights) and Newsreader italic (5 cuts) plus their SIL Open Font License texts |
| `VIDALAB/ContentView.swift` | Floating tab bar, sliding Lab segment control |
| `VIDALAB/Views/HomeView.swift` | Date eyebrow, display greeting, Today hero ring |
| `VIDALAB/Views/OnboardingView.swift` | `PressableStyle` gains the haptic tick |
| `PatternMapView`, `AskVidaView`, `LibraryView`, `ExperimentsView`, `DoctorPrepView` | Scroll chrome and parallax headline |

## Using it in Xcode

1. Pull the branch and open `VIDALAB.xcodeproj`. The project uses synchronized folders, so the new Swift file and the font folder are picked up automatically; there is nothing to drag in.
2. Product, Clean Build Folder, then run on a device or simulator.
3. To confirm the fonts loaded, the Today greeting should be a thin, high-contrast serif rather than the heavier system serif. If it still looks like the system font, select any file in `Resources/Fonts` and check that the VIDALAB target is ticked under Target Membership.

## Using the pieces on new screens

```swift
ScrollView {
    VStack(alignment: .leading, spacing: 28) {
        header.vidaParallaxHeader()   // large headline that drifts and fades
        content.paperCard()           // lift and scroll reveal come with it
    }
}
.vidaScrollChrome("Screen Name")      // frosted bar and fade-in title
```

Headlines: `Vida.display(34)`. Italic accents: `Vida.serifItalic(size)`. Hero rings: `LuminousRing(progress:)`.

## Fonts and licensing

Geist (Vercel) and Newsreader (Production Type) are both under the SIL Open Font License 1.1, which allows bundling in an app. The static files were cut from the Google Fonts variable masters and renamed with a `Vida` prefix so they can never clash with another installed copy. The license texts ship alongside them.
