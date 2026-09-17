import SwiftUI

struct PatternDetailView: View {
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let link: PatternLink

    @State private var article: ScienceArticle?
    @State private var showPaywall: Bool = false
    @State private var startedLab: String?

    private var explanation: PatternExplanation { PatternExplainer.explanation(for: link) }
    private var confidence: PatternConfidence { PatternExplainer.confidence(for: link) }
    private var arms: ArmComparison? { PatternExplainer.comparison(for: link, logs: store.visibleLogs) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    hero
                    if let arms { armComparison(arms) }
                    confidenceCard
                    meaningSection
                    triesSection
                    experimentSection
                    tracksCard
                    scienceSection
                    disclaimer
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Vida.sans(15, weight: .medium))
                        .foregroundStyle(Vida.moss)
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
        .sheet(item: $article) { ArticleView(article: $0) }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert("\(startedLab ?? "") started", isPresented: Binding(
            get: { startedLab != nil },
            set: { if !$0 { startedLab = nil } }
        )) {
            Button("Got it") { startedLab = nil }
        } message: {
            Text("You'll find it in the Lab tab. Log both signals each day and Vida will compare the two halves for you.")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "\(confidence.rawValue) · \(link.sampleSize) days", color: Vida.moss)

            Text(PatternExplainer.shortMeaning(for: link))
                .font(Vida.serif(30))
                .foregroundStyle(Vida.forest)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            if let arms {
                Text(PatternExplainer.readout(for: link, comparison: arms))
                    .font(Vida.sans(16))
                    .foregroundStyle(Vida.inkSoft)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(PatternEngine.sentence(for: link, logs: store.visibleLogs))
                    .font(Vida.sans(16))
                    .foregroundStyle(Vida.inkSoft)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    /// The heart of the screen: the same comparison a study would make,
    /// shown as two averages from her own days rather than a coefficient.
    private func armComparison(_ arms: ArmComparison) -> some View {
        let scale = max(arms.highAverage, arms.lowAverage, 1)
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: "Side by side")
                Text("Your \(PatternExplainer.noun(link.b)) on both kinds of day")
                    .font(Vida.sans(14))
                    .foregroundStyle(Vida.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ArmBar(
                label: "\(arms.highLabel) \(PatternExplainer.noun(link.a))",
                days: arms.highDays,
                value: arms.highAverage,
                display: PatternExplainer.format(arms.highAverage, for: link.b),
                fraction: arms.highAverage / scale,
                tint: arms.highArmIsBetter ? Vida.moss : Vida.blush
            )

            ArmBar(
                label: "\(arms.lowLabel) \(PatternExplainer.noun(link.a))",
                days: arms.lowDays,
                value: arms.lowAverage,
                display: PatternExplainer.format(arms.lowAverage, for: link.b),
                fraction: arms.lowAverage / scale,
                tint: arms.highArmIsBetter ? Vida.blush : Vida.moss
            )

            Text("Averages of your logged \(PatternExplainer.noun(link.b)), split at the midpoint of your \(PatternExplainer.noun(link.a)).")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.taupe)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }

