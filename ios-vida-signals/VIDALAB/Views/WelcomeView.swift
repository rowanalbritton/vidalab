import SwiftUI
import UIKit

/// The front door: a still title page the app opens from.
///
/// Deliberately one gesture and nothing else — no marketing, no progress dots,
/// no sign-up pressure. It exists to set the temperature before the first
/// screen of data arrives, because the person opening this app is often about
/// to describe a bad day and deserves a beat of quiet first.
///
/// The whole surface is the target, so nobody has to aim; the button is there
/// for discoverability and for VoiceOver, which never sees a bare tap gesture.
/// The reveal itself belongs to `ContentView`, which owns both sides of it.
struct WelcomeView: View {
    let onEnter: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var breathing = false

    var body: some View {
        ZStack {
            Vida.cream.ignoresSafeArea()
            OrganicBackdrop()

            VStack(spacing: 0) {
                Spacer(minLength: 20)
                hero
                Spacer(minLength: 20)
                enterControl
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 34)
            .readableColumn(maxWidth: 460)
        }
        // The backdrop is decorative, so the tap belongs to the whole screen
        // rather than to any one thing drawn on it.
        .contentShape(.rect)
        .onTapGesture(perform: enter)
        .onAppear {
            appeared = true
            // A slow halo behind the mark is the only motion here, and it is
            // the first thing to go for anyone who has asked for less.
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 26) {
            VidaLockup(size: .hero, showsAttribution: true, stacked: true)
                .background(alignment: .top) { halo }
                .entrance(0, appeared: appeared, reduced: reduceMotion)

            Rectangle()
                .fill(Vida.hairline)
                .frame(width: 44, height: 0.8)
                .entrance(1, appeared: appeared, reduced: reduceMotion)

            Text("A quiet place to notice what your body has been telling you.")
                .font(Vida.serif(21))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .entrance(2, appeared: appeared, reduced: reduceMotion)
        }
    }

    /// A soft bloom behind the mark, so the logo sits in light rather than on
    /// a flat field. Sized and offset to sit under the mark, not the type.
    private var halo: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Vida.sage, .clear],
                    center: .center,
                    startRadius: 2,
                    endRadius: 110
                )
            )
            .frame(width: 230, height: 230)
            .opacity(breathing ? 0.34 : 0.18)
            .blur(radius: 16)
            .offset(y: -62)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: - Entering

    private var enterControl: some View {
        VStack(spacing: 15) {
            Button(action: enter) {
                HStack(spacing: 9) {
                    Text("Enter")
                        .font(Vida.sans(17, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Vida.forest, in: Capsule())
                .foregroundStyle(Vida.onForest)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Enter Vida Lab")
            .accessibilityHint("Opens your day")

            Text("Private by design · grounded in published research")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.taupe)
                .multilineTextAlignment(.center)
        }
        .entrance(3, appeared: appeared, reduced: reduceMotion)
    }

    private func enter() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        onEnter()
    }
}

/// Staged fade-and-rise used to bring the welcome in one element at a time.
///
/// The stagger is what separates "a screen appeared" from "a screen was set" —
/// but it is only ever decoration, so with Reduce Motion on it collapses to a
/// short, nearly simultaneous fade rather than disappearing entirely.
private struct Entrance: ViewModifier {
    let index: Int
    let appeared: Bool
    let reduced: Bool

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduced ? 0 : 16)
            .blur(radius: appeared || reduced ? 0 : 3)
            .animation(animation, value: appeared)
    }

    private var animation: Animation {
        reduced
            ? .easeOut(duration: 0.4).delay(Double(index) * 0.05)
            : .smooth(duration: 0.9).delay(0.15 + Double(index) * 0.16)
    }
}

private extension View {
    func entrance(_ index: Int, appeared: Bool, reduced: Bool) -> some View {
        modifier(Entrance(index: index, appeared: appeared, reduced: reduced))
    }
}

#Preview {
    WelcomeView {}
}
