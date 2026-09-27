import SwiftUI

/// The Pattern Map: an orbital constellation of signals with living connections.
struct PatternMapView: View {
    @Environment(VidaStore.self) private var store
    @State private var focusedLink: PatternLink?
    @State private var selectedNode: SignalCategory?
    @State private var showPaywall: Bool = false
    @State private var showCheckIn: Bool = false
    @State private var breathe: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var nodes: [SignalCategory] {
        [.cycle, .sleep, .energy, .mood, .pain, .headache, .digestion, .focus, .stress, .movement]
    }

    private var links: [PatternLink] {
        store.links.filter { $0.magnitude >= 0.28 }
    }

    private var visibleLinks: [PatternLink] { store.visibleInsights }

    private var readiness: PatternReadiness {
        PatternReadiness(loggedDays: store.loggedDayCount, visibleCount: visibleLinks.count)
    }

    /// A constellation with no threads is a chart drawn from nothing. Below the
    /// floor Vida shows the progress card instead of an empty diagram.
    private var hasEnoughForMap: Bool {
        store.loggedDayCount >= PatternReadiness.floor
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    if hasEnoughForMap {
                        constellation
                    } else {
                        PatternProgressCard(readiness: readiness) {
                            showCheckIn = true
                        }
                    }

                    if !store.isPlus && store.hiddenInsightCount > 0 {
                        PlusLockCard(
                            title: "\(store.hiddenInsightCount) quieter connection\(store.hiddenInsightCount == 1 ? " is" : "s are") waiting",
                            message: "Vida Free shows your \(VidaStore.freeInsightLimit) strongest patterns. Vida+ opens the rest of the map and your full history."
                        ) { showPaywall = true }
                    }
                    InsightLaunchCard(feature: .differential)
                    connectionsList
                    methodNote
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
                .readableColumn()
            }
            .scrollIndicators(.hidden)
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PATTERN MAP")
                        .font(Vida.sans(12, weight: .bold))
                        .tracking(2.4)
                        .foregroundStyle(Vida.forest)
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
        .sheet(item: $focusedLink) { PatternDetailView(link: $0) }
        .sheet(item: $selectedNode) { SignalDetailView(category: $0) }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showCheckIn) { CheckInFlow(period: store.currentPeriod) }
        .onAppear {
            // The constellation breathes continuously, which is the most
            // motion-sensitive surface in the app. Reduce Motion stops it.
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) { breathe = true }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What connects\nin your body")
                .font(Vida.serif(30))
                .foregroundStyle(Vida.forest)
            Text(store.loggedDayCount < 5
                 ? "Vida needs about a week of check-ins before connections become trustworthy. You have \(store.loggedDayCount) day\(store.loggedDayCount == 1 ? "" : "s")."
                 : "Built from \(store.visibleLogs.count) days of your own check-ins. Tap any thread or signal to see what it means.")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    // MARK: - Constellation

    private var constellation: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size * 0.38

            ZStack {
                Circle()
                    .strokeBorder(Vida.hairline.opacity(0.5), lineWidth: 0.8)
                    .frame(width: radius * 2.05, height: radius * 2.05)
                    .position(center)

                // Threads
                ForEach(links) { link in
                    if let p1 = position(of: link.a, center: center, radius: radius),
                       let p2 = position(of: link.b, center: center, radius: radius) {
                        let isVisible = visibleLinks.contains(link)
                        let control = bowedControl(from: p1, to: p2, toward: center)
                        let thread = threadPath(from: p1, to: p2, control: control)
                        thread
                            .stroke(
                                threadColor(for: link, visible: isVisible),
                                style: StrokeStyle(lineWidth: 0.7 + link.magnitude * 3.2, lineCap: .round)
                            )
                            .opacity(isVisible ? (breathe ? 0.95 : 0.6) : 0.25)
                            .contentShape(thread.strokedPath(StrokeStyle(lineWidth: 22, lineCap: .round)))
                            .onTapGesture { tapThread(link) }
                    }
                }

                // Nodes
                ForEach(nodes) { node in
                    if let p = position(of: node, center: center, radius: radius) {
                        NodeBubble(
                            category: node,
                            weight: nodeWeight(node),
                            isConnected: visibleLinks.contains { $0.a == node || $0.b == node }
                        ) {
                            selectedNode = node
                        }
                        .position(p)
                    }
                }

                VStack(spacing: 2) {
                    Text("\(store.meaningfulLinks.count)")
                        .font(Vida.number(28, weight: .regular))
                        .foregroundStyle(Vida.forest)
                    Text(store.meaningfulLinks.count == 1 ? "connection" : "connections")
                        .font(Vida.sans(11))
                        .tracking(1.2)
                        .foregroundStyle(Vida.taupe)
                }
                .position(center)
            }
        }
        .frame(height: 360)
        .paperCard(padding: 8)
    }

    /// Pulls the midpoint of a thread toward the centre so threads arc inward.
    private func bowedControl(from p1: CGPoint, to p2: CGPoint, toward center: CGPoint) -> CGPoint {
        let midX: CGFloat = (p1.x + p2.x) / 2
        let midY: CGFloat = (p1.y + p2.y) / 2
        let pull: CGFloat = 0.35
        return CGPoint(x: midX + (center.x - midX) * pull, y: midY + (center.y - midY) * pull)
    }

    /// Extracted so the same curve can be drawn and reused as a hit area.
    private func threadPath(from p1: CGPoint, to p2: CGPoint, control: CGPoint) -> Path {
        var path = Path()
        path.move(to: p1)
        path.addQuadCurve(to: p2, control: control)
        return path
    }

    /// Visible threads open their explanation; locked ones explain the lock.
    private func tapThread(_ link: PatternLink) {
        if visibleLinks.contains(link) {
            focusedLink = link
        } else if store.meaningfulLinks.contains(link) {
            showPaywall = true
        }
    }

    private func threadColor(for link: PatternLink, visible: Bool) -> Color {
        guard visible else { return Vida.taupe.opacity(0.4) }
        return link.strength > 0 ? Vida.skyDeep : Vida.moss
    }

    private func position(of category: SignalCategory, center: CGPoint, radius: CGFloat) -> CGPoint? {
        guard let index = nodes.firstIndex(of: category) else { return nil }
        let angle = (Double(index) / Double(nodes.count)) * 2 * .pi - .pi / 2
        return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }

    private func nodeWeight(_ category: SignalCategory) -> Double {
        let count = visibleLinks.filter { $0.a == category || $0.b == category }.count
        return min(1, Double(count) / 3.0)
    }

    // MARK: - Connections list

    private var connectionsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(eyebrow: "Threads", title: "Worth noticing")
                .padding(.horizontal, 2)

            if visibleLinks.isEmpty {
                QuietEmptyState(
                    symbol: "point.3.connected.trianglepath.dotted",
                    title: store.loggedDayCount < 6 ? "Not enough days yet" : "No clear threads yet",
                    message: store.loggedDayCount < 6
                        ? "Vida needs about six days of check-ins before a connection can be trusted. You have \(store.loggedDayCount)."
                        : "That's a genuine finding, not a failure. Keep checking in — Vida only surfaces a connection once it has enough days behind it."
                )
                .paperCard(padding: 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(visibleLinks) { link in
                        Button {
                            focusedLink = link
                        } label: {
                            LinkRow(link: link)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }

    private var methodNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "How to read this")
            Text("A connection means two things moved together in your data. It does not mean one caused the other — and it is never a diagnosis. Threads get thicker as the association gets stronger, and Vida only shows one once it has at least six overlapping days.")
                .font(Vida.sans(13))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Vida.sage.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct NodeBubble: View {
    let category: SignalCategory
    let weight: Double
    let isConnected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(isConnected ? category.accent.opacity(0.22) : Vida.cream)
                        .frame(width: 38 + weight * 10, height: 38 + weight * 10)
                    Circle()
                        .strokeBorder(isConnected ? category.accent : Vida.hairline, lineWidth: isConnected ? 1.4 : 0.9)
                        .frame(width: 38 + weight * 10, height: 38 + weight * 10)
                    Image(systemName: category.symbol)
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(isConnected ? Vida.forest : Vida.taupe)
                }
                Text(category.title)
                    .font(Vida.sans(10, weight: .medium))
                    .foregroundStyle(isConnected ? Vida.forest : Vida.taupe)
            }
        }
        .buttonStyle(PressableStyle())
    }
}

struct LinkRow: View {
    let link: PatternLink

    private var confidence: PatternConfidence { PatternExplainer.confidence(for: link) }

    var body: some View {
        HStack(spacing: 16) {
            ConnectionGlyph(strength: link.magnitude)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 5) {
                Text(PatternExplainer.shortMeaning(for: link))
                    .font(Vida.sans(16, weight: .semibold))
                    .foregroundStyle(Vida.forest)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(link.a.title) ↔ \(link.b.title)")
                    .font(Vida.sans(12))
                    .foregroundStyle(Vida.inkSoft)

                HStack(spacing: 7) {
                    ConfidenceDots(level: confidence)
                    Text(confidence.rawValue)
                        .font(Vida.sans(12, weight: .medium))
                        .foregroundStyle(Vida.moss)
                    Text("·")
                        .foregroundStyle(Vida.taupe)
                    Text("\(link.sampleSize) days")
                        .font(Vida.sans(12))
                        .foregroundStyle(Vida.taupe)
                }
                .padding(.top, 1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Vida.taupe)
        }
        .paperCard(padding: 16)
    }
}