    /// How much weight this deserves — and what would earn it more.
    private var confidenceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ConfidenceDots(level: confidence)
                Text(confidence.rawValue)
                    .font(Vida.sans(15, weight: .semibold))
                    .foregroundStyle(Vida.forest)
                Spacer(minLength: 0)
                Text("\(link.sampleSize) days")
                    .font(Vida.number(13))
                    .foregroundStyle(Vida.taupe)
            }

            Text(confidence.blurb)
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HairlineDivider()

            Text(PatternExplainer.nextStep(for: link))
                .font(Vida.sans(13))
                .foregroundStyle(Vida.moss)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }

    /// The part that was missing entirely: why these two might travel together.
    private var meaningSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(eyebrow: "Why this happens", title: "The likely mechanism")
                .padding(.horizontal, 2)

            Text(explanation.mechanism)
                .font(Vida.sans(15))
                .foregroundStyle(Vida.ink)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .paperCard(padding: 20)
        }
    }

    private var triesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(eyebrow: "Where to go next", title: "What you could try")
                .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(explanation.tries.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(Vida.number(12, weight: .semibold))
                            .foregroundStyle(Vida.moss)
                            .frame(width: 22, height: 22)
                            .background(Vida.sage.opacity(0.22), in: Circle())
                        Text(item)
                            .font(Vida.sans(14))
                            .foregroundStyle(Vida.ink)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .paperCard(padding: 20)
        }
    }

    /// Correlation can't establish direction — this is the honest way to test it.
    @ViewBuilder
    private var experimentSection: some View {
        if let template = PatternExplainer.experiment(for: link) {
            let running = store.isRunning(template)
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "Test it properly", color: Vida.moss)

                Text(template.question)
                    .font(Vida.serif(20))
                    .foregroundStyle(Vida.forest)
                    .fixedSize(horizontal: false, vertical: true)

                Text("A connection can't tell you which way the arrow points. A \(template.durationDays)-day lab can get you closer.")
                    .font(Vida.sans(14))
                    .foregroundStyle(Vida.inkSoft)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    guard !running else { return }
                    if store.canStartExperiment {
                        store.start(template)
                        startedLab = template.labName
                    } else {
                        showPaywall = true
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: running ? "checkmark" : "flask")
                            .font(.system(size: 12, weight: .semibold))
                        Text(running ? "Already running in your Lab" : "Start \(template.labName)")
                            .font(Vida.sans(14, weight: .semibold))
                    }
                    .foregroundStyle(running ? Vida.moss : Vida.cream)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(running ? Vida.sage.opacity(0.22) : Vida.forest)
                    )
                }
                .buttonStyle(PressableStyle())
                .disabled(running)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Vida.sky.opacity(0.12), in: RoundedRectangle(cornerRadius: Vida.cardRadius, style: .continuous))
        }
    }

    private var tracksCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow(text: "Both tracks")
            HStack(spacing: 18) {
                trackColumn(link.a)
                trackColumn(link.b)
            }
            Text("Association strength \(String(format: "%.2f", link.magnitude)) of a possible 1.00. Vida only surfaces a connection above 0.35 with at least six overlapping days.")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.taupe)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }

    private func trackColumn(_ category: SignalCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: category.symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(category.accent)
                Text(category.title)
                    .font(Vida.sans(12, weight: .medium))
                    .foregroundStyle(Vida.inkSoft)
            }
            Sparkline(values: store.recentValues(for: category, days: 21).map(\.1), color: category.accent)
                .frame(height: 48)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var scienceSection: some View {
        if let match = explanation.articleID.flatMap({ ScienceLibrary.article(id: $0) })
            ?? ScienceLibrary.article(explaining: link)
            ?? ScienceLibrary.articles(for: link.b).first
            ?? ScienceLibrary.articles(for: link.a).first {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(eyebrow: "What science says", title: match.title)
                    .padding(.horizontal, 2)

                Button {
                    article = match
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(match.deck)
                            .font(Vida.sans(15))
                            .foregroundStyle(Vida.inkSoft)
                            .lineSpacing(5)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(match.takeaways.prefix(2), id: \.self) { takeaway in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(Vida.sky)
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 7)
                                Text(takeaway)
                                    .font(Vida.sans(14))
                                    .foregroundStyle(Vida.ink)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        HStack(spacing: 6) {
                            Text("Read the full explanation")
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .font(Vida.sans(14, weight: .semibold))
                        .foregroundStyle(Vida.moss)
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .paperCard(padding: 20)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(Vida.taupe)
            Text("This is a pattern in your data, not a diagnosis. Two things moving together doesn't mean one caused the other — and something else entirely may be moving both. If something here worries you, it's a great thing to bring to a clinician. Doctor Prep can help you put it into words.")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Vida.taupe.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// One half of a side-by-side comparison, shown as a labelled meter.
struct ArmBar: View {
    let label: String
    let days: Int
    let value: Double
    let display: String
    let fraction: Double
    var tint: Color = Vida.moss

    @State private var grown: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .font(Vida.sans(13, weight: .medium))
                    .foregroundStyle(Vida.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                Text(display)
                    .font(Vida.number(19))
                    .foregroundStyle(Vida.forest)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Vida.shell)
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * (grown ? min(1, max(0.04, fraction)) : 0))
                }
            }
            .frame(height: 8)

            Text("\(days) day\(days == 1 ? "" : "s")")
                .font(Vida.sans(11))
                .foregroundStyle(Vida.taupe)
        }
        .onAppear {
            withAnimation(.smooth(duration: 0.7).delay(0.1)) { grown = true }
        }
    }
}

