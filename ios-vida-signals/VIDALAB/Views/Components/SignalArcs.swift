import SwiftUI

/// "Signal horizon": this week's signals drawn as glowing orbs resting on a
/// set of luminous arcs, like planets on their orbits over a horizon.
///
/// Each orb sits on its own arc. How far along the arc it rests is how this
/// week has gone for that signal, from harder days on the left to steadier
/// days on the right, computed from her own check-ins (for signals where a
/// lower number is better, such as pain, the scale is flipped so right always
/// means easier). Tapping an orb opens that signal.
struct SignalArcs: View {
    struct Reading: Identifiable {
        let category: SignalCategory
        /// 0 = harder, 1 = steadier.
        let score: Double
        var id: SignalCategory { category }
    }

    let readings: [Reading]
    var onSelect: (SignalCategory) -> Void = { _ in }

    @State private var settled = false
    @State private var glow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// Orbs travel between these angles; the arcs themselves run a little
    /// wider so they fade off past the orbs rather than ending at them.
    private let sweepStart: Double = 228
    private let sweepEnd: Double = 312

    private var spectrum: [Color] {
        [Vida.blush, Vida.sage, Vida.moss, Vida.sky]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GeometryReader { geo in
                let w = geo.size.width
                let outer = min(w * 0.62, 224)
                let center = CGPoint(x: w / 2, y: outer + 16)

                ZStack {
                    // Soft aurora behind the outermost arc.
                    arc(center: center, radius: outer)
                        .stroke(
                            LinearGradient(colors: spectrum, startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 34, lineCap: .round)
                        )
                        .blur(radius: 26)
                        .opacity(glow ? 0.55 : 0.35)

                    ForEach(0..<max(4, readings.count), id: \.self) { index in
                        arc(center: center, radius: radius(index, outer: outer))
                            .stroke(
                                LinearGradient(colors: spectrum, startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: index == 0 ? 1.6 : 1, lineCap: .round)
                            )
                            .opacity(index == 0 ? 0.9 : 0.55 - Double(index) * 0.08)
                    }

                    ForEach(Array(readings.enumerated()), id: \.element.id) { index, reading in
                        let r = radius(index, outer: outer)
                        let score = settled ? reading.score : 0.5
                        let angle = Angle.degrees(sweepStart + (sweepEnd - sweepStart) * score)
                        let point = CGPoint(
                            x: center.x + r * cos(angle.radians),
                            y: center.y + r * sin(angle.radians)
                        )
                        Button { onSelect(reading.category) } label: {
                            orb(reading.category)
                        }
                        .buttonStyle(PressableStyle())
                        .position(point)
                        .accessibilityLabel("\(reading.category.title), \(phrase(for: reading.score))")
                    }
                }
            }
            .frame(height: 240)

            HStack {
                Text("HARDER DAYS")
                    .foregroundStyle(Vida.blush)
                Spacer()
                Text("STEADIER")
                    .foregroundStyle(Vida.skyDeep)
            }
            .font(Vida.sans(11, weight: .semibold))
            .tracking(1.8)
            .accessibilityHidden(true)
        }
        .onAppear {
            guard !reduceMotion else {
                settled = true
                return
            }
            withAnimation(.spring(duration: 1.4, bounce: 0.12).delay(0.2)) { settled = true }
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) { glow = true }
        }
    }

    private func radius(_ index: Int, outer: CGFloat) -> CGFloat {
        outer - CGFloat(index) * outer * 0.16
    }

    private func arc(center: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(sweepStart - 16),
                endAngle: .degrees(sweepEnd + 16),
                clockwise: false
            )
        }
    }

    private func orb(_ category: SignalCategory) -> some View {
        Image(systemName: category.symbol)
            .font(.system(size: 17, weight: .light))
            .foregroundStyle(Vida.forest)
            .frame(width: 50, height: 50)
            .background {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay { Circle().fill(category.accent.opacity(0.28)) }
            }
            .overlay {
                Circle().strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.22 : 0.6), lineWidth: 0.8)
            }
            .shadow(color: category.accent.opacity(0.45), radius: 14)
    }

    private func phrase(for score: Double) -> String {
        switch score {
        case ..<0.35: "harder this week"
        case ..<0.65: "mixed this week"
        default: "steadier this week"
        }
    }
}

extension SignalArcs {
    /// Builds this week's readings from the store: the average of the last
    /// seven days for up to four signals that have any data.
    @MainActor
    static func readings(from store: VidaStore) -> [Reading] {
        let candidates: [SignalCategory] = [.sleep, .energy, .mood, .pain, .stress, .focus, .headache]
        var result: [Reading] = []
        for category in candidates {
            let values = store.recentValues(for: category, days: 7).map(\.1)
            guard !values.isEmpty else { continue }
            let average = values.reduce(0, +) / Double(values.count)
            var score = category == .sleep ? average / 9.0 : average / 10.0
            if !category.higherIsBetter { score = 1 - score }
            result.append(Reading(category: category, score: min(0.97, max(0.03, score))))
            if result.count == 4 { break }
        }
        return result
    }

    /// A one-line summary naming the steadiest and the hardest signal.
    static func headline(for readings: [Reading]) -> String? {
        guard let best = readings.max(by: { $0.score < $1.score }),
              let worst = readings.min(by: { $0.score < $1.score }) else { return nil }
        if best.category == worst.category || best.score - worst.score < 0.15 {
            return "An even week across your signals"
        }
        return "\(best.category.title) holding steady, \(worst.category.title.lowercased()) asking for care"
    }
}
