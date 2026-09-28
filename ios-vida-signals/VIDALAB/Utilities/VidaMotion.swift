import Combine
import SwiftUI
import UIKit

// MARK: - Scroll-driven chrome

/// Declared by hand rather than with `@Entry` so the key stays nonisolated
/// under this project's MainActor-by-default setting.
nonisolated private struct VidaScrollOffsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

/// The visible part of the enclosing scroll view: its height, and how much
/// of its top is covered by the navigation bar and status bar.
nonisolated struct VidaViewport: Equatable {
    var height: CGFloat = 0
    var topInset: CGFloat = 0
}

nonisolated private struct VidaViewportKey: EnvironmentKey {
    static let defaultValue = VidaViewport()
}

extension EnvironmentValues {
    /// How far the enclosing Vida screen has scrolled, in points. Zero at
    /// rest, positive when scrolled down, negative while pulling past the top.
    var vidaScrollOffset: CGFloat {
        get { self[VidaScrollOffsetKey.self] }
        set { self[VidaScrollOffsetKey.self] = newValue }
    }

    /// The enclosing scroll view's visible size, for effects that key off
    /// where something sits on screen (pinning, brightening as you read).
    var vidaViewport: VidaViewport {
        get { self[VidaViewportKey.self] }
        set { self[VidaViewportKey.self] = newValue }
    }
}

/// Publishes the scroll view's visible height and top inset to its content.
/// `vidaScrollChrome` applies it; screens with their own toolbar can use
/// `vidaTracksViewport()` directly.
struct ViewportReader: ViewModifier {
    @State private var viewport = VidaViewport()

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: VidaViewport.self) { geometry in
                VidaViewport(
                    height: geometry.containerSize.height.rounded(),
                    topInset: geometry.contentInsets.top.rounded()
                )
            } action: { _, value in
                viewport = value
            }
            .environment(\.vidaViewport, viewport)
    }
}

/// The navigation chrome every tab screen shares, modelled on the way Oura and
/// Apple's own Health app handle a scroll: at rest the bar is invisible and the
/// large serif headline owns the top of the screen; once that headline has
/// scrolled away, a frosted bar fades in carrying a small tracked title.
///
/// Apply it to the `ScrollView` itself, inside the `NavigationStack`.
struct VidaScrollChrome<Badge: View>: ViewModifier {
    let title: String
    /// Scroll distance at which the headline counts as gone.
    var threshold: CGFloat = 72
    /// Optional mark shown beside the small title once it appears.
    var badge: Badge

    @State private var offset: CGFloat = 0
    @State private var collapsed = false

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                // Only the first few hundred points drive any effect, so clamp
                // and round: past that, scrolling costs no view updates at all.
                let raw = geometry.contentOffset.y + geometry.contentInsets.top
                return (min(max(raw, -200), 320) * 2).rounded() / 2
            } action: { _, value in
                offset = value
                let isCollapsed = value > threshold
                if isCollapsed != collapsed {
                    withAnimation(Vida.Motion.chrome) { collapsed = isCollapsed }
                }
            }
            .environment(\.vidaScrollOffset, offset)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        badge
                            .scaleEffect(collapsed ? 1 : 0.6, anchor: .center)
                        Text(title.uppercased())
                            .font(Vida.sans(12, weight: .bold))
                            .tracking(2.4)
                            .foregroundStyle(Vida.forest)
                            .accessibilityAddTraits(.isHeader)
                    }
                    .opacity(collapsed ? 1 : 0)
                    .offset(y: collapsed ? 0 : 6)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackgroundVisibility(collapsed ? .visible : .hidden, for: .navigationBar)
            .modifier(ViewportReader())
    }
}

/// Makes a screen's headline behave like a physical object under the scroll:
/// it drifts up more slowly than the content (parallax), softens and fades as
/// it leaves, and swells very slightly when pulled past the top.
///
/// Reads the offset published by `VidaScrollChrome`, so it only moves on
/// screens that use it. Reduce Motion keeps the fade and drops the movement.
struct ParallaxHeader: ViewModifier {
    @Environment(\.vidaScrollOffset) private var offset
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let pushed = max(0, offset)
        let pulled = max(0, -offset)
        content
            .scaleEffect(reduceMotion ? 1 : 1 + min(pulled, 160) / 1100, anchor: .topLeading)
            .offset(y: reduceMotion ? 0 : pushed * 0.28)
            .opacity(1 - min(1, pushed / 170))
            .blur(radius: reduceMotion ? 0 : min(4, pushed / 45))
    }
}

/// Cards ease in as they enter from the bottom of the screen and ease back as
/// they leave, so the list feels like it has depth rather than sliding past
/// like a sheet of paper. Deliberately small: the eye should feel it, not
/// see it.
struct ScrollReveal: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.scrollTransition(.interactive.threshold(.visible(0.25))) { view, phase in
                view
                    .opacity(1 - abs(phase.value) * 0.4)
                    .scaleEffect(1 - abs(phase.value) * 0.035)
            }
        }
    }
}

