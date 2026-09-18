import SwiftUI

/// Accessibility primitives shared across the app.
///
/// These exist centrally rather than as scattered `@Environment` checks so that
/// "does VIDA LAB support Reduce Motion" has one answer instead of forty.
enum VidaMotion {
    /// An animation that becomes no animation when Reduce Motion is on.
    ///
    /// Vestibular triggers are a real symptom for people with migraine, POTS
    /// and long COVID — a drifting background is not a neutral flourish for
    /// this audience specifically.
    static func gentle(_ animation: Animation, reduced: Bool) -> Animation? {
        reduced ? nil : animation
    }
}

extension View {
    /// Applies an animation unless the member has asked for less motion.
    func vidaAnimation<V: Equatable>(_ animation: Animation, value: V, reduced: Bool) -> some View {
        self.animation(reduced ? nil : animation, value: value)
    }
}

/// A status meaning rendered so it never depends on colour alone.
///
/// Differentiate Without Color is not a niche setting here: roughly one in
/// twelve men has some colour vision deficiency, and this app uses green and
/// terracotta to mean "fine" and "needs attention" — the exact pair that
/// red-green deficiency collapses. Every status therefore carries a glyph and
/// a word, with colour as reinforcement rather than the message.
nonisolated enum VidaStatusTone {
    case positive
    case caution
    case urgent
    case neutral

    var symbol: String {
        switch self {
        case .positive: "checkmark.circle.fill"
        case .caution: "clock.fill"
        case .urgent: "exclamationmark.triangle.fill"
        case .neutral: "circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .positive: Vida.moss
        case .caution: Vida.skyDeep
        case .urgent: Vida.clay
        case .neutral: Vida.taupe
        }
    }

    /// Spoken by VoiceOver and shown as text when colour can't be relied on.
    var spokenLabel: String {
        switch self {
        case .positive: "Active"
        case .caution: "Needs attention soon"
        case .urgent: "Needs attention now"
        case .neutral: "Inactive"
        }
    }
}

/// Status badge that stays legible without colour vision.
struct StatusBadge: View {
    let tone: VidaStatusTone
    let text: String
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    var body: some View {
        HStack(spacing: 5) {
            // The glyph is always present, not only when the setting is on:
            // shape plus colour is more legible for everyone, and a layout
            // that shifts based on an accessibility setting is harder to test.
            Image(systemName: tone.symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(Vida.sans(11, weight: .semibold))
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background {
            Capsule().fill(tone.color.opacity(differentiate ? 0.06 : 0.12))
        }
        .overlay {
            // Without colour to carry it, the outline does the separating.
            Capsule().strokeBorder(
                tone.color.opacity(differentiate ? 0.9 : 0),
                lineWidth: differentiate ? 1 : 0
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(text). \(tone.spokenLabel)")
    }
}
