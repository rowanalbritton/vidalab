import SwiftUI
import UIKit

// Vida+ meditation, in the spirit of Oura's sessions: breathe, follow a guided
// session, or sit with a timer, and see how it moved your stress.

/// Opens meditation from Today.
struct MeditationLaunchCard: View {
    @State private var isPresented = false

    var body: some View {
        Button { isPresented = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "wind")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Vida.moss)
                    .frame(width: 44, height: 44)
                    .background(Vida.sage.opacity(0.18), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Meditate")
                            .font(Vida.serif(19))
                            .foregroundStyle(Vida.forest)
                        Text("VIDA+")
                            .font(Vida.sans(9, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Vida.cream)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Vida.moss, in: Capsule())
                    }
                    Text("Breathing, guided sessions, and a quiet timer")
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Vida.taupe)
                    .accessibilityHidden(true)
            }
            .paperCard(padding: 18)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Meditate, Vida Plus. Breathing, guided sessions, and a quiet timer")
        .accessibilityAddTraits(.isButton)
        .sheet(isPresented: $isPresented) {
            MeditationHomeView()
                .presentationDetents([.large])
        }
    }
}

/// What a session will run, chosen on the home screen.
enum MeditationPlan: Identifiable, Hashable {
    case breathing(BreathPattern)
    case guided(ApothecaryItem)
    case timer(Int)

    var id: String {
        switch self {
        case .breathing(let pattern): "breath-\(pattern.id)"
        case .guided(let item): "guided-\(item.id)"
        case .timer(let minutes): "timer-\(minutes)"
        }
    }

    var title: String {
        switch self {
        case .breathing(let pattern): pattern.title
        case .guided(let item): item.title
        case .timer: "Quiet sit"
        }
    }

    var kind: MeditationKind {
        switch self {
        case .breathing: .breathing
        case .guided: .guided
        case .timer: .timer
        }
    }
}

