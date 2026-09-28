import CoreText
import SwiftUI
import UIKit

/// Which palette the member wants. Stored in `VidaStore` and applied once at
/// the root — every colour below resolves itself from the trait collection.
nonisolated enum VidaAppearance: String, CaseIterable, Codable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Automatic"
        case .light: "Daylight"
        case .dark: "Forest"
        }
    }

    var caption: String {
        switch self {
        case .system: "Follows your phone"
        case .light: "Warm paper"
        case .dark: "Deep green, easy on the eyes"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    /// Forces the choice onto every window in the app.
    ///
    /// `preferredColorScheme` only governs SwiftUI's own hierarchy. The screens
    /// that are really UIKit underneath — the Mail composer that sends a
    /// report, the photo picker for a profile image, share sheets and system
    /// alerts — keep following the device instead, so choosing Night and then
    /// emailing a report produced a white flash at 3am. Setting the window's
    /// override makes the preference actually global.
    @MainActor
    func applyToWindows() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = interfaceStyle
            }
        }
    }
}

/// VIDA LAB's visual language: warm paper by day, a deep botanical night by
/// dark, and data rendered quietly — closer to a well-made instrument than a
/// mood board. Restraint is the brief: flat surfaces, hairline edges, one
/// accent per idea.
///
/// Every colour is a single adaptive value, so a view never has to ask which
/// mode it is in. Night is deliberately a deep green-charcoal rather than pure
/// black: this app gets opened at 3am by someone in pain, and true black with
/// bright text is the harshest thing a screen can do at that hour.
nonisolated enum Vida {
    /// Canvas behind every screen.
    static let cream = adaptive(0xF7F2E9, 0x0F1C16)
    /// Raised card surface.
    static let paper = adaptive(0xFEFCF7, 0x17281F)
    /// Recessed tone used for meter tracks and empty ring segments.
    static let shell = adaptive(0xE9E3D7, 0x22352B)
    /// Primary brand tone: headline text in one mode, button fill in both.
    static let forest = adaptive(0x1E3A2B, 0xEEF3EC)
    static let moss = adaptive(0x3C6B4F, 0x8CC7A1)
    static let sage = adaptive(0xA3B3A3, 0x5E7A68)
    static let sky = adaptive(0x8FB6CE, 0x86B3CF)
    static let skyDeep = adaptive(0x5D8BA9, 0xA3CDE6)
    /// Caption and metadata text.
    ///
    /// The light value was darkened from #A79987, which measured only 2.5:1
    /// against cream and so failed WCAG AA for the body-sized captions it's
    /// used on throughout the app. #756A59 keeps the warm taupe character and
    /// measures 4.75:1. (Forest 11.1:1, inkSoft 5.4:1, moss 5.5:1 all pass.)
    static let taupe = adaptive(0x756A59, 0x96A399)
    static let blush = adaptive(0xD9B8AE, 0xD3A496)
    static let ink = adaptive(0x243029, 0xEEF3EC)
    static let inkSoft = adaptive(0x5A655E, 0xB0BDB3)
    static let hairline = adaptive(0xD3CBBD, 0x2A3D33)

    /// Reserved for urgency: emergency guidance and destructive confirmations.
    ///
    /// A burnt terracotta rather than a signal red — it reads as serious inside
    /// a cream-and-forest palette without the alarm-clock quality of pure red,
    /// and it clears 4.5:1 against both canvases. Used sparingly on purpose: if
    /// this colour appears everywhere it stops meaning anything.
    static let clay = adaptive(0xA8412B, 0xE08163)

    /// Text that sits on top of a `forest` fill — always the inverse of it.
    static let onForest = adaptive(0xF7F2E9, 0x0F1C16)

    /// Text that sits on top of a `clay` fill.
    static let onClay = adaptive(0xFFF6F2, 0x1A0E0A)

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// Maps a design point size onto the text style with the closest default
    /// size, so scaling stays proportionate: captions grow like captions and
    /// headlines like headlines, rather than everything inflating uniformly.
    private static func metrics(for size: CGFloat) -> UIFontMetrics {
        let style: UIFont.TextStyle
        switch size {
        case ..<12: style = .caption2
        case ..<13: style = .caption1
        case ..<15: style = .footnote
        case ..<16: style = .subheadline
        case ..<18: style = .body
        case ..<21: style = .title3
        case ..<28: style = .title2
        default: style = .title1
        }
        return UIFontMetrics(forTextStyle: style)
    }

    /// Scales a fixed design size for the member's Larger Text setting.
    ///
    /// Every font in the app goes through here. Without it the interface is
    /// pinned to fixed point sizes and ignores Dynamic Type entirely — which,
    /// in an app for people managing chronic illness, excludes exactly the
    /// readers most likely to need larger text.
    ///
    /// Growth is capped at 1.6x rather than the full accessibility range:
    /// beyond that the dense pattern and report layouts stop being readable,
    /// and a legible cap serves people better than a broken screen.
    private static func scaled(_ size: CGFloat) -> CGFloat {
        min(metrics(for: size).scaledValue(for: size), size * 1.6)
    }

    /// Headline face. Now Geist, a contemporary grotesk, instead of a
    /// classic serif: large sizes use its light weight, which is what gives
    /// the app its calm, modern, Oura-like voice. The function keeps its
    /// original name so every existing screen picks up the change. Falls back
    /// to the system font if the font files are missing.
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let face = VidaFonts.headlineFace(size: size, weight: weight)
        return VidaFonts.font(face, size: scaled(size))
            ?? .system(size: scaled(size), weight: weight, design: .default)
    }

    /// Newsreader italic, kept as the one editorial accent: the "LAB" in the
    /// wordmark, her name in the greeting, pull quotes.
    static func serifItalic(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let face = VidaFonts.accentFace(size: size, weight: weight)
        return VidaFonts.font(face, size: scaled(size))
            ?? .system(size: scaled(size), weight: weight, design: .serif).italic()
    }

    /// Hero headline: Geist Light at large sizes. Pair with
    /// `.tracking(Vida.displayTracking)` for the tight, modern set.
    static func display(_ size: CGFloat) -> Font {
        serif(size, weight: .light)
    }

    /// Negative tracking for large Geist headlines.
    static let displayTracking: CGFloat = -0.8

    /// Interface text, labels, body copy and the tab bar (Geist).
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let face = VidaFonts.sansFace(weight: weight)
        return VidaFonts.font(face, size: scaled(size))
            ?? .system(size: scaled(size), weight: weight, design: .default)
    }

    /// Readouts, with tabular figures so numbers never shift as they change.
    static func number(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        let face = VidaFonts.sansFace(weight: weight)
        return (VidaFonts.font(face, size: scaled(size))
            ?? .system(size: scaled(size), weight: weight, design: .default)).monospacedDigit()
    }

    /// Letter-spaced uppercase label used for section eyebrows.
    static let eyebrowTracking: CGFloat = 1.6
    static let cardRadius: CGFloat = 22

    /// Spacing scale. Generous, even rhythm is most of what makes a screen
    /// feel expensive, so screens should reach for these rather than
    /// one-off numbers.
    nonisolated enum Space {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 36
        static let xxl: CGFloat = 52
        /// Side margin for every scrolling screen.
        static let gutter: CGFloat = 22
    }

    /// Motion vocabulary. Springs are slightly underdamped so things settle
    /// rather than stop, which reads as physical and calm.
    nonisolated enum Motion {
        /// Default for taps and toggles: unhurried, almost no bounce.
        static let gentle = Animation.spring(duration: 0.55, bounce: 0.06)
        /// Moving between pages and steps. Slow enough to feel like a breath.
        static let page = Animation.spring(duration: 0.85, bounce: 0.04)
        static let press = Animation.spring(response: 0.42, dampingFraction: 0.82)
        static let settle = Animation.spring(response: 0.55, dampingFraction: 0.86)
        static let reveal = Animation.smooth(duration: 0.8)
        static let chrome = Animation.easeInOut(duration: 0.25)
    }
}