extension View {
    /// Frosted, fade-in navigation title plus the scroll offset that drives
    /// `vidaParallaxHeader()`. Apply to the screen's `ScrollView`.
    func vidaScrollChrome(_ title: String, threshold: CGFloat = 72) -> some View {
        modifier(VidaScrollChrome(title: title, threshold: threshold, badge: EmptyView()))
    }

    /// The same chrome with a small mark beside the title, such as the
    /// miniature arch Today's photo settles into.
    func vidaScrollChrome<Badge: View>(
        _ title: String,
        threshold: CGFloat = 72,
        @ViewBuilder badge: () -> Badge
    ) -> some View {
        modifier(VidaScrollChrome(title: title, threshold: threshold, badge: badge()))
    }

    /// Publishes the scroll view's visible size for `vidaBrightenOnScroll()`
    /// on screens that manage their own toolbar.
    func vidaTracksViewport() -> some View {
        modifier(ViewportReader())
    }

    /// Text rests a little dim and comes up to full ink, line by line, as it
    /// rises past the reading line just below the middle of the screen.
    func vidaBrightenOnScroll() -> some View {
        modifier(BrightenOnScroll())
    }

    /// Parallax, fade and pull-to-swell for a screen's large headline.
    func vidaParallaxHeader() -> some View {
        modifier(ParallaxHeader())
    }

    /// Subtle depth as the view enters and leaves a scroll view.
    func vidaScrollReveal() -> some View {
        modifier(ScrollReveal())
    }
}

// MARK: - Brighten as you read

/// The effect on Apple's product pages where a paragraph lights up as you
/// read it: everything above an imaginary reading line (a little below the
/// middle of the screen) is full ink, everything below it rests at about a
/// third, with a soft edge between so it moves line by line rather than as
/// a block. Scrolling back up dims it again. Reduce Motion shows plain text.
struct BrightenOnScroll: ViewModifier {
    @Environment(\.vidaViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frame: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { proxy in
                let f = proxy.frame(in: .scrollView)
                return CGRect(x: 0, y: f.minY.rounded(), width: 0, height: f.height.rounded())
            } action: { frame = $0 }
            .mask { mask }
    }

    private var mask: some View {
        let active = !reduceMotion && viewport.height > 0 && frame.height > 0
        let line = viewport.height * 0.62
        // How much of the paragraph has risen above the reading line.
        let risen = active ? (line - frame.minY) / frame.height : 1
        let soft = 34 / max(frame.height, 1)
        return LinearGradient(
            stops: [
                .init(color: .black, location: min(1, max(0, risen - soft))),
                .init(color: .black.opacity(0.3), location: min(1, max(0, risen + soft)))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Luminous ring

/// The hero ring: a soft gradient stroke with a faint glow beneath it, the
/// visual centre of the Today screen in the way the readiness score is for
/// Oura. It draws itself in on first appearance and eases to new values.
struct LuminousRing: View {
    let progress: Double
    var lineWidth: CGFloat = 9
    var colors: [Color] = [Vida.sage, Vida.moss, Vida.skyDeep]
    /// False for still images, which draw the ring at its value immediately.
    var animated: Bool = true

    @State private var drawn: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var clamped: Double { min(1, max(0, progress)) }

    var body: some View {
        let gradient = AngularGradient(
            colors: colors + [colors.first ?? Vida.moss],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
        ZStack {
            Circle()
                .stroke(Vida.shell.opacity(0.8), lineWidth: lineWidth)

            // Glow: the same arc, blurred. Stronger at night, where light
            // reads as light; barely there by day.
            Circle()
                .trim(from: 0, to: max(0.001, animated ? drawn : clamped))
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .blur(radius: lineWidth * 1.1)
                .opacity(colorScheme == .dark ? 0.55 : 0.28)

            Circle()
                .trim(from: 0, to: max(0.001, animated ? drawn : clamped))
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .onAppear {
            if reduceMotion {
                drawn = clamped
            } else {
                withAnimation(.smooth(duration: 1.2).delay(0.25)) { drawn = clamped }
            }
        }
        .onChange(of: clamped) { _, value in
            withAnimation(reduceMotion ? nil : Vida.Motion.settle) { drawn = value }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Keyboard

/// Tracks whether the software keyboard is on screen, so the floating tab bar
/// can step aside instead of riding up on top of it.
struct KeyboardVisibilityReader: ViewModifier {
    @Binding var isVisible: Bool

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(Vida.Motion.chrome) { isVisible = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(Vida.Motion.chrome) { isVisible = false }
            }
    }
}

extension View {
    func readsKeyboardVisibility(_ isVisible: Binding<Bool>) -> some View {
        modifier(KeyboardVisibilityReader(isVisible: isVisible))
    }
}
