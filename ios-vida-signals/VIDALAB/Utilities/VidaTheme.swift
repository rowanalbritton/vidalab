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
        case .dark: "Night"
        }
    }

    var caption: String {
        switch self {
        case .system: "Follows your phone"
        case .light: "Warm paper"
        case .dark: "Easier at 3am"
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
    static let cream = adaptive(0xF7F2E9, 0x121713)
    /// Raised card surface.
    static let paper = adaptive(0xFEFCF7, 0x1A201B)
    /// Recessed tone used for meter tracks and empty ring segments.
    static let shell = adaptive(0xE9E3D7, 0x28302A)
    /// Primary brand tone: headline text in one mode, button fill in both.
    static let forest = adaptive(0x1E3A2B, 0xE4EDE2)
    static let moss = adaptive(0x3C6B4F, 0x86C09A)
    static let sage = adaptive(0xA3B3A3, 0x5C6F60)
    static let sky = adaptive(0x8FB6CE, 0x7FA9C4)
    static let skyDeep = adaptive(0x5D8BA9, 0x9CC6E0)
    /// Caption and metadata text.
    ///
    /// The light value was darkened from #A79987, which measured only 2.5:1
    /// against cream and so failed WCAG AA for the body-sized captions it's
    /// used on throughout the app. #756A59 keeps the warm taupe character and
    /// measures 4.75:1. (Forest 11.1:1, inkSoft 5.4:1, moss 5.5:1 all pass.)
    static let taupe = adaptive(0x756A59, 0x8D8577)
    static let blush = adaptive(0xD9B8AE, 0xD3A496)
    static let ink = adaptive(0x243029, 0xEAEFE9)
    static let inkSoft = adaptive(0x5A655E, 0xAAB4AC)
    static let hairline = adaptive(0xD3CBBD, 0x333B35)

    /// Reserved for urgency: emergency guidance and destructive confirmations.
    ///
    /// A burnt terracotta rather than a signal red — it reads as serious inside
    /// a cream-and-forest palette without the alarm-clock quality of pure red,
    /// and it clears 4.5:1 against both canvases. Used sparingly on purpose: if
    /// this colour appears everywhere it stops meaning anything.
    static let clay = adaptive(0xA8412B, 0xE08163)

    /// Text that sits on top of a `forest` fill — always the inverse of it.
    static let onForest = adaptive(0xF7F2E9, 0x121713)

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

    /// Brand serif (Newsreader). Sizes of 24pt and up use the display cut,
    /// which has finer hairlines and tighter spacing drawn for headline sizes;
    /// smaller sizes use the text cut, which is sturdier at reading sizes.
    /// Falls back to the system serif if the font files are missing, so the
    /// app never renders a blank label.
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let face = VidaFonts.serifFace(size: size, weight: weight, italic: false)
        return VidaFonts.font(face, size: scaled(size))
            ?? .system(size: scaled(size), weight: weight, design: .serif)
    }

    /// Brand serif, italic. Used for accents: the "LAB" in the wordmark,
    /// pull quotes, and the one soft word in a headline.
    static func serifItalic(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let face = VidaFonts.serifFace(size: size, weight: weight, italic: true)
        return VidaFonts.font(face, size: scaled(size))
            ?? .system(size: scaled(size), weight: weight, design: .serif).italic()
    }

    /// Hero headline: the light display cut at large sizes. This is the
    /// single biggest contributor to the "quiet luxury" feel, the same move
    /// Oura and Aesop make: big, thin, generous type instead of bold type.
    static func display(_ size: CGFloat) -> Font {
        serif(size, weight: .light)
    }

    /// Brand sans (DM Sans) for interface text, labels and body copy.
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let face = VidaFonts.sansFace(weight: weight)
        return VidaFonts.font(face, size: scaled(size))
            ?? .system(size: scaled(size), weight: weight, design: .default)
    }

    /// Readouts. DM Sans for brand consistency; the system fallback keeps
    /// tabular figures so numbers never shift as values change.
    static func number(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        let face = VidaFonts.sansFace(weight: weight)
        return VidaFonts.font(face, size: scaled(size))?.monospacedDigit()
            ?? .system(size: scaled(size), weight: weight, design: .default).monospacedDigit()
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
        static let press = Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let settle = Animation.spring(response: 0.55, dampingFraction: 0.86)
        static let reveal = Animation.smooth(duration: 0.8)
        static let chrome = Animation.easeInOut(duration: 0.25)
    }
}

/// Loads the bundled brand fonts (Newsreader and DM Sans, both SIL Open Font
/// License) and resolves a design request to one of the static faces.
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

    static func serifFace(size: CGFloat, weight: Font.Weight, italic: Bool) -> String {
        if size >= 24 {
            let base = "VidaNewsreaderDisplay-"
            switch (weight, italic) {
            case (.ultraLight, false), (.thin, false), (.light, false): return base + "Light"
            case (.ultraLight, true), (.thin, true), (.light, true): return base + "LightItalic"
            case (.regular, false): return base + "Regular"
            case (.regular, true): return base + "Italic"
            case (_, false): return base + "Medium"
            case (_, true): return base + "MediumItalic"
            }
        }
        let base = "VidaNewsreaderText-"
        switch (weight, italic) {
        case (.ultraLight, false), (.thin, false), (.light, false), (.regular, false): return base + "Regular"
        case (.ultraLight, true), (.thin, true), (.light, true), (.regular, true): return base + "Italic"
        case (.medium, false): return base + "Medium"
        case (_, true): return base + "MediumItalic"
        default: return base + "SemiBold"
        }
    }

    static func sansFace(weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight, .thin, .light, .regular: "VidaDMSans-Regular"
        case .medium: "VidaDMSans-Medium"
        case .semibold: "VidaDMSans-SemiBold"
        default: "VidaDMSans-Bold"
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

    /// The calm paper background used on every screen. Atmosphere comes from
    /// the warmth of the canvas plus one very soft pool of light at the top,
    /// the way a lamp lights a room rather than a gradient filling a poster.
    func vidaBackground() -> some View {
        background {
            ZStack {
                Vida.cream
                LinearGradient(
                    colors: [Vida.paper.opacity(0.75), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                RadialGradient(
                    colors: [Vida.sage.opacity(0.16), .clear],
                    center: UnitPoint(x: 0.85, y: -0.05),
                    startRadius: 0,
                    endRadius: 420
                )
            }
            .ignoresSafeArea()
        }
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