/// Loads the bundled brand fonts (Geist and Newsreader italic, both SIL Open
/// Font License) and resolves a design request to one of the static faces.
///
/// Fonts are registered at runtime rather than through Info.plist, because
/// this project generates its Info.plist from build settings and UIAppFonts
/// cannot be expressed there. Registration happens once, lazily, the first
/// time any Vida font is asked for.
nonisolated enum VidaFonts {
    private static let registered: Bool = {
        let bundle = Bundle.main
        let urls = (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        for url in urls where url.lastPathComponent.hasPrefix("Vida") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return true
    }()

    /// Call once at launch so the first screen paints in the brand faces.
    static func register() { _ = registered }

    /// Cache of which PostScript names actually resolved, so a missing file
    /// costs one lookup rather than one per label.
    private static let lock = NSLock()
    nonisolated(unsafe) private static var availability: [String: Bool] = [:]

    static func font(_ postScriptName: String, size: CGFloat) -> Font? {
        _ = registered
        lock.lock()
        defer { lock.unlock() }
        let isAvailable: Bool
        if let cached = availability[postScriptName] {
            isAvailable = cached
        } else {
            isAvailable = UIFont(name: postScriptName, size: 12) != nil
            availability[postScriptName] = isAvailable
        }
        return isAvailable ? Font.custom(postScriptName, fixedSize: size) : nil
    }

    /// Headlines: light at display sizes so large type stays airy.
    static func headlineFace(size: CGFloat, weight: Font.Weight) -> String {
        if size >= 24 {
            switch weight {
            case .ultraLight, .thin, .light, .regular: return "VidaGeist-Light"
            case .medium: return "VidaGeist-Regular"
            default: return "VidaGeist-Medium"
            }
        }
        return sansFace(weight: weight)
    }

    static func accentFace(size: CGFloat, weight: Font.Weight) -> String {
        if size >= 24 {
            switch weight {
            case .ultraLight, .thin, .light: return "VidaNewsreaderDisplay-LightItalic"
            case .regular: return "VidaNewsreaderDisplay-Italic"
            default: return "VidaNewsreaderDisplay-MediumItalic"
            }
        }
        switch weight {
        case .ultraLight, .thin, .light, .regular: return "VidaNewsreaderText-Italic"
        default: return "VidaNewsreaderText-MediumItalic"
        }
    }

    static func sansFace(weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight, .thin, .light: "VidaGeist-Light"
        case .regular: "VidaGeist-Regular"
        case .medium: "VidaGeist-Medium"
        case .semibold: "VidaGeist-SemiBold"
        default: "VidaGeist-Bold"
        }
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Vida.taupe

    var body: some View {
        Text(text.uppercased())
            .font(Vida.sans(11, weight: .semibold))
            .tracking(Vida.eyebrowTracking)
            .foregroundStyle(color)
    }
}

/// Paper surface with a hairline edge and a soft, ambient lift.
///
/// The shadow is two layers tinted with forest rather than grey: a tight one
/// that seats the card on the canvas and a wide, faint one that gives it air.
/// Together they read as depth without reading as "a shadow". At night the
/// shadow disappears (it would be invisible on the dark canvas) and a faint
/// top highlight on the edge does the same job instead.
struct PaperCard: ViewModifier {
    var padding: CGFloat = 20
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Vida.cardRadius, style: .continuous)
        let isDark = colorScheme == .dark
        content
            .padding(padding)
            .background {
                shape
                    .fill(Vida.paper)
                    .shadow(color: Vida.forest.opacity(isDark ? 0 : 0.05), radius: 2, x: 0, y: 1)
                    .shadow(color: Vida.forest.opacity(isDark ? 0 : 0.06), radius: 22, x: 0, y: 12)
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: isDark
                            ? [Color.white.opacity(0.10), Vida.hairline.opacity(0.35)]
                            : [Color.white.opacity(0.9), Vida.hairline.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.7
                )
            }
            .vidaScrollReveal()
    }
}