struct MeditationHomeView: View {
    @Environment(VidaStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    private let content = SiteContentService.shared

    @State private var sessions: [MeditationSession] = []
    @State private var running: MeditationPlan?
    @State private var showPaywall = false
    @State private var guidedFilter: String?

    private var stats: MeditationStats { MeditationStats.from(sessions) }

    private var meditations: [ApothecaryItem] {
        (content.apothecary.value ?? []).filter { $0.category == ApothecaryShelf.meditation.rawValue }
    }

    private var filters: [String] {
        let order = ["sleep", "mindfulness", "body-scan", "breathing", "morning", "grounding", "visualization", "loving-kindness"]
        let present = Set(meditations.compactMap(\.subcategory))
        return order.filter(present.contains)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Vida+", color: Vida.moss)
                        Text("A few quiet minutes.")
                            .font(Vida.serif(30))
                            .foregroundStyle(Vida.forest)
                        Text("Slow your breathing, follow a guided session, or just sit. Check in before and after to see what it does for you.")
                            .font(Vida.sans(15))
                            .foregroundStyle(Vida.inkSoft)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if store.isPlus {
                        statsCard
                        breatheSection
                        guidedSection
                        timerSection
                        recentSection
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Meditation is part of Vida+.")
                                .font(Vida.sans(15, weight: .semibold))
                                .foregroundStyle(Vida.forest)
                            Button { showPaywall = true } label: {
                                Text("Explore Vida+")
                                    .font(Vida.sans(15, weight: .semibold))
                                    .foregroundStyle(Vida.onForest)
                                    .frame(maxWidth: .infinity, minHeight: 50)
                                    .background(Vida.forest, in: Capsule())
                            }
                            .buttonStyle(PressableStyle())
                        }
                        .paperCard(padding: 18)
                    }

                    Text("Meditation and breathing practices can support wellbeing but don't treat any condition. If a breathing exercise makes you dizzy or uncomfortable, stop and breathe normally.")
                        .font(Vida.sans(12))
                        .foregroundStyle(Vida.taupe)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
                .readableColumn()
            }
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Vida.moss)
                }
            }
        }
        .task {
            reload()
            await content.loadApothecary()
        }
        .fullScreenCover(item: $running, onDismiss: reload) { plan in
            MeditationSessionView(plan: plan)
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private func reload() {
        guard let userID = auth.user?.id else { return }
        sessions = MeditationLog.load(userID: userID)
    }

    // MARK: Sections

    private var statsCard: some View {
        HStack(spacing: 0) {
            stat("\(stats.minutesThisWeek)", "min this week")
            Divider().frame(height: 36)
            stat("\(stats.streakDays)", "day streak")
            Divider().frame(height: 36)
            if let change = stats.averageStressChange {
                stat(change <= 0 ? String(format: "−%.1f", abs(change)) : String(format: "+%.1f", change), "stress, on average")
            } else {
                stat("\(stats.sessionsThisWeek)", stats.sessionsThisWeek == 1 ? "session" : "sessions")
            }
        }
        .paperCard(padding: 16)
        .accessibilityElement(children: .combine)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Vida.serif(24)).foregroundStyle(Vida.forest)
            Text(label).font(Vida.sans(11)).foregroundStyle(Vida.inkSoft).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var breatheSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(eyebrow: "Breathe", title: "Paced breathing")
            ForEach(BreathPattern.all) { pattern in
                planRow(symbol: "wind", title: pattern.title, detail: pattern.summary) { running = .breathing(pattern) }
            }
        }
    }

    @ViewBuilder
    private var guidedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(eyebrow: "Guided", title: "Read aloud, at your pace")
            if meditations.isEmpty {
                ProgressView().tint(Vida.moss).frame(maxWidth: .infinity).padding(.vertical, 16)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        SelectChip(label: "All", isSelected: guidedFilter == nil) { guidedFilter = nil }
                        ForEach(filters, id: \.self) { filter in
                            SelectChip(label: filter.replacingOccurrences(of: "-", with: " ").capitalized, isSelected: guidedFilter == filter) {
                                guidedFilter = guidedFilter == filter ? nil : filter
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()

                ForEach(meditations.filter { guidedFilter == nil || $0.subcategory == guidedFilter }.prefix(20)) { item in
                    planRow(symbol: "leaf", title: item.title, detail: [item.durationMinutes.map { "\($0) min" }, item.summary].compactMap { $0 }.joined(separator: " · ")) {
                        if let pattern = GuidedScript.breathPattern(forTitle: item.title) {
                            running = .breathing(pattern)
                        } else {
                            running = .guided(item)
                        }
                    }
                }
            }
        }
    }

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(eyebrow: "Unguided", title: "Quiet timer")
            HStack(spacing: 8) {
                ForEach([3, 5, 10, 15, 20], id: \.self) { minutes in
                    Button { running = .timer(minutes) } label: {
                        Text("\(minutes) min")
                            .font(Vida.sans(14, weight: .semibold))
                            .foregroundStyle(Vida.forest)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Vida.sage.opacity(0.18), in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Start a \(minutes) minute quiet timer")
                }
            }
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        if !sessions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeading(eyebrow: "Yours", title: "Recent sessions")
                ForEach(sessions.suffix(5).reversed()) { session in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.title).font(Vida.sans(15, weight: .medium)).foregroundStyle(Vida.forest)
                            Text("\(session.date.formatted(date: .abbreviated, time: .shortened)) · \(max(1, session.seconds / 60)) min")
                                .font(Vida.sans(12))
                                .foregroundStyle(Vida.taupe)
                        }
                        Spacer()
                        if let before = session.stressBefore, let after = session.stressAfter {
                            Text("Stress \(before) → \(after)")
                                .font(Vida.sans(12, weight: .semibold))
                                .foregroundStyle(after < before ? Vida.moss : Vida.inkSoft)
                        }
                    }
                    .paperCard(padding: 14)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func planRow(symbol: String, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(Vida.moss)
                    .frame(width: 24)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(Vida.sans(16, weight: .semibold)).foregroundStyle(Vida.forest).multilineTextAlignment(.leading)
                    if !detail.isEmpty {
                        Text(detail).font(Vida.sans(13)).foregroundStyle(Vida.inkSoft).lineLimit(3).multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "play.circle")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Vida.moss)
                    .accessibilityHidden(true)
            }
            .paperCard(padding: 16)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Starts the session")
    }
}

