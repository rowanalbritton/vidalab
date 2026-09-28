import SwiftUI

/// "The plate": this week's signals cultured on a specimen dish.
///
/// Vida's own visual for Patterns, drawn from the lab rather than the sky.
/// Each signal grows as a colony on a glass plate. The closer a colony sits
/// to the centre, the steadier that signal has been over the past seven
/// days; colonies near the rim had a harder week. Colour follows the same
/// reading, from blush (harder) through moss to sky (steadier), and each
/// colony carries one faint growth ring per day she logged it. Everything is
/// computed from her own check-ins; for signals where lower is better, such
/// as pain, the scale is flipped so the centre always means easier.
struct SpecimenPlate: View {
    struct Culture: Identifiable {
        let category: SignalCategory
        /// 0 = harder week, 1 = steadier week.
        let score: Double
        /// Days logged in the past week, 1...7.
        let days: Int
        var id: SignalCategory { category }
    }

    let cultures: [Culture]
    /// When set, this colony is lit and the others step back, as the
    /// chapters beneath the plate scroll past.
    var focus: SignalCategory? = nil
    var onSelect: (SignalCategory) -> Void = { _ in }

    @State private var grown: Bool

    init(
        cultures: [Culture],
        focus: SignalCategory? = nil,
        onSelect: @escaping (SignalCategory) -> Void = { _ in },
        startsGrown: Bool = false
    ) {
        self.cultures = cultures
        self.focus = focus
        self.onSelect = onSelect
        // Still images (share cards) have no appear animation to run.
        _grown = State(initialValue: startsGrown)
    }
    @State private var breathe = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let radius = side / 2 - 6
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                dish(radius: radius)
                    .position(center)

                ForEach(Array(cultures.enumerated()), id: \.element.id) { index, culture in
                    let angle = Angle.degrees(-90 + 360 * Double(index) / Double(max(cultures.count, 1)) + 18)
                    let reach = grown ? (1 - culture.score) : 0.05
                    let distance = radius * (0.1 + 0.68 * reach)
                    let dimmed = focus != nil && focus != culture.category
                    Button { onSelect(culture.category) } label: {
                        colony(culture)
                    }
                    .buttonStyle(PressableStyle())
                    .scaleEffect(focus == culture.category ? 1.18 : 1)
                    .opacity(dimmed ? 0.28 : 1)
                    .animation(Vida.Motion.settle, value: focus)
                    .position(
                        x: center.x + distance * cos(angle.radians),
                        y: center.y + distance * sin(angle.radians)
                    )
                    .accessibilityLabel("\(culture.category.title), \(Self.phrase(for: culture.score)), logged \(culture.days) of the last 7 days")
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            guard !reduceMotion else {
                grown = true
                return
            }
            withAnimation(.spring(duration: 1.6, bounce: 0.1).delay(0.15)) { grown = true }
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) { breathe = true }
        }
    }

    // MARK: - Dish

    private func dish(radius: CGFloat) -> some View {
        let glass = colorScheme == .dark ? Color.white : Vida.forest
        return ZStack {
            // Agar: a faint, warm pool in the middle of the plate.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Vida.moss.opacity(colorScheme == .dark ? 0.16 : 0.10), Vida.paper.opacity(0.02)],
                        center: .center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )

            // Zones: dashed rings marking steady, mixed and harder.
            ForEach([0.36, 0.62], id: \.self) { fraction in
                Circle()
                    .stroke(glass.opacity(0.12), style: StrokeStyle(lineWidth: 0.7, dash: [2, 5]))
                    .frame(width: radius * 2 * fraction, height: radius * 2 * fraction)
            }

            // Measurement ticks around the inside of the rim.
            ForEach(0..<72, id: \.self) { tick in
                Rectangle()
                    .fill(glass.opacity(tick % 6 == 0 ? 0.35 : 0.14))
                    .frame(width: 0.8, height: tick % 6 == 0 ? 9 : 4)
                    .offset(y: -(radius - 12))
                    .rotationEffect(.degrees(Double(tick) * 5))
            }

            // The glass rim: two fine edges and a highlight where light
            // would catch the curve.
            Circle()
                .stroke(glass.opacity(0.28), lineWidth: 1)
            Circle()
                .stroke(glass.opacity(0.12), lineWidth: 0.6)
                .padding(5)
            Circle()
                .trim(from: 0.58, to: 0.78)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.35 : 0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .blur(radius: 1.2)
                .padding(2)
        }
        .frame(width: radius * 2, height: radius * 2)
    }

    // MARK: - Colony

    private func colony(_ culture: Culture) -> some View {
        let tint = Self.color(for: culture.score)
        let core: CGFloat = 12
        return VStack(spacing: 6) {
            ZStack {
                // Growth rings, one per day logged.
                ForEach(0..<culture.days, id: \.self) { ring in
                    Circle()
                        .stroke(tint.opacity(0.32 - Double(ring) * 0.035), lineWidth: 0.7)
                        .frame(width: core + 10 + CGFloat(ring) * 7, height: core + 10 + CGFloat(ring) * 7)
                }
                // The colony's soft bloom.
                Circle()
                    .fill(RadialGradient(colors: [tint.opacity(0.55), tint.opacity(0)], center: .center, startRadius: 0, endRadius: 30))
                    .frame(width: 60, height: 60)
                    .scaleEffect(breathe ? 1.08 : 0.94)
                Circle()
                    .fill(tint)
                    .frame(width: core, height: core)
                    .overlay {
                        Circle()
                            .fill(Color.white.opacity(0.7))
                            .frame(width: 4, height: 4)
                            .offset(x: -2, y: -2)
                    }
            }
            .frame(width: 66, height: 66)

            Text(culture.category.title.uppercased())
                .font(Vida.sans(9, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Vida.inkSoft)
                .fixedSize()
        }
        .padding(.top, 14)
        .contentShape(Circle())
    }

    static func color(for score: Double) -> Color {
        score < 0.5
            ? Vida.blush.mix(with: Vida.moss, by: score * 2)
            : Vida.moss.mix(with: Vida.sky, by: (score - 0.5) * 2)
    }

    static func phrase(for score: Double) -> String {
        switch score {
        case ..<0.35: "harder this week"
        case ..<0.65: "mixed this week"
        default: "steadier this week"
        }
    }
}

extension SpecimenPlate {
    /// This week's cultures: up to six signals with any check-ins in the
    /// last seven days, scored from their average.
    @MainActor
    static func cultures(from store: VidaStore) -> [Culture] {
        let candidates: [SignalCategory] = [.sleep, .energy, .mood, .pain, .stress, .focus, .headache, .digestion]
        var result: [Culture] = []
        for category in candidates {
            let values = store.recentValues(for: category, days: 7).map(\.1)
            guard !values.isEmpty else { continue }
            let average = values.reduce(0, +) / Double(values.count)
            var score = category == .sleep ? average / 9.0 : average / 10.0
            if !category.higherIsBetter { score = 1 - score }
            result.append(Culture(category: category, score: min(1, max(0, score)), days: min(7, values.count)))
            if result.count == 6 { break }
        }
        return result
    }

    /// A one-line reading naming the steadiest and the hardest signal.
    static func headline(for cultures: [Culture]) -> String? {
        guard let best = cultures.max(by: { $0.score < $1.score }),
              let worst = cultures.min(by: { $0.score < $1.score }) else { return nil }
        if best.category == worst.category || best.score - worst.score < 0.15 {
            return "An even week across your signals"
        }
        return "\(best.category.title) held steady; \(worst.category.title.lowercased()) had a harder week"
    }
}