/// Constrains content to a comfortable reading column and centres it.
///
/// The app is universal, and without this every screen is a phone-width layout
/// stretched across a 13-inch iPad: single sentences running the full width of
/// the display, which is both ugly and genuinely harder to read. Capping the
/// column keeps the editorial rhythm identical on every device, and on iPhone
/// the cap is wider than the screen so nothing changes at all.
struct ReadableColumn: ViewModifier {
    var maxWidth: CGFloat = 620

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func paperCard(padding: CGFloat = 20) -> some View {
        modifier(PaperCard(padding: padding))
    }

    /// Centres content in a reading-width column on iPad and larger windows.
    func readableColumn(maxWidth: CGFloat = 620) -> some View {
        modifier(ReadableColumn(maxWidth: maxWidth))
    }

    /// The canvas used on every screen. See `VidaCanvas`.
    func vidaBackground() -> some View {
        background { VidaCanvas().ignoresSafeArea() }
    }
}

/// The canvas behind every screen.
///
/// Forest (the default) is a deep botanical green that darkens toward the
/// bottom, with a soft pool of moss light at the top and a faint cool pool of
/// sky to one side, the way Oura's backgrounds glow rather than sit flat.
/// Daylight keeps the warm paper canvas with one soft pool of sage.
struct VidaCanvas: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Drives the slow drift of the light pools. Animated by Core Animation
    /// once, on a long repeating ease, so it costs almost nothing.
    @State private var drift = false

    var body: some View {
        // Re-read the hour once a minute so the light follows the day.
        TimelineView(.everyMinute) { context in
            let light = Daylight(date: context.date)
            canvas(light)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 28).repeatForever(autoreverses: true)) { drift = true }
        }
    }

    @ViewBuilder
    private func canvas(_ light: Daylight) -> some View {
        if colorScheme == .dark {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.071, green: 0.137, blue: 0.106), Color(red: 0.039, green: 0.078, blue: 0.059)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(
                    colors: [Color(red: 0.30, green: 0.55, blue: 0.41).opacity(0.38), .clear],
                    center: UnitPoint(x: drift ? 0.66 : 0.8, y: drift ? 0.02 : -0.04),
                    startRadius: 0,
                    endRadius: 460
                )
                RadialGradient(
                    colors: [Vida.skyDeep.opacity(light.cool), .clear],
                    center: UnitPoint(x: drift ? 0.08 : 0, y: drift ? 0.48 : 0.4),
                    startRadius: 0,
                    endRadius: 380
                )
                // Evening warmth: a low, faint ember near the bottom of the
                // screen that only shows late in the day.
                RadialGradient(
                    colors: [Vida.blush.opacity(light.warm), .clear],
                    center: UnitPoint(x: drift ? 0.3 : 0.2, y: 1.05),
                    startRadius: 0,
                    endRadius: 420
                )
            }
        } else {
            ZStack {
                Vida.cream
                LinearGradient(
                    colors: [Vida.paper.opacity(0.75), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                RadialGradient(
                    colors: [Vida.sage.opacity(0.16), .clear],
                    center: UnitPoint(x: drift ? 0.72 : 0.85, y: -0.05),
                    startRadius: 0,
                    endRadius: 420
                )
                RadialGradient(
                    colors: [Vida.sky.opacity(light.cool * 0.8), .clear],
                    center: UnitPoint(x: drift ? 0.06 : 0, y: 0.45),
                    startRadius: 0,
                    endRadius: 340
                )
                RadialGradient(
                    colors: [Vida.blush.opacity(light.warm * 0.8), .clear],
                    center: UnitPoint(x: 0.25, y: 1.05),
                    startRadius: 0,
                    endRadius: 400
                )
            }
        }
    }
}

