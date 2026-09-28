import SwiftUI

/// A short, swipeable walk through the six tabs and the habits that make them
/// worth opening.
///
/// Shown once automatically when onboarding finishes, and on demand from the
/// first-week card and Settings. Every page answers two questions: what is
/// this tab for, and what do I do to get something out of it.
struct AppTourView: View {
    /// `true` when she chose to start a check-in from the last page.
    var onFinish: (_ startCheckIn: Bool) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(FirstWeekGuide.tourSeenKey) private var tourSeen: Bool = false
    @State private var page: Int = 0

    private struct Page: Identifiable {
        let id: Int
        let symbol: String
        let eyebrow: String
        let title: String
        let body: String
        let tip: String?
    }

    private let pages: [Page] = [
        Page(id: 0, symbol: "leaf", eyebrow: "How Vida works",
             title: "A minute a day,\npatterns in a few weeks.",
             body: "You log how you feel. Vida compares the days and shows you what tends to move together, so you can bring real evidence to your next appointment.",
             tip: nil),
        Page(id: 1, symbol: RootTab.home.symbol, eyebrow: RootTab.home.title,
             title: "Check in twice a day.",
             body: "Today is where you log. The morning check-in is two questions about sleep and energy. The evening one covers the rest of the day.",
             tip: "Short check-ins every day are worth more than long ones now and then."),
        Page(id: 2, symbol: RootTab.patterns.symbol, eyebrow: RootTab.patterns.title,
             title: "Your signals, connected.",
             body: "Once you've logged about two weeks, the Pattern Map shows which signals rise and fall together, like poor sleep and next-day pain.",
             tip: "Patterns are correlations in your own data, not a diagnosis."),
        Page(id: 3, symbol: RootTab.ask.symbol, eyebrow: RootTab.ask.title,
             title: "Questions, answered\nfrom research.",
             body: "Ask about symptoms, tests or conditions. Answers come from a cited library first, with every source shown.",
             tip: "Five free questions a day. Vida+ makes them unlimited."),
        Page(id: 4, symbol: RootTab.community.symbol, eyebrow: RootTab.community.title,
             title: "People who get it.",
             body: "Read and share experiences with other members. You choose the name you post under, and you can report posts or block anyone.",
             tip: "Posts are visible to other members, so leave out anything that identifies you."),
        Page(id: 5, symbol: RootTab.lab.symbol, eyebrow: RootTab.lab.title,
             title: "Test a change.\nPrepare for a visit.",
             body: "Experiments let you try one change and see whether it helps. Doctor Prep turns your tracking into notes and questions for your next appointment.",
             tip: nil),
        Page(id: 6, symbol: RootTab.library.symbol, eyebrow: RootTab.library.title,
             title: "Science, translated.",
             body: "Plain-language articles on the research behind your symptoms, ranked toward the conditions and goals you chose.",
             tip: "Save anything you want to come back to."),
        Page(id: 7, symbol: "heart.text.square", eyebrow: "Getting the most from Vida",
             title: "Three habits that\nmake it work.",
             body: "Check in morning and evening. Connect Apple Health so sleep and steps fill in on their own. Keep going for two weeks, and your first patterns appear.",
             tip: "Your first-week checklist on Today tracks these for you.")
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        ZStack {
            Vida.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if !isLast {
                        Button("Skip") { finish(startCheckIn: false) }
                            .font(Vida.sans(15, weight: .medium))
                            .foregroundStyle(Vida.inkSoft)
                            .frame(minWidth: 64, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, 24)
                .frame(height: 52)

                TabView(selection: $page) {
                    ForEach(pages) { item in
                        pageView(item)
                            .tag(item.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: page)

                controls
            }
        }
        .onAppear { tourSeen = true }
    }

    private func pageView(_ item: Page) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: item.symbol)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Vida.moss)
                    .frame(width: 64, height: 64)
                    .background(Vida.sage.opacity(0.18), in: Circle())
                    .accessibilityHidden(true)
                    .padding(.bottom, 8)

                Eyebrow(text: item.eyebrow)

                Text(item.title)
                    .font(Vida.serif(34))
                    .foregroundStyle(Vida.forest)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.body)
                    .font(Vida.sans(16))
                    .foregroundStyle(Vida.inkSoft)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                if let tip = item.tip {
                    Label {
                        Text(tip)
                            .font(Vida.sans(14))
                            .foregroundStyle(Vida.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "lightbulb")
                            .foregroundStyle(Vida.moss)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Vida.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Vida.hairline, lineWidth: 0.9)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 12)
            .readableColumn()
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                ForEach(pages) { item in
                    Capsule()
                        .fill(item.id == page ? Vida.forest : Vida.taupe.opacity(0.35))
                        .frame(width: item.id == page ? 20 : 6, height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(page + 1) of \(pages.count)")

            Button {
                if isLast {
                    finish(startCheckIn: true)
                } else {
                    page += 1
                }
            } label: {
                Text(isLast ? "Start a check-in" : "Next")
                    .font(Vida.sans(17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Vida.forest, in: Capsule())
                    .foregroundStyle(Vida.onForest)
            }
            .buttonStyle(PressableStyle())

            if isLast {
                Button("Maybe later") { finish(startCheckIn: false) }
                    .font(Vida.sans(15, weight: .medium))
                    .foregroundStyle(Vida.inkSoft)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 20)
        .readableColumn()
    }

    private func finish(startCheckIn: Bool) {
        tourSeen = true
        onFinish(startCheckIn)
        dismiss()
    }
}
