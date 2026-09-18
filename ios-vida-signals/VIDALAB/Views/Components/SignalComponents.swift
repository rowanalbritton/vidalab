import SwiftUI

/// Compact readout of one signal: label, quiet meter, value, trend.
struct SignalPill: View {
    let category: SignalCategory
    let valueText: String
    let trend: Trend
    var fraction: Double = 0

    enum Trend { case up, down, steady, none }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.symbol)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(category.accent)
                .frame(width: 16)

            Text(category.title)
                .font(Vida.sans(14))
                .foregroundStyle(Vida.ink)

            Spacer(minLength: 8)

            MeterBar(fraction: fraction, tint: category.accent.opacity(0.75))

            Text(valueText)
                .font(Vida.number(13))
                .foregroundStyle(Vida.inkSoft)
                .frame(minWidth: 62, alignment: .trailing)

            Image(systemName: trendSymbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Vida.taupe)
                .frame(width: 9)
                .opacity(trend == .none ? 0 : 1)
        }
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(category.title): \(valueText)\(trendPhrase)")
    }

    private var trendSymbol: String {
        switch trend {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .steady, .none: "minus"
        }
    }

    /// The arrow glyph carries meaning visually; VoiceOver gets it in words.
    private var trendPhrase: String {
        switch trend {
        case .up: ", trending up"
        case .down: ", trending down"
        case .steady: ", steady"
        case .none: ""
        }
    }
}

/// A sparkline drawn as a soft organic curve rather than a chart.
struct Sparkline: View {
    let values: [Double]
    var color: Color = Vida.skyDeep
    var filled: Bool = true
    /// Below this many readings Vida draws nothing and says why.
    ///
    /// A "trend" through two points is a straight line between two moods. It
    /// looks like evidence and isn't, which is the specific failure this app
    /// exists to avoid.
    var minimumSamples: Int = 3

    var body: some View {
        if values.count < minimumSamples {
            notEnoughYet
        } else {
            chart
        }
    }

    private var notEnoughYet: some View {
        HStack(spacing: 7) {
            Image(systemName: "chart.line.flattrend.xyaxis")
                .font(.system(size: 11))
                .foregroundStyle(Vida.sage)
            Text(values.isEmpty
                 ? "No readings yet"
                 : "\(values.count) reading\(values.count == 1 ? "" : "s") · \(minimumSamples) needed for a trend")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.taupe)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Not enough readings to draw a trend yet")
    }

    private var chart: some View {
        GeometryReader { geo in
            let points = normalizedPoints(in: geo.size)
            ZStack {
                if filled, points.count > 1 {
                    curvePath(points, closeIn: geo.size)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.28), color.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                }
                if points.count > 1 {
                    curvePath(points, closeIn: nil)
                        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                if let last = points.last {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .position(last)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trendDescription)
    }

    /// Conveys the shape in words, so the chart doesn't rely on sight or colour.
    private var trendDescription: String {
        guard let first = values.first, let last = values.last else { return "No trend" }
        let change = last - first
        let direction: String
        if abs(change) < 0.5 {
            direction = "roughly steady"
        } else {
            direction = change > 0 ? "trending up" : "trending down"
        }
        return "\(values.count) readings, \(direction), from \(String(format: "%.1f", first)) to \(String(format: "%.1f", last))"
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        let span = max(0.5, maxV - minV)
        return values.enumerated().map { index, value in
            let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
            let y = size.height * (1 - CGFloat((value - minV) / span)) * 0.86 + size.height * 0.07
            return CGPoint(x: x, y: y)
        }
    }

    private func curvePath(_ points: [CGPoint], closeIn size: CGSize?) -> Path {
        var path = Path()
        path.move(to: points[0])
        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            let mid = CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2)
            path.addQuadCurve(to: mid, control: prev)
            if i == points.count - 1 {
                path.addQuadCurve(to: curr, control: curr)
            }
        }
        if let size {
            path.addLine(to: CGPoint(x: points.last?.x ?? 0, y: size.height))
            path.addLine(to: CGPoint(x: points.first?.x ?? 0, y: size.height))
            path.closeSubpath()
        }
        return path
    }
}