/// How the canvas light leans through the day: cooler and clearer in the
/// morning, neutral at midday, a little warmer in the evening, and quiet at
/// night. The shifts are small on purpose; the app should feel alive, not
/// change colour.
struct Daylight {
    let cool: Double
    let warm: Double

    init(date: Date) {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: (cool, warm) = (0.16, 0.0)
        case 11..<17: (cool, warm) = (0.10, 0.02)
        case 17..<22: (cool, warm) = (0.06, 0.08)
        default: (cool, warm) = (0.05, 0.04)
        }
    }
}

/// Soft, blurred rise used when pages and steps change: the old content
/// dissolves upward and the new one settles in from below, never a cut.
struct SoftRise: ViewModifier {
    let progress: Double

    func body(content: Content) -> some View {
        content
            .opacity(1 - progress)
            .blur(radius: progress * 8)
            .offset(y: progress * 18)
    }
}

extension AnyTransition {
    static var vidaSoftRise: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: SoftRise(progress: 1), identity: SoftRise(progress: 0)),
            removal: .modifier(active: SoftRise(progress: -0.6), identity: SoftRise(progress: 0))
                .combined(with: .opacity)
        )
    }

    /// Crossfade with a whisper of blur, for swapping whole screens.
    static var vidaDissolve: AnyTransition {
        .modifier(active: DissolveModifier(amount: 1), identity: DissolveModifier(amount: 0))
    }
}