// MARK: - Session

/// The whole session: stress check, the practice, stress check, summary.
struct MeditationSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var auth

    let plan: MeditationPlan

    private enum Stage { case before, running, after, done }

    @State private var stage: Stage = .before
    @State private var minutes = 3
    @State private var stressBefore: Int?
    @State private var stressAfter: Int?
    @State private var startedAt = Date.now
    @State private var elapsed = 0

    var body: some View {
        ZStack {
            Vida.cream.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    // The summary has its own Done button.
                    if stage != .done {
                        Button(stage == .running ? "End" : "Close") { closeTapped() }
                            .font(Vida.sans(15, weight: .semibold))
                            .foregroundStyle(Vida.moss)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
                .frame(minHeight: 44)
                .padding(.horizontal, 20)

                switch stage {
                case .before:
                    StressCheckView(
                        title: plan.title,
                        prompt: "Before you start, how stressed do you feel?",
                        durationChoices: durationChoices,
                        minutes: $minutes,
                        startLabel: "Begin",
                        initial: 5
                    ) { value in
                        stressBefore = value
                        begin()
                    }
                case .running:
                    running
                case .after:
                    StressCheckView(
                        title: "Nicely done",
                        prompt: "How stressed do you feel now?",
                        durationChoices: [],
                        minutes: $minutes,
                        startLabel: "See how it went",
                        initial: stressBefore ?? 5
                    ) { value in
                        stressAfter = value
                        finish()
                    }
                case .done:
                    summary
                }
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            MeditationAudioSession.end()
        }
    }

    private var durationChoices: [Int] {
        switch plan {
        case .breathing: [1, 3, 5, 10]
        case .guided, .timer: []
        }
    }

    @ViewBuilder
    private var running: some View {
        switch plan {
        case .breathing(let pattern):
            BreathingRunner(pattern: pattern, minutes: minutes, onFinish: completed)
        case .guided(let item):
            GuidedRunner(script: GuidedScript.make(title: item.title, content: item.content ?? item.summary ?? "", minutes: item.durationMinutes ?? 5), onFinish: completed)
        case .timer(let minutes):
            TimerRunner(minutes: minutes, onFinish: completed)
        }
    }

    private var summary: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Vida.moss)
                .accessibilityHidden(true)
            Text(plan.title)
                .font(Vida.serif(26))
                .foregroundStyle(Vida.forest)
                .multilineTextAlignment(.center)
            Text(MeditationSessionView.durationText(seconds: elapsed))
                .font(Vida.sans(15, weight: .medium))
                .foregroundStyle(Vida.moss)
            if let before = stressBefore, let after = stressAfter {
                Text(after < before ? "Your stress went from \(before) to \(after)." : after == before ? "Your stress held steady at \(after)." : "Your stress went from \(before) to \(after). Some sessions are like that, and it still counts.")
                    .font(Vida.sans(16))
                    .foregroundStyle(Vida.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button { dismiss() } label: {
                Text("Done")
                    .font(Vida.sans(16, weight: .semibold))
                    .foregroundStyle(Vida.onForest)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Vida.forest, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(28)
    }

    private func begin() {
        startedAt = .now
        UIApplication.shared.isIdleTimerDisabled = true
        MeditationAudioSession.begin()
        stage = .running
    }

    private func completed(seconds: Int) {
        elapsed = seconds
        UIApplication.shared.isIdleTimerDisabled = false
        // Only ask afterwards if she answered beforehand; one answer on its
        // own shows no change.
        if stressBefore == nil {
            finish()
        } else {
            stage = .after
        }
    }

    /// "Under a minute", "1 minute", "12 minutes", rounded to the nearest.
    nonisolated static func durationText(seconds: Int) -> String {
        guard seconds >= 60 else { return "Under a minute" }
        let minutes = Int((Double(seconds) / 60).rounded())
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    private func closeTapped() {
        switch stage {
        case .running:
            // Ending early still asks how it went; a few minutes still count.
            completed(seconds: Int(Date.now.timeIntervalSince(startedAt)))
        case .after:
            finish()
            dismiss()
        default:
            dismiss()
        }
    }

    private func finish() {
        if elapsed >= 30, let userID = auth.user?.id {
            MeditationLog.append(
                MeditationSession(date: startedAt, kind: plan.kind, title: plan.title, seconds: elapsed, stressBefore: stressBefore, stressAfter: stressAfter),
                userID: userID
            )
        }
        stage = .done
    }
}

/// A 0-to-10 stress check with an optional length choice. "Skip" leaves the
/// answer empty rather than guessing.
struct StressCheckView: View {
    let title: String
    let prompt: String
    let durationChoices: [Int]
    @Binding var minutes: Int
    let startLabel: String
    var initial = 5
    let onContinue: (Int?) -> Void

    @State private var value = 5.0

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            Text(title)
                .font(Vida.serif(30))
                .foregroundStyle(Vida.forest)
                .fixedSize(horizontal: false, vertical: true)

            if !durationChoices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "How long?")
                    Picker("Length", selection: $minutes) {
                        ForEach(durationChoices, id: \.self) { Text("\($0) min").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(prompt).font(Vida.sans(17, weight: .medium)).foregroundStyle(Vida.ink)
                // Buttons on either side for exact values; the slider for quick ones.
                HStack(spacing: 24) {
                    stepButton("minus", label: "Less stressed") { value = max(0, value - 1) }
                    Text("\(Int(value))")
                        .font(Vida.serif(44))
                        .foregroundStyle(Vida.forest)
                        .monospacedDigit()
                        .frame(minWidth: 60)
                        .accessibilityHidden(true)
                    stepButton("plus", label: "More stressed") { value = min(10, value + 1) }
                }
                .frame(maxWidth: .infinity)
                Slider(value: $value, in: 0...10, step: 1)
                    .tint(Vida.moss)
                    .accessibilityLabel("Stress")
                    .accessibilityValue("\(Int(value)) out of 10")
                HStack {
                    Text("Calm").font(Vida.sans(12)).foregroundStyle(Vida.inkSoft)
                    Spacer()
                    Text("Very stressed").font(Vida.sans(12)).foregroundStyle(Vida.inkSoft)
                }
                .accessibilityHidden(true)
            }
            Spacer()
            VStack(spacing: 10) {
                Button { onContinue(Int(value)) } label: {
                    Text(startLabel)
                        .font(Vida.sans(16, weight: .semibold))
                        .foregroundStyle(Vida.onForest)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Vida.forest, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                Button { onContinue(nil) } label: {
                    Text("Skip the check")
                        .font(Vida.sans(14, weight: .medium))
                        .foregroundStyle(Vida.moss)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(28)
        .onAppear { value = Double(initial) }
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Vida.forest)
                .frame(width: 48, height: 48)
                .background(Vida.sage.opacity(0.2), in: Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}

// MARK: - Runners

struct BreathingRunner: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let pattern: BreathPattern
    let minutes: Int
    let onFinish: (Int) -> Void

    @State private var phase: BreathPattern.Phase = .inhale
    @State private var phaseTick = 0
    @State private var scale: CGFloat = 0.55
    @State private var cycle = 1
    @State private var startedAt = Date.now
    @State private var chime = MeditationChime()

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Vida.sage.opacity(0.18))
                    .frame(width: 280, height: 280)
                Circle()
                    .fill(Vida.moss.opacity(reduceMotion ? (phase == .exhale || phase == .holdOut ? 0.25 : 0.55) : 0.45))
                    .frame(width: 280, height: 280)
                    .scaleEffect(reduceMotion ? 0.8 : scale)
                Text(phase.rawValue)
                    .font(Vida.serif(24))
                    .foregroundStyle(Vida.forest)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .background(Vida.cream.opacity(0.7), in: Capsule())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(phase.rawValue)
            .accessibilityAddTraits(.updatesFrequently)

            Text("Breath \(cycle) of \(pattern.cycles(forMinutes: minutes))")
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
            Spacer()
        }
        .padding(28)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: phaseTick)
        .task { await run() }
    }

    private func run() async {
        startedAt = .now
        chime.ring()
        let cycles = pattern.cycles(forMinutes: minutes)
        for index in 1...cycles {
            cycle = index
            for step in pattern.phases {
                if Task.isCancelled { return }
                phase = step.phase
                phaseTick += 1
                let target: CGFloat
                switch step.phase {
                case .inhale: target = pattern.topUp > 0 ? 0.92 : 1.0
                case .topUp: target = 1.0
                case .exhale: target = 0.55
                case .holdIn, .holdOut: target = scale
                }
                withAnimation(.easeInOut(duration: step.seconds)) { scale = target }
                try? await Task.sleep(for: .seconds(step.seconds))
            }
        }
        guard !Task.isCancelled else { return }
        chime.ring()
        onFinish(Int(Date.now.timeIntervalSince(startedAt)))
    }
}