/// Three dots showing how much weight a connection has earned.
struct ConfidenceDots: View {
    let level: PatternConfidence

    private var filled: Int {
        switch level {
        case .early: 1
        case .watching: 2
        case .consistent: 3
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index < filled ? Vida.moss : Vida.shell)
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityLabel(level.rawValue)
    }
}

/// Detail on a single tracked signal.
struct SignalDetailView: View {
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let category: SignalCategory

    @State private var article: ScienceArticle?

    private var values: [(Date, Double)] { store.recentValues(for: category, days: store.isPlus ? 60 : 7) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: category.symbol)
                                .font(.system(size: 16))
                                .foregroundStyle(category.accent)
                            Eyebrow(text: "Signal")
                        }
                        Text(category.title)
                            .font(Vida.serif(36))
                            .foregroundStyle(Vida.forest)
                    }
                    .padding(.top, 8)

                    // Three readings minimum before a trend line or an average
                    // is drawn — anything less describes two days, not a pattern.
                    if values.count >= 3 {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .firstTextBaseline) {
                                Eyebrow(text: "Last \(values.count) logged days")
                                Spacer()
                                Text(averageText)
                                    .font(Vida.sans(13, weight: .medium))
                                    .foregroundStyle(Vida.moss)
                            }
                            Sparkline(values: values.map(\.1), color: category.accent)
                                .frame(height: 110)
                        }
                        .paperCard(padding: 20)
                    } else {
                        QuietEmptyState(
                            symbol: category.symbol,
                            title: values.isEmpty ? "Nothing logged yet" : "Not enough data yet",
                            message: values.isEmpty
                                ? "\(category.title) hasn't been logged yet. Add it to a check-in and its trend will build here."
                                : "You've logged \(category.title.lowercased()) \(values.count) time\(values.count == 1 ? "" : "s"). Vida draws a trend from three — fewer than that describes a couple of days, not a pattern."
                        )
                        .paperCard(padding: 8)
                    }

                    connections

                    reading
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Vida.sans(15, weight: .medium))
                        .foregroundStyle(Vida.moss)
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
        .sheet(item: $article) { ArticleView(article: $0) }
    }

    private var averageText: String {
        guard !values.isEmpty else { return "" }
        let avg = values.map(\.1).reduce(0, +) / Double(values.count)
        if category == .sleep {
            let hours = Int(avg)
            return "Average \(hours)h \(String(format: "%02d", Int((avg - Double(hours)) * 60)))m"
        }
        return String(format: "Average %.1f / 10", avg)
    }

    @ViewBuilder
    private var connections: some View {
        let related = store.meaningfulLinks.filter { $0.a == category || $0.b == category }
        if !related.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(eyebrow: "Connects to", title: "Related signals")
                    .padding(.horizontal, 2)
                VStack(spacing: 10) {
                    ForEach(related) { link in
                        LinkRow(link: link)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var reading: some View {
        let related = ScienceLibrary.articles(for: category)
        if !related.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(eyebrow: "From the library", title: "Understand it")
                    .padding(.horizontal, 2)
                VStack(spacing: 10) {
                    ForEach(related) { item in
                        Button { article = item } label: {
                            ArticleRow(article: item, isLocked: item.isPremium && !store.isPlus)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }
}