struct DissolveModifier: ViewModifier {
    let amount: Double

    func body(content: Content) -> some View {
        content
            .opacity(1 - amount)
            .blur(radius: amount * 6)
    }
}

/// A quiet progress ring — the app's primary way of showing "how much of this".
struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 7
    var tint: Color = Vida.moss
    var track: Color = Vida.shell
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.004, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.75), value: progress)
    }
}

/// Small horizontal meter used beside numeric readouts.
struct MeterBar: View {
    let fraction: Double
    var tint: Color = Vida.moss
    var width: CGFloat = 42
    var height: CGFloat = 3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Vida.shell)
                .frame(width: width, height: height)
            Capsule()
                .fill(tint)
                .frame(width: width * min(1, max(0.05, fraction)), height: height)
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.6), value: fraction)
    }
}

/// A thin organic leaf mark, kept for the check-in completion moment.
struct LeafMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.midX - w * 0.55, y: rect.maxY - h * 0.35),
            control2: CGPoint(x: rect.midX - w * 0.42, y: rect.minY + h * 0.12)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.midX + w * 0.42, y: rect.minY + h * 0.12),
            control2: CGPoint(x: rect.midX + w * 0.55, y: rect.maxY - h * 0.35)
        )
        path.closeSubpath()
        return path
    }
}

/// The orbit mark, shown as a miniature of the app icon.
///
/// The glyph is cream-on-forest, so it needs its own dark tile to stay legible
/// against the cream canvas — showing it as a small badge also means the mark in
/// the app is the same thing she tapped on her home screen.
struct OrbitMark: View {
    var body: some View {
        Image("Mark")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .accessibilityHidden(true)
    }
}

/// Mark plus wordmark, locked together at a fixed optical ratio.
///
/// The type is drawn rather than shipped flat so it stays sharp, recolours with
/// the theme, and scales with Dynamic Type instead of blurring.
struct VidaLockup: View {
    enum Size { case compact, large }

    var size: Size = .compact
    var showsAttribution: Bool = false

    private var markSize: CGFloat { size == .compact ? 30 : 52 }
    private var typeSize: CGFloat { size == .compact ? 18 : 30 }

    var body: some View {
        HStack(spacing: size == .compact ? 9 : 14) {
            OrbitMark()
                .frame(width: markSize, height: markSize)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: typeSize * 0.24) {
                    Text("VIDA")
                        .font(Vida.serif(typeSize, weight: .medium))
                        .foregroundStyle(Vida.forest)
                    Text("LAB")
                        .font(Vida.serifItalic(typeSize, weight: .medium))
                        .foregroundStyle(Vida.skyDeep)
                }
                .tracking(typeSize * 0.02)

                if showsAttribution {
                    Text("by rowan albritton")
                        .font(Vida.serifItalic(typeSize * 0.38))
                        .foregroundStyle(Vida.moss)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showsAttribution ? "Vida Lab, by Rowan Albritton" : "Vida Lab")
    }
}

/// Small toolbar button that opens the Vida Lab website.
///
/// Replaces the logo in the top-left with something quieter that still points
/// curious users back to the site.
struct VidaSiteButton: View {
    private let url = URL(string: "https://vidalab.co")!

    var body: some View {
        Link(destination: url) {
            Text("vidalab.co")
                .font(Vida.sans(12, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(Vida.forest)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .overlay {
                    Capsule()
                        .strokeBorder(Vida.hairline, lineWidth: 0.8)
                }
        }
        .accessibilityLabel("Visit vidalab.co")
    }
}

struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(Vida.hairline.opacity(0.6))
            .frame(height: 0.7)
    }
}