struct GuidedRunner: View {
    let script: GuidedScript
    let onFinish: (Int) -> Void

    @State private var index = 0
    @State private var isPaused = false
    @State private var startedAt = Date.now
    @State private var speaker = MeditationSpeaker()
    @State private var chime = MeditationChime()

    var body: some View {
        VStack(spacing: 24) {
            Text("Step \(min(index + 1, script.segments.count)) of \(script.segments.count)")
                .font(Vida.sans(13, weight: .medium))
                .foregroundStyle(Vida.taupe)
                .padding(.top, 12)
            Spacer()
            Text(script.segments.indices.contains(index) ? script.segments[index].text : "")
                .font(Vida.serif(24))
                .foregroundStyle(Vida.forest)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.6), value: index)
                .accessibilityAddTraits(.updatesFrequently)
            Spacer()
            Button {
                isPaused.toggle()
                if isPaused { speaker.pause() } else { speaker.resume() }
            } label: {
                Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                    .font(Vida.sans(15, weight: .semibold))
                    .foregroundStyle(Vida.forest)
                    .frame(minWidth: 140, minHeight: 50)
                    .background(Vida.sage.opacity(0.2), in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(28)
        .task { await run() }
        .onDisappear { speaker.stop() }
    }

    private func run() async {
        startedAt = .now
        chime.ring()
        try? await Task.sleep(for: .seconds(3))
        for (position, segment) in script.segments.enumerated() {
            if Task.isCancelled { return }
            index = position
            await speaker.speak(segment.text)
            // Quiet time, paused while she's paused.
            var waited = 0.0
            while waited < segment.pauseSeconds {
                if Task.isCancelled { return }
                try? await Task.sleep(for: .milliseconds(250))
                if !isPaused { waited += 0.25 }
            }
        }
        guard !Task.isCancelled else { return }
        chime.ring()
        onFinish(Int(Date.now.timeIntervalSince(startedAt)))
    }
}

struct TimerRunner: View {
    let minutes: Int
    let onFinish: (Int) -> Void

