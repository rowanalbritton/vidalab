import SwiftUI

/// This week's plate, told as a short scroll story.
///
/// The dish pins below the top bar while a chapter for each colony scrolls
/// up beneath it, in the manner of Apple's product pages. Whichever chapter
/// sits just under the plate lights its colony and dims the rest, and the
/// chapter itself brightens as it arrives and fades as it slides up under
/// the dish. Once the last chapter has passed, the plate lets go and
/// scrolls away with the page. Reduce Motion keeps the plate in place at the
/// top and simply lists the chapters.
struct PlateStory: View {
    let cultures: [SpecimenPlate.Culture]
    var onSelect: (SignalCategory) -> Void = { _ in }

    @Environment(\.vidaViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var width: CGFloat = 0
    /// Top of the whole story, in the scroll view's visible coordinates.
    @State private var top: CGFloat = 0
    /// Each chapter's top edge, in the same coordinates.
    @State private var chapterTops: [SignalCategory: CGFloat] = [:]

    private var plateSide: CGFloat { min(width, 340) }
    private let chapterHeight: CGFloat = 230
    private let gap: CGFloat = 18

    private var pinning: Bool { !reduceMotion && viewport.height > 0 }

    /// Where the plate's top edge rests while it is pinned.
    private var pinLine: CGFloat { viewport.topInset + 8 }

    /// How far the plate has to travel down its own column to stay pinned.
    private var pinOffset: CGFloat {
        guard pinning else { return 0 }
        let travel = CGFloat(max(cultures.count - 1, 0)) * chapterHeight
        return min(travel, max(0, pinLine - top))
    }

    /// The chapter nearest the space just below the pinned plate.
    private var focus: SignalCategory? {
        guard pinning, top < pinLine else { return nil }
        let target = pinLine + plateSide + gap + 30
        return chapterTops.min { abs($0.value - target) < abs($1.value - target) }?.key
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: plateSide + gap)
            ForEach(cultures) { culture in
                chapter(culture)
                    .frame(minHeight: pinning ? chapterHeight : nil, alignment: .top)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.frame(in: .scrollView).minY.rounded()
                    } action: { chapterTops[culture.category] = $0 }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            SpecimenPlate(cultures: cultures, focus: focus, onSelect: onSelect)
                .frame(width: plateSide, height: plateSide)
                .offset(y: pinOffset)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .scrollView).minY.rounded()
        } action: { top = $0 }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width = $0 }
        .sensoryFeedback(.selection, trigger: focus) { _, new in new != nil }
    }

    // MARK: - Chapter

    private func chapter(_ culture: SpecimenPlate.Culture) -> some View {
        let tint = SpecimenPlate.color(for: culture.score)
        let isFocus = focus == nil || focus == culture.category
        let plateBottom = pinLine + plateSide + gap
        let chapterTop = chapterTops[culture.category] ?? .greatestFiniteMagnitude
        // Fade the chapter as it slides up under the dish so the two never
        // overlap on screen.
        let underPlate = pinning ? min(1, max(0, (plateBottom - chapterTop) / 60)) : 0

        return Button { onSelect(culture.category) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle().fill(tint).frame(width: 7, height: 7)
                    Text(culture.category.title.uppercased())
                        .font(Vida.sans(11, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(Vida.taupe)
                }
                Text(SpecimenPlate.phrase(for: culture.score).capitalizedFirst)
                    .font(Vida.display(26))
                    .tracking(Vida.displayTracking)
                    .foregroundStyle(Vida.forest)
                Text(sentence(for: culture))
                    .font(Vida.sans(15))
                    .foregroundStyle(Vida.inkSoft)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .opacity((isFocus ? 1 : 0.32) * (1 - underPlate))
        .animation(Vida.Motion.gentle, value: isFocus)
        .accessibilityHint("Opens \(culture.category.title)")
    }

    private func sentence(for culture: SpecimenPlate.Culture) -> String {
        let logged = "Logged \(culture.days) of the last 7 days"
        switch culture.score {
        case ..<0.35:
            return "\(logged). It sits out toward the rim, the harder end of your week. Tap to see the days behind it."
        case ..<0.65:
            return "\(logged). It sits in the middle ring: some easier days, some harder ones."
        default:
            return "\(logged). It sits close to the centre, one of the steadier parts of your week."
        }
    }
}

private extension String {
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}