/// Section heading in Vida's editorial style.
struct SectionHeading: View {
    let eyebrow: String
    let title: String
    var action: (() -> Void)?
    var actionLabel: String = "See all"

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: eyebrow)
                Text(title)
                    .font(Vida.serif(22))
                    .foregroundStyle(Vida.forest)
            }
            Spacer()
            if let action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(Vida.sans(13, weight: .medium))
                        .foregroundStyle(Vida.moss)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

/// Locked-feature prompt shown to free users.
struct PlusLockCard: View {
    let title: String
    let message: String
    var onUpgrade: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12))
                Text("VIDA+")
                    .font(Vida.sans(11, weight: .bold))
                    .tracking(1.6)
            }
            .foregroundStyle(Vida.moss)

            Text(title)
                .font(Vida.serif(21))
                .foregroundStyle(Vida.forest)
                .fixedSize(horizontal: false, vertical: true)

            Text(message)
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onUpgrade) {
                HStack(spacing: 6) {
                    Text("Explore Vida+")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .font(Vida.sans(14, weight: .semibold))
                .foregroundStyle(Vida.cream)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(Vida.forest, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: Vida.cardRadius, style: .continuous)
                .fill(Vida.sage.opacity(0.14))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Vida.cardRadius, style: .continuous)
                .strokeBorder(Vida.moss.opacity(0.22), lineWidth: 0.7)
        }
    }
}

/// Shows where she stands on the road to trustworthy patterns.
///
/// Replaces the blank panel that used to sit on Home and the Pattern Map for
/// the first two weeks. Every stage names the current day count, says what
/// happens next, and offers one action.
struct PatternProgressCard: View {
    let readiness: PatternReadiness
    var onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: readiness.stage == .noneFound ? "circle.dotted" : "chart.dots.scatter")
                    .font(.system(size: 12))
                Text(readiness.stage == .noneFound ? "NOTHING YET" : "BUILDING YOUR MAP")
                    .font(Vida.sans(11, weight: .semibold))
                    .tracking(1.6)
            }
            .foregroundStyle(Vida.taupe)

            Text(readiness.title)
                .font(Vida.serif(22))
                .foregroundStyle(Vida.forest)
                .fixedSize(horizontal: false, vertical: true)

            Text(readiness.message)
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            if readiness.stage != .noneFound {
                dayMeter
            }

            if let suggestion = readiness.suggestion {
                Text(suggestion)
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Vida.sage.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button(action: onAction) {
                HStack(spacing: 6) {
                    Text(readiness.actionLabel)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .font(Vida.sans(14, weight: .semibold))
                .foregroundStyle(Vida.onForest)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
                .background(Vida.forest, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: Vida.cardRadius, style: .continuous)
                .fill(Vida.paper)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Vida.cardRadius, style: .continuous)
                .strokeBorder(Vida.hairline, lineWidth: 0.7)
        }
    }

    /// Fourteen ticks, one per day. Concrete progress beats a percentage when
    /// the unit is "days you showed up".
    private var dayMeter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 3) {
                ForEach(0..<PatternReadiness.target, id: \.self) { index in
                    Capsule()
                        .fill(index < readiness.loggedDays ? Vida.moss : Vida.shell)
                        .frame(height: 7)
                }
            }
            HStack {
                Text("\(readiness.loggedDays) of \(PatternReadiness.target) days")
                    .font(Vida.number(12))
                    .foregroundStyle(Vida.forest)
                Spacer()
                if readiness.daysRemaining > 0 {
                    Text("\(readiness.daysRemaining) to go")
                        .font(Vida.sans(12))
                        .foregroundStyle(Vida.taupe)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(readiness.loggedDays) of \(PatternReadiness.target) days logged")
    }
}