    @State private var remaining = 0
    @State private var isPaused = false
    @State private var startedAt = Date.now
    @State private var chime = MeditationChime()

    private var total: Int { minutes * 60 }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle().stroke(Vida.sage.opacity(0.25), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: total == 0 ? 0 : CGFloat(total - remaining) / CGFloat(total))
                    .stroke(Vida.moss, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)
                Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                    .font(Vida.serif(44))
                    .foregroundStyle(Vida.forest)
                    .monospacedDigit()
            }
            .frame(width: 260, height: 260)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(remaining / 60) minutes \(remaining % 60) seconds left")

            Text("Sit comfortably and let your attention rest on your breath. When it wanders, gently bring it back.")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button { isPaused.toggle() } label: {
                Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                    .font(Vida.sans(15, weight: .semibold))
                    .foregroundStyle(Vida.forest)
                    .frame(minWidth: 140, minHeight: 50)
                    .background(Vida.sage.opacity(0.2), in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(28)
        .task { await run() }
    }

    private func run() async {
        remaining = total
        startedAt = .now
        chime.ring()
        while remaining > 0 {
            if Task.isCancelled { return }
            try? await Task.sleep(for: .seconds(1))
            if !isPaused { remaining -= 1 }
        }
        guard !Task.isCancelled else { return }
        chime.ring()
        onFinish(Int(Date.now.timeIntervalSince(startedAt)))
    }
}
