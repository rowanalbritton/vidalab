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

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size), weight: weight, design: .serif)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size), weight: weight, design: .default)
    }

    /// Tabular figures so numbers never shift as values change.
    static func number(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: scaled(size), weight: weight, design: .default).monospacedDigit()
    }

    /// Letter-spaced uppercase label used for section eyebrows.
    static let eyebrowTracking: CGFloat = 1.6
    static let cardRadius: CGFloat = 20
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

/// Flat paper surface with a hairline edge — no drop shadow, no gloss.
struct PaperCard: ViewModifier {
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: Vida.cardRadius, style: .continuous)
                    .fill(Vida.paper)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Vida.cardRadius, style: .continuous)
                    .strokeBorder(Vida.hairline.opacity(0.5), lineWidth: 0.7)
            }
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

    /// The calm paper background used on every screen. Deliberately flat —
    /// atmosphere comes from the warmth of the canvas, not from gradients.
    func vidaBackground() -> some View {
        background {
            ZStack {
                Vida.cream
                LinearGradient(
                    colors: [Vida.paper.opacity(0.75), .clear],
                    startPoint: .top,
                    endPoint: .center
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
    enum Size { case compact, large, hero }

    var size: Size = .compact
    var showsAttribution: Bool = false
    /// Stacks the mark above the type. Side by side the lockup reads as a
    /// header; stacked it reads as a title page, which is what the welcome
    /// screen wants.
    var stacked: Bool = false

    private var markSize: CGFloat {
        switch size {
        case .compact: 30
        case .large: 52
        case .hero: 88
        }
    }

    private var typeSize: CGFloat {
        switch size {
        case .compact: 18
        case .large: 30
        case .hero: 38
        }
    }

    private var spacing: CGFloat {
        switch size {
        case .compact: 9
        case .large: 14
        case .hero: 22
        }
    }

    var body: some View {
        Group {
            if stacked {
                VStack(spacing: spacing) {
                    mark
                    wordmark(alignment: .center)
                }
            } else {
                HStack(spacing: spacing) {
                    mark
                    wordmark(alignment: .leading)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showsAttribution ? "Vida Lab, by Rowan Albritton" : "Vida Lab")
    }

    private var mark: some View {
        OrbitMark()
            .frame(width: markSize, height: markSize)
    }

    private func wordmark(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            HStack(spacing: typeSize * 0.24) {
                Text("VIDA")
                    .font(Vida.serif(typeSize, weight: .medium))
                    .foregroundStyle(Vida.forest)
                Text("LAB")
                    .font(Vida.serif(typeSize, weight: .medium))
                    .italic()
                    .foregroundStyle(Vida.skyDeep)
            }
            .tracking(typeSize * 0.02)

            if showsAttribution {
                Text("by rowan albritton")
                    .font(Vida.serif(typeSize * 0.38))
                    .italic()
                    .foregroundStyle(Vida.moss)
            }
        }
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