/// Non-blocking banner for a billing problem or an ending membership.
///
/// Deliberately never a modal and never a lock. A failed card is a bad week,
/// not grounds for shutting someone out of their own health history — so this
/// informs, offers the fix, and gets out of the way.
struct EntitlementNotice: View {
    let title: String
    let message: String
    var isUrgent: Bool = false
    var actionLabel: String?
    var onAction: (() -> Void)?

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    private var accent: Color { isUrgent ? Vida.clay : Vida.skyDeep }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                // Terracotta vs blue is the only visual difference between
                // "payment failed" and "ends soon", and red/blue is exactly
                // the distinction colour-vision deficiency erases. The glyph
                // carries the severity independently.
                Image(systemName: isUrgent ? "exclamationmark.circle.fill" : "clock")
                    .font(.system(size: 13))
                Text(title)
                    .font(Vida.sans(14, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(accent)

            Text(message)
                .font(Vida.sans(13))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if let actionLabel, let onAction {
                Button(action: onAction) {
                    HStack(spacing: 5) {
                        Text(actionLabel)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(Vida.sans(13, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(minHeight: 44)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Vida.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    accent.opacity(differentiate ? 0.9 : 0.35),
                    lineWidth: differentiate ? 1.6 : 0.9
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isUrgent ? "Needs attention now" : "Notice"). \(title). \(message)")
    }
}

/// Reusable empty state with a quiet, encouraging tone.
struct QuietEmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Vida.sage)
            Text(title)
                .font(Vida.serif(19))
                .foregroundStyle(Vida.forest)
            Text(message)
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 20)
    }
}

/// Her profile photo, or her initial on a quiet sage disc when there isn't one.
struct AvatarView: View {
    let data: Data?
    let name: String
    var size: CGFloat = 44

    private var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "" : String(trimmed.prefix(1)).uppercased()
    }

    var body: some View {
        ZStack {
            Circle().fill(Vida.sage.opacity(0.3))

            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            } else if initial.isEmpty {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: size * 0.55, weight: .light))
                    .foregroundStyle(Vida.moss)
            } else {
                Text(initial)
                    .font(Vida.serif(size * 0.42))
                    .foregroundStyle(Vida.forest)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(Vida.hairline.opacity(0.8), lineWidth: 0.8)
        }
    }
}

/// One half of today on the home screen. Shows what's still open, what's done,
/// and which one Vida is asking for right now.
struct PeriodCheckInRow: View {
    let period: CheckInPeriod
    let isDone: Bool
    let isNext: Bool
    let count: Int
    /// Short line describing what tapping the row actually costs her.
    var promise: String?
    /// Optional escape hatch to the longer flow, shown beneath the row.
    var accessoryLabel: String?
    var accessoryAction: (() -> Void)?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            mainRow

            if let accessoryLabel, let accessoryAction {
                Button(action: accessoryAction) {
                    HStack(spacing: 5) {
                        Text(accessoryLabel)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .font(Vida.sans(13, weight: .medium))
                    .foregroundStyle(Vida.moss)
                    .padding(.top, 10)
                    .padding(.horizontal, 4)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private var mainRow: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isDone ? Vida.moss.opacity(0.16) : Vida.shell.opacity(0.7))
                        .frame(width: 44, height: 44)
                    Image(systemName: isDone ? "checkmark" : period.symbol)
                        .font(.system(size: isDone ? 15 : 17, weight: isDone ? .semibold : .light))
                        .foregroundStyle(isDone ? Vida.moss : Vida.inkSoft)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(period.title)
                            .font(Vida.sans(15, weight: .semibold))
                            .foregroundStyle(Vida.forest)
                        if isNext && !isDone {
                            Text("NOW")
                                .font(Vida.sans(9, weight: .bold))
                                .tracking(1.1)
                                .foregroundStyle(Vida.onForest)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Vida.moss, in: Capsule())
                        }
                    }
                    Text(caption)
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Vida.taupe)
            }
            .paperCard(padding: 18)
            .overlay {
                RoundedRectangle(cornerRadius: Vida.cardRadius, style: .continuous)
                    .strokeBorder(isNext && !isDone ? Vida.moss.opacity(0.4) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(period.title) check-in. \(caption)")
        .accessibilityAddTraits(isDone ? [.isButton, .isSelected] : .isButton)
    }

    private var caption: String {
        if isDone {
            return "\(count) signal\(count == 1 ? "" : "s") logged · tap to add more"
        }
        return promise ?? period.caption
    }
}

/// A rounded chip used for multi-select follow-up answers.
struct SelectChip: View {
    let label: String
    let isSelected: Bool
    var accent: Color = Vida.moss
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Vida.sans(14, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? Vida.cream : Vida.ink)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                // Chips were 38pt tall, below the 44pt minimum. The capsule
                // keeps its drawn size; only the tappable frame grows.
                .frame(minHeight: 44)
                .background {
                    Capsule().fill(isSelected ? accent : Vida.paper)
                }
                .overlay {
                    Capsule().strokeBorder(isSelected ? .clear : Vida.hairline.opacity(0.7), lineWidth: 0.7)
                }
                .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
