import SwiftUI

struct HomeView: View {
    @Environment(VidaStore.self) private var store
    @Binding var selectedTab: RootTab
    @State private var checkInPeriod: CheckInPeriod?
    @State private var showQuickMorning: Bool = false
    @State private var focusedLink: PatternLink?
    @State private var showPaywall: Bool = false
    @State private var showReport: Bool = false
    @State private var appeared: Bool = false
    @State private var carouselID: PatternLink.ID?
    @State private var showShare: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    greeting
                    todayHero
                    checkInCard
                    weeklyReportCard
                    signalsSection
                    insightsSection
                    cycleCard
                    principleFooter
                }
                .padding(.horizontal, Vida.Space.gutter)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .readableColumn()
            }
            .scrollIndicators(.hidden)
            .vidaScrollChrome("Today", threshold: 300) {
                ArchBadge(photo: VidaHeroPhoto.current)
            }
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
            .vidaMenu()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        Button { showShare = true } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(Vida.forest)
                        }
                        .accessibilityLabel("Share today")
                        NavigationLink {
                            SettingsView()
                        } label: {
                            AvatarView(data: store.avatarData, name: store.name, size: 30)
                        }
                    }
                }
            }
        }
        .sheet(item: $checkInPeriod) { period in
            CheckInFlow(period: period)
        }
        .sheet(isPresented: $showQuickMorning) {
            MorningCheckInView {
                // Presenting straight from a dismissing sheet gets swallowed,
                // so hand the next one to the following runloop turn.
                DispatchQueue.main.async { checkInPeriod = .morning }
            }
        }
        .sheet(isPresented: $showReport) {
            WeeklyReportView()
        }
        .sheet(item: $focusedLink) { link in
            PatternDetailView(link: link)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showShare) {
            ShareSnapshotView()
        }
        .onAppear {
            withAnimation(.smooth(duration: 0.7).delay(0.05)) { appeared = true }
        }
    }

    // MARK: - Greeting

    private var greeting: some View {
        ArchWindow(photo: VidaHeroPhoto.current) {
            greetingText
        }
        .zIndex(-1)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var greetingText: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()), color: OnPhoto.secondary)
            greetingLine
                .font(Vida.display(36))
                .tracking(Vida.displayTracking)
                .foregroundStyle(OnPhoto.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(greetingCaption)
                .font(Vida.sans(16))
                .foregroundStyle(OnPhoto.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Today hero

    /// The one big, quiet number on the screen: how much of today is logged,
    /// drawn as a luminous ring, with the two figures that say how close her
    /// patterns are beside it.
    private var todayHero: some View {
        let done = store.completedPeriodsToday.count
        let total = CheckInPeriod.allCases.count
        let stat = patternStat
        return HStack(spacing: 24) {
            ZStack {
                LuminousRing(progress: store.todayPeriodCompletion, lineWidth: 9)
                VStack(spacing: 1) {
                    Text("\(done)")
                        .font(Vida.display(42))
                        .tracking(Vida.displayTracking)
                        .foregroundStyle(Vida.forest)
                        .contentTransition(.numericText(value: Double(done)))
                    Text("of \(total) today")
                        .font(Vida.sans(11, weight: .medium))
                        .tracking(0.4)
                        .foregroundStyle(Vida.taupe)
                }
            }
            .frame(width: 126, height: 126)

            VStack(alignment: .leading, spacing: 14) {
                heroStat(
                    value: store.loggedDayCount,
                    label: store.loggedDayCount == 1 ? "day logged" : "days logged"
                )
                HairlineDivider()
                heroStat(value: stat.value, label: stat.label)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .paperCard(padding: 22)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .animation(Vida.Motion.settle, value: done)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(total) check-ins done today. \(store.loggedDayCount) days logged. \(stat.value) \(stat.label).")
    }

    private var patternStat: (value: Int, label: String) {
        let found = store.visibleInsights.count
        if found > 0 || readiness.daysRemaining == 0 {
            return (found, found == 1 ? "pattern found" : "patterns found")
        }
        return (readiness.daysRemaining, readiness.daysRemaining == 1 ? "day to a full picture" : "days to a full picture")
    }

    private func heroStat(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(Vida.display(30))
                .tracking(Vida.displayTracking)
                .foregroundStyle(Vida.forest)
                .contentTransition(.numericText(value: Double(value)))
            Text(label)
                .font(Vida.sans(12))
                .foregroundStyle(Vida.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Her name is set in Newsreader italic: the one warm, human note in an
    /// otherwise modern sans headline.
    private var greetingLine: Text {
        if store.name.isEmpty { return Text(timeGreeting + ".") }
        return Text(timeGreeting + ", ")
            + Text(store.name + ".")
                .font(Vida.serifItalic(36))
                .foregroundStyle(OnPhoto.accent)
    }

    /// Speaks to her condition when she named one — the app should sound like
    /// it remembers what she's dealing with.
    private var greetingCaption: String {
        if store.completedPeriodsToday.count == 2 {
            return "Both check-ins done today. That's what makes the patterns real."
        }
        if let condition = store.profile.conditions.first, store.loggedDayCount < 14 {
            return "Building your \(condition.name.lowercased()) picture, one day at a time."
        }
        return store.currentPeriod == .morning
            ? "How did you wake up?"
            : "How did the day treat you?"
    }

    private var timeGreeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 0..<5: "Still up"
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    // MARK: - Check in

    private var checkInCard: some View {
        VStack(spacing: 12) {
            ForEach(CheckInPeriod.allCases) { period in
                let isDone = store.hasCompleted(period)
                PeriodCheckInRow(
                    period: period,
                    isDone: isDone,
                    isNext: store.nextPeriod == period,
                    count: store.todayLog?.categories(in: period).count ?? 0,
                    // The morning row leads with the short flow: two questions is
                    // a promise someone can keep on a bad morning, and a kept
                    // check-in is worth more than a perfect one she skipped.
                    promise: period == .morning ? "Sleep and energy · about 30 seconds" : nil,
                    accessoryLabel: period == .morning && !isDone ? "Log everything instead" : nil,
                    accessoryAction: period == .morning && !isDone ? { checkInPeriod = .morning } : nil
                ) {
                    if period == .morning && !isDone {
                        showQuickMorning = true
                    } else {
                        checkInPeriod = period
                    }
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    // MARK: - Weekly report

    @ViewBuilder
    private var weeklyReportCard: some View {
        if store.loggedDayCount >= 3 {
            Button {
                showReport = true
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Vida.sky.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 16, weight: .light))
                            .foregroundStyle(Vida.skyDeep)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow(text: "Your week", color: Vida.skyDeep)
                        Text(store.weeklyReport().headline)
                            .font(Vida.sans(15, weight: .medium))
                            .foregroundStyle(Vida.forest)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Vida.taupe)
                }
                .paperCard(padding: 18)
            }
            .buttonStyle(PressableStyle())
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 18)
        }
    }

    // MARK: - Your signals

    private var signalsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(eyebrow: "Today", title: "Your Signals") {
                selectedTab = .patterns
            }
            .padding(.horizontal, 2)

            VStack(spacing: 0) {
                let rows = summaryRows
                if rows.isEmpty {
                    QuietEmptyState(
                        symbol: "leaf",
                        title: "Nothing logged yet",
                        message: "Your signals appear here as soon as you complete your first check-in."
                    )
                } else {
                    ForEach(Array(rows.enumerated()), id: \.element.category) { index, row in
                        SignalPill(
                            category: row.category,
                            valueText: row.text,
                            trend: row.trend,
                            fraction: row.fraction
                        )
                        if index < rows.count - 1 { HairlineDivider() }
                    }
                }
            }
            .paperCard(padding: 18)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private struct SummaryRow {
        let category: SignalCategory
        let text: String
        let trend: SignalPill.Trend
        let fraction: Double
    }

    /// Normalises a reading to 0...1 so the row meter reads at a glance.
    private func fraction(_ value: Double, _ category: SignalCategory) -> Double {
        if category == .sleep { return min(1, max(0, value / 9.0)) }
        return min(1, max(0, value / 10.0))
    }

    private var summaryRows: [SummaryRow] {
        var rows: [SummaryRow] = []
        if let day = store.cycleDay, let phase = store.cyclePhase {
            rows.append(.init(
                category: .cycle,
                text: "Day \(day) · \(phase)",
                trend: .none,
                fraction: Double(day) / Double(store.averageCycleLength)
            ))
        }
        let priority: [SignalCategory] = [.sleep, .energy, .mood, .pain, .headache, .focus, .stress]
        guard let log = store.todayLog else {
            // Fall back to the most recent readings so the card is never empty.
            for category in priority.prefix(4) {
                if let recent = store.recentValues(for: category, days: 4).last {
                    rows.append(.init(
                        category: category,
                        text: display(recent.1, category),
                        trend: .none,
                        fraction: fraction(recent.1, category)
                    ))
                }
            }
            return rows
        }
        for category in priority where log.reading(for: category) != nil {
            guard let reading = log.reading(for: category) else { continue }
            rows.append(.init(
                category: category,
                text: display(reading.value, category),
                trend: trend(for: category, current: reading.value),
                fraction: fraction(reading.value, category)
            ))
            if rows.count >= 5 { break }
        }
        return rows
    }

    private func display(_ value: Double, _ category: SignalCategory) -> String {
        if category == .sleep {
            let hours = Int(value)
            let minutes = Int((value - Double(hours)) * 60)
            return "\(hours)h \(String(format: "%02d", minutes))m"
        }
        if category == .cycle {
            return value == 0 ? "None" : "Flow \(Int(value))/10"
        }
        switch value {
        case 0..<3: return category.higherIsBetter ? "Low" : "Minimal"
        case 3..<6: return category.higherIsBetter ? "Moderate" : "Mild"
        case 6..<8: return category.higherIsBetter ? "Good" : "Notable"
        default: return category.higherIsBetter ? "High" : "Severe"
        }
    }

    private func trend(for category: SignalCategory, current: Double) -> SignalPill.Trend {
        let history = store.recentValues(for: category, days: 10).dropLast()
        guard history.count >= 3 else { return .none }
        let average = history.map(\.1).reduce(0, +) / Double(history.count)
        if current > average + 0.8 { return .up }
        if current < average - 0.8 { return .down }
        return .steady
    }

    // MARK: - Something worth noticing

    private var readiness: PatternReadiness {
        PatternReadiness(loggedDays: store.loggedDayCount, visibleCount: store.visibleInsights.count)
    }

    @ViewBuilder
    private var insightsSection: some View {
        if store.visibleInsights.isEmpty {
            // Never a blank panel. Before patterns exist this states the day
            // count, what unlocks at 14, and offers the one action that moves
            // it forward.
            PatternProgressCard(readiness: readiness) {
                switch readiness.stage {
                case .noneFound:
                    selectedTab = .patterns
                default:
                    if let next = store.nextPeriod {
                        if next == .morning {
                            showQuickMorning = true
                        } else {
                            checkInPeriod = next
                        }
                    } else {
                        checkInPeriod = store.currentPeriod
                    }
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 24)
        } else if let insight = store.visibleInsights.first {
            VStack(alignment: .leading, spacing: 12) {
                if store.visibleInsights.count > 1 {
                    noticingCarousel
                } else {
                    noticingCard(insight)
                }

                if store.visibleInsights.count > 1 {
                    Button {
                        selectedTab = .patterns
                    } label: {
                        HStack(spacing: 6) {
                            Text("See all \(store.visibleInsights.count) connections")
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .font(Vida.sans(14, weight: .semibold))
                        .foregroundStyle(Vida.moss)
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(PressableStyle())
                } else if !store.isPlus && store.hiddenInsightCount > 0 {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("\(store.hiddenInsightCount) more in Vida+")
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .font(Vida.sans(14, weight: .semibold))
                        .foregroundStyle(Vida.moss)
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    /// Several patterns, one at a time: cards snap into place, and the ones
    /// waiting on either side tilt back and dim a little, so the row reads as
    /// objects with depth rather than a strip of tiles.
    private var noticingCarousel: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(Array(store.visibleInsights.prefix(5))) { link in
                    noticingCard(link)
                        .containerRelativeFrame(.horizontal) { width, _ in width * 0.86 }
                        .scrollTransition(.interactive) { view, phase in
                            view
                                .scaleEffect(1 - abs(phase.value) * 0.06)
                                .opacity(1 - abs(phase.value) * 0.45)
                                .rotation3DEffect(
                                    .degrees(phase.value * -9),
                                    axis: (x: 0, y: 1, z: 0),
                                    anchor: phase.value < 0 ? .trailing : .leading,
                                    perspective: 0.6
                                )
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $carouselID)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: carouselID)
    }

    private func noticingCard(_ link: PatternLink) -> some View {
        Button {
            focusedLink = link
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 11))
                    Text("SOMETHING WORTH NOTICING")
                        .font(Vida.sans(11, weight: .semibold))
                        .tracking(1.6)
                }
                .foregroundStyle(Vida.skyDeep)

                Text("\(link.a.title) ↔ \(link.b.title)")
                    .font(Vida.serif(22))
                    .foregroundStyle(Vida.forest)
                    .fixedSize(horizontal: false, vertical: true)

                Text(PatternEngine.sentence(for: link, logs: store.visibleLogs))
                    .font(Vida.sans(15))
                    .foregroundStyle(Vida.inkSoft)
                    .lineSpacing(5)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    Text("Explore the science")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .font(Vida.sans(13, weight: .medium))
                .foregroundStyle(Vida.moss)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: Vida.cardRadius, style: .continuous)
                    .fill(Vida.paper)
            }
            .overlay(alignment: .topTrailing) {
                ConnectionGlyph(strength: link.magnitude)
                    .frame(width: 46, height: 46)
                    .padding(16)
                    .opacity(0.42)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Vida.cardRadius, style: .continuous)
                    .strokeBorder(Vida.skyDeep.opacity(0.3), lineWidth: 0.7)
            }
        }
        .buttonStyle(PressableStyle())
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
    }

    // MARK: - Cycle

    @ViewBuilder
    private var cycleCard: some View {
        if let day = store.cycleDay, let phase = store.cyclePhase {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeading(eyebrow: "Cycle", title: "Where you are")
                    .padding(.horizontal, 2)

                HStack(spacing: 22) {
                    CycleDial(day: day, length: store.averageCycleLength)
                        .frame(width: 92, height: 92)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Day \(day)")
                            .font(Vida.serif(28))
                            .foregroundStyle(Vida.forest)
                        Text("\(phase) phase")
                            .font(Vida.sans(15, weight: .medium))
                            .foregroundStyle(Vida.moss)
                        if let until = store.daysUntilNextPeriod {
                            Text(until <= 1 ? "Next period expected around now" : "Next period in about \(until) days")
                                .font(Vida.sans(13))
                                .foregroundStyle(Vida.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .paperCard(padding: 20)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 28)
        }
    }

    private var principleFooter: some View {
        VStack(spacing: 10) {
            HairlineDivider()
                .padding(.bottom, 6)
            Text("You are the expert on what you're experiencing.")
                .font(Vida.serifItalic(17))
                .foregroundStyle(Vida.moss)
                .multilineTextAlignment(.center)
            Text("Science helps you understand what it might mean.")
                .font(Vida.sans(13))
                .foregroundStyle(Vida.taupe)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 10)
    }
}

/// Circular cycle position dial.
struct CycleDial: View {
    let day: Int
    let length: Int

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Vida.hairline, lineWidth: 1)

            // Bleeding window
            Circle()
                .trim(from: 0, to: 5.0 / Double(length))
                .stroke(Vida.blush, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(7)

            // Ovulatory window
            Circle()
                .trim(from: Double(length / 2 - 2) / Double(length), to: Double(length / 2 + 2) / Double(length))
                .stroke(Vida.sky, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(7)

            // Progress
            Circle()
                .trim(from: 0, to: Double(day) / Double(length))
                .stroke(Vida.forest.opacity(0.75), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(16)

            Circle()
                .fill(Vida.forest)
                .frame(width: 8, height: 8)
                .offset(y: -30)
                .rotationEffect(.degrees(360 * Double(day) / Double(length)))

            Text("\(day)")
                .font(Vida.serif(20))
                .foregroundStyle(Vida.forest)
        }
    }
}

/// Two circles joined by a line whose weight reflects association strength.
struct ConnectionGlyph: View {
    let strength: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: w * 0.22, y: h * 0.32))
                    p.addQuadCurve(
                        to: CGPoint(x: w * 0.78, y: h * 0.7),
                        control: CGPoint(x: w * 0.75, y: h * 0.25)
                    )
                }
                .stroke(Vida.skyDeep, style: StrokeStyle(lineWidth: 1 + strength * 3, lineCap: .round))

                Circle().fill(Vida.moss).frame(width: 9).position(x: w * 0.22, y: h * 0.32)
                Circle().fill(Vida.sky).frame(width: 9).position(x: w * 0.78, y: h * 0.7)
            }
        }
    }
}
