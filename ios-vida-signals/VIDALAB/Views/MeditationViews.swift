import AVFoundation
import SwiftUI
import UIKit

// Vida+ meditation, in the spirit of Oura's sessions: breathe, follow a guided
// session, or sit with a timer, and see how it moved your stress.

/// Opens meditation from Today.
struct MeditationLaunchCard: View {
    @Environment(VidaStore.self) private var store
    @State private var isPresented = VidaDebugLaunch.flag("VidaOpenMeditation")

    private var moment: MeditationMoment { .at(.now) }

    var body: some View {
        Button { isPresented = true } label: {
            HStack(spacing: 14) {
                Image(systemName: moment == .night ? "moon.stars" : "wind")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Vida.moss)
                    .frame(width: 44, height: 44)
                    .background(Vida.sage.opacity(0.18), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Meditate")
                        .font(Vida.serif(19))
                        .foregroundStyle(Vida.forest)
                    Text("\(moment.title). A few minutes of breathing, a guided session, or a quiet timer.")
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
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
    case voiced(VoicedSession)
    case timer(Int)

    var id: String {
        switch self {
        case .breathing(let pattern): "breath-\(pattern.id)"
        case .guided(let item): "guided-\(item.id)"
        case .voiced(let session): "voiced-\(session.id)"
        case .timer(let minutes): "timer-\(minutes)"
        }
    }

    var title: String {
        switch self {
        case .breathing(let pattern): pattern.title
        case .guided(let item): item.title
        case .voiced(let session): session.title
        case .timer: "Quiet sit"
        }
    }

    var kind: MeditationKind {
        switch self {
        case .breathing: .breathing
        case .guided, .voiced: .guided
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
    @State private var showGuides = false
    @AppStorage(MeditationGuidePreference.key) private var guideID = MeditationGuidePreference.defaultID

    private static let voicedSessions = VoicedLibrary.loadSessions()

    private var stats: MeditationStats { MeditationStats.from(sessions) }
    private var moment: MeditationMoment { .at(.now) }
    private var guide: MeditationGuide { MeditationGuidePreference.guide(for: guideID) }

    private var meditations: [ApothecaryItem] {
        (content.apothecary.value ?? []).filter { $0.category == ApothecaryShelf.meditation.rawValue }
    }

    private var meditationIDs: [String] { meditations.map(\.id) }

    private var filters: [String] {
        let order = ["sleep", "mindfulness", "body-scan", "breathing", "morning", "grounding", "visualization", "loving-kindness"]
        let present = Set(meditations.compactMap(\.subcategory))
        return order.filter(present.contains)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Meditate", color: Vida.moss)
                        Text("A few quiet minutes.")
                            .font(Vida.serif(30))
                            .foregroundStyle(Vida.forest)
                        Text("Slow your breathing, follow a guided session, or sit with a timer. Check in before and after to see what it does for you.")
                            .font(Vida.sans(15))
                            .foregroundStyle(Vida.inkSoft)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    featuredCard
                    if !sessions.isEmpty { statsCard }
                    withAGuideSection
                    breatheSection
                    guidedSection
                    timerSection
                    if !store.isPlus { plusCard }
                    recentSection

                    Text("Meditation and breathing practices can help some people feel calmer, but they don't treat any condition. If a breathing exercise makes you dizzy or uncomfortable, stop and breathe normally.")
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
        .sheet(isPresented: $showGuides) { GuidePickerView() }
    }

    private func reload() {
        guard let userID = auth.user?.id else { return }
        sessions = MeditationLog.load(userID: userID)
    }

    private func start(_ plan: MeditationPlan, locked: Bool) {
        if locked { showPaywall = true } else { running = plan }
    }

    private func isLocked(_ pattern: BreathPattern) -> Bool { pattern.isPremium && !store.isPlus }

    private func isLocked(_ item: ApothecaryItem) -> Bool {
        if let pattern = GuidedScript.breathPattern(forTitle: item.title) { return isLocked(pattern) }
        return !store.isPlus && !MeditationAccess.isGuidedFree(item.id, in: meditationIDs)
    }

    /// A guided item as a plan, played as a breathing pattern when that's what it is.
    private func plan(for item: ApothecaryItem) -> MeditationPlan {
        if let pattern = GuidedScript.breathPattern(forTitle: item.title) { return .breathing(pattern) }
        return .guided(item)
    }

    // MARK: Sections

    /// One suggestion that fits the time of day, so there's nothing to decide.
    @ViewBuilder
    private var featuredCard: some View {
        let voiced = VoicedLibrary.suggestedID(for: moment, isPlus: store.isPlus, sessions: Self.voicedSessions)
            .flatMap { id in Self.voicedSessions.first { $0.id == id } }
        let guided = meditations.first { $0.subcategory == moment.guidedSubcategory && !isLocked($0) }
        let pattern = moment.breathPattern(isPlus: store.isPlus)
        if let target: (MeditationPlan, String, String) = voiced.map({ (.voiced($0), $0.title, "\($0.minutes) min · with \(guide.name), AI voice") })
            ?? guided.map({ (plan(for: $0), $0.title, [$0.durationMinutes.map { "\($0) min" }, "Guided"].compactMap { $0 }.joined(separator: " · ")) })
            ?? pattern.map({ (.breathing($0), $0.title, "Breathing · 3 min") }) {
            Button { running = target.0 } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Eyebrow(text: "For right now", color: MeditationNight.text.opacity(0.75))
                        Spacer()
                        Image(systemName: moment == .night || moment == .evening ? "moon.stars" : "sun.haze")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(MeditationNight.text.opacity(0.85))
                            .accessibilityHidden(true)
                    }
                    Text(moment.title)
                        .font(Vida.serif(26))
                        .foregroundStyle(MeditationNight.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(MeditationNight.background)
                            .frame(width: 34, height: 34)
                            .background(MeditationNight.text, in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(target.1).font(Vida.sans(15, weight: .semibold)).foregroundStyle(MeditationNight.text)
                            Text(target.2).font(Vida.sans(12)).foregroundStyle(MeditationNight.textSoft)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(MeditationNight.background)
                        .overlay(alignment: .topTrailing) {
                            Circle().fill(MeditationNight.glow.opacity(0.35)).frame(width: 180).blur(radius: 40).offset(x: 50, y: -60)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
            .buttonStyle(PressableStyle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("For right now: \(target.1), \(target.2)")
            .accessibilityHint("Starts the session")
        }
    }

    /// Scripted sessions in the chosen guide's voice.
    @ViewBuilder
    private var withAGuideSection: some View {
        if !Self.voicedSessions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(eyebrow: "With a guide", title: "Guided sessions")
                Button { showGuides = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.wave.2")
                            .font(.system(size: 15, weight: .light))
                            .foregroundStyle(Vida.moss)
                            .accessibilityHidden(true)
                        Text("Your guide: \(guide.name)")
                            .font(Vida.sans(14, weight: .semibold))
                            .foregroundStyle(Vida.forest)
                        AIVoiceTag()
                        Spacer(minLength: 0)
                        Text("Change")
                            .font(Vida.sans(13, weight: .medium))
                            .foregroundStyle(Vida.moss)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(Vida.sage.opacity(0.14), in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Your guide is \(guide.name), an AI voice")
                .accessibilityHint("Choose a different guide")

                ForEach(Self.voicedSessions) { session in
                    let locked = session.isPremium && !store.isPlus
                    planRow(symbol: "waveform", title: session.title, detail: "\(session.minutes) min · \(session.summary)", locked: locked) {
                        start(.voiced(session), locked: locked)
                    }
                }
            }
        }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            stat("\(stats.minutesThisWeek)", "min this week")
            Divider().frame(height: 36)
            stat("\(stats.streakDays)", stats.streakDays == 1 ? "day in a row" : "days in a row")
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
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(eyebrow: "Breathe", title: "Paced breathing")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(BreathPattern.all) { pattern in
                    breathTile(pattern)
                }
            }
        }
    }

    private func breathTile(_ pattern: BreathPattern) -> some View {
        let locked = isLocked(pattern)
        return Button { start(.breathing(pattern), locked: locked) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    BreathGlyph(pattern: pattern)
                    Spacer()
                    if locked { PlusBadge() }
                }
                Text(pattern.title)
                    .font(Vida.sans(15, weight: .semibold))
                    .foregroundStyle(Vida.forest)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(pattern.rhythm)
                    .font(Vida.sans(12))
                    .foregroundStyle(Vida.inkSoft)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .paperCard(padding: 14)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pattern.title). \(pattern.summary)\(locked ? " Vida Plus." : "")")
        .accessibilityHint(locked ? "Shows Vida Plus" : "Starts the session")
    }

    @ViewBuilder
    private var guidedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(eyebrow: "Library", title: "Read aloud by your device")
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
                    let locked = isLocked(item)
                    planRow(
                        symbol: "leaf",
                        title: item.title,
                        detail: [item.durationMinutes.map { "\($0) min" }, item.summary].compactMap { $0 }.joined(separator: " · "),
                        locked: locked
                    ) { start(plan(for: item), locked: locked) }
                }
            }
        }
    }

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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

    /// Shown to free members after the free sessions, not in front of them.
    private var plusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Vida+", color: Vida.moss)
            Text("Every session, every night.")
                .font(Vida.serif(22))
                .foregroundStyle(Vida.forest)
            Text("Vida+ opens Clear the fog, the Flare-day body scan, and Wind down, box and 4-7-8 breathing, and the full library: sleep, body scans, grounding, and more.")
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
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

    private func planRow(symbol: String, title: String, detail: String, locked: Bool, action: @escaping () -> Void) -> some View {
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
                if locked {
                    PlusBadge()
                } else {
                    Image(systemName: "play.circle")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Vida.moss)
                        .accessibilityHidden(true)
                }
            }
            .paperCard(padding: 16)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(locked ? "Part of Vida Plus" : "Starts the session")
    }
}

/// The small "Vida+" marker on sessions that need it.
struct PlusBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "lock.fill").font(.system(size: 8, weight: .bold))
            Text("VIDA+").font(Vida.sans(9, weight: .bold)).tracking(1)
        }
        .foregroundStyle(Vida.cream)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Vida.moss, in: Capsule())
        .accessibilityLabel("Vida Plus")
    }
}

/// A tiny drawing of a pattern's rhythm: one bar per phase, height by length.
struct BreathGlyph: View {
    let pattern: BreathPattern

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(pattern.phases.enumerated()), id: \.offset) { _, step in
                Capsule()
                    .fill(step.phase == .holdIn || step.phase == .holdOut ? Vida.sage.opacity(0.5) : Vida.moss)
                    .frame(width: 6, height: 6 + step.seconds * 2.6)
            }
        }
        .frame(height: 28, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

/// The dim palette a session runs in: the same in light and dark mode, so the
/// room stays dark and the screen never flares.
enum MeditationNight {
    static let background = Color(red: 0.075, green: 0.118, blue: 0.098)
    static let glow = Color(red: 0.36, green: 0.55, blue: 0.45)
    static let glowCool = Color(red: 0.34, green: 0.46, blue: 0.58)
    static let text = Color(red: 0.93, green: 0.91, blue: 0.86)
    static let textSoft = Color(red: 0.93, green: 0.91, blue: 0.86).opacity(0.62)
}

/// Slow, soft light behind a running session. Still with Reduce Motion on.
struct MeditationBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        ZStack {
            MeditationNight.background
            Circle()
                .fill(MeditationNight.glow.opacity(0.28))
                .frame(width: 360)
                .blur(radius: 90)
                .offset(x: drift ? 90 : 40, y: drift ? -250 : -300)
            Circle()
                .fill(MeditationNight.glowCool.opacity(0.22))
                .frame(width: 320)
                .blur(radius: 90)
                .offset(x: drift ? -110 : -60, y: drift ? 280 : 330)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) { drift = true }
        }
    }
}

// MARK: - Session

/// The whole session: stress check, the practice, stress check, summary.
struct MeditationSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var auth

    let plan: MeditationPlan
    @AppStorage(MeditationGuidePreference.key) private var guideID = MeditationGuidePreference.defaultID

    private enum Stage { case before, running, after, done }

    @State private var stage: Stage = .before
    @State private var minutes = 3
    @State private var stressBefore: Int?
    @State private var stressAfter: Int?
    @State private var startedAt = Date.now
    @State private var elapsed = 0
    @State private var weekStats: MeditationStats?

    var body: some View {
        ZStack {
            // The room goes dim while the session runs, and comes back after.
            if stage == .running {
                MeditationBackdrop().transition(.opacity)
            } else {
                Vida.cream.ignoresSafeArea().transition(.opacity)
            }
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    // The summary has its own Done button.
                    if stage != .done {
                        Button(stage == .running ? "End" : "Close") { closeTapped() }
                            .font(Vida.sans(15, weight: .semibold))
                            .foregroundStyle(stage == .running ? MeditationNight.textSoft : Vida.moss)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
                .frame(minHeight: 44)
                .padding(.horizontal, 20)

                switch stage {
                case .before:
                    StressCheckView(
                        title: plan.title,
                        intro: introText,
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
                        intro: nil,
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
        .animation(.easeInOut(duration: 1.2), value: stage)
        .preferredColorScheme(stage == .running ? .dark : nil)
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            MeditationAudioSession.end()
        }
    }

    /// What to expect, in a line or two.
    private var introText: String {
        switch plan {
        case .breathing(let pattern):
            return "\(pattern.summary) Follow the circle: it grows as you breathe in and settles as you breathe out."
        case .guided(let item):
            let script = GuidedScript.make(title: item.title, content: item.content ?? item.summary ?? "", minutes: item.durationMinutes ?? 5)
            let length = "About \(item.durationMinutes ?? 5) minutes, read aloud one step at a time with quiet in between. Headphones help."
            return script.tip.map { "\(length) Tip: \($0)" } ?? length
        case .voiced(let session):
            let guide = MeditationGuidePreference.guide(for: guideID)
            return "\(session.summary) Guided by \(guide.name), an AI voice. Headphones help."
        case .timer(let minutes):
            return "\(minutes) minutes of quiet, with a soft bell at the start and the end."
        }
    }

    private var durationChoices: [Int] {
        switch plan {
        case .breathing: [1, 3, 5, 10]
        case .guided, .voiced, .timer: []
        }
    }

    @ViewBuilder
    private var running: some View {
        switch plan {
        case .breathing(let pattern):
            BreathingRunner(pattern: pattern, minutes: minutes, onFinish: completed)
        case .guided(let item):
            GuidedRunner(script: GuidedScript.make(title: item.title, content: item.content ?? item.summary ?? "", minutes: item.durationMinutes ?? 5), onFinish: completed)
        case .voiced(let session):
            VoicedRunner(session: session, guide: MeditationGuidePreference.guide(for: guideID), onFinish: completed)
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
            if let weekStats, weekStats.sessionsThisWeek > 0 {
                Text(weekStats.streakDays > 1
                     ? "\(weekStats.minutesThisWeek) minutes this week, \(weekStats.streakDays) days in a row."
                     : "\(weekStats.minutesThisWeek) minutes this week.")
                    .font(Vida.sans(14))
                    .foregroundStyle(Vida.taupe)
            }
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
        if let userID = auth.user?.id {
            weekStats = MeditationStats.from(MeditationLog.load(userID: userID))
        }
        stage = .done
    }
}

/// A 0-to-10 stress check with an optional length choice. "Skip" leaves the
/// answer empty rather than guessing.
struct StressCheckView: View {
    let title: String
    var intro: String?
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
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(Vida.serif(30))
                    .foregroundStyle(Vida.forest)
                    .fixedSize(horizontal: false, vertical: true)
                if let intro {
                    Text(intro)
                        .font(Vida.sans(15))
                        .foregroundStyle(Vida.inkSoft)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

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

/// A thin line across the top of a running session.
struct SessionProgressLine: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(MeditationNight.text.opacity(0.12))
                Capsule()
                    .fill(MeditationNight.text.opacity(0.55))
                    .frame(width: geo.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(height: 3)
        .animation(.linear(duration: 0.8), value: fraction)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(min(1, max(0, fraction)) * 100)) percent")
    }
}

/// Pause and resume, in the session's dim style.
struct SessionPauseButton: View {
    @Binding var isPaused: Bool
    var onChange: (Bool) -> Void = { _ in }

    var body: some View {
        Button {
            isPaused.toggle()
            onChange(isPaused)
        } label: {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 20))
                .foregroundStyle(MeditationNight.background)
                .frame(width: 64, height: 64)
                .background(MeditationNight.text, in: Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(isPaused ? "Resume" : "Pause")
        .sensoryFeedback(.selection, trigger: isPaused)
    }
}

struct BreathingRunner: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let pattern: BreathPattern
    let minutes: Int
    let onFinish: (Int) -> Void

    @State private var phase: BreathPattern.Phase = .inhale
    @State private var phaseTick = 0
    @State private var phaseEndsAt = Date.now
    @State private var scale: CGFloat = 0.55
    @State private var cycle = 1
    @State private var startedAt = Date.now
    private let chime = MeditationChime.shared

    private var totalCycles: Int { pattern.cycles(forMinutes: minutes) }

    var body: some View {
        VStack(spacing: 28) {
            SessionProgressLine(fraction: Double(cycle - 1) / Double(max(1, totalCycles)))
                .padding(.top, 8)
            Spacer()
            ZStack {
                // Three soft rings that breathe together, the outer ones lagging.
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .fill(MeditationNight.glow.opacity(0.10 + Double(ring) * 0.12))
                        .frame(width: 290, height: 290)
                        .scaleEffect(reduceMotion ? 0.8 - CGFloat(ring) * 0.1 : scale * (1 - CGFloat(ring) * 0.14))
                        .opacity(reduceMotion ? (phase == .exhale || phase == .holdOut ? 0.5 : 1) : 1)
                        .animation(reduceMotion ? .easeInOut(duration: 0.8) : nil, value: phase)
                }
                VStack(spacing: 6) {
                    Text(phase.rawValue)
                        .font(Vida.serif(26))
                        .foregroundStyle(MeditationNight.text)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.4), value: phase)
                    TimelineView(.periodic(from: .now, by: 0.25)) { context in
                        Text("\(max(1, Int(phaseEndsAt.timeIntervalSince(context.date).rounded(.up))))")
                            .font(Vida.sans(15, weight: .medium))
                            .foregroundStyle(MeditationNight.textSoft)
                            .monospacedDigit()
                    }
                }
            }
            .frame(width: 290, height: 290)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(phase.rawValue)
            .accessibilityAddTraits(.updatesFrequently)

            Text("Breath \(cycle) of \(totalCycles)")
                .font(Vida.sans(14))
                .foregroundStyle(MeditationNight.textSoft)
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: phaseTick)
        .task { await run() }
    }

    private func run() async {
        startedAt = .now
        chime.ring()
        for index in 1...totalCycles {
            cycle = index
            for step in pattern.phases {
                if Task.isCancelled { return }
                phase = step.phase
                phaseTick += 1
                phaseEndsAt = .now.addingTimeInterval(step.seconds)
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

    @State private var index = -1
    @State private var isPaused = false
    @State private var startedAt = Date.now
    @State private var speaker = MeditationSpeaker()
    private let chime = MeditationChime.shared
    /// Text only, for a quiet room or a shared one. Kept between sessions.
    @AppStorage("meditation.voiceOn") private var voiceOn = true

    private var currentText: String {
        script.segments.indices.contains(index) ? script.segments[index].text : "Settle in. The first step begins in a moment."
    }

    var body: some View {
        VStack(spacing: 24) {
            SessionProgressLine(fraction: Double(max(0, index)) / Double(max(1, script.segments.count)))
                .padding(.top, 8)
            Spacer()
            Text(currentText)
                .font(Vida.serif(25))
                .foregroundStyle(MeditationNight.text.opacity(isPaused ? 0.5 : 1))
                .multilineTextAlignment(.center)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
                .id(index)
                .transition(.opacity)
                .accessibilityAddTraits(.updatesFrequently)
            Spacer()
            HStack(spacing: 36) {
                Button {
                    voiceOn.toggle()
                    if !voiceOn { speaker.stop() }
                } label: {
                    Image(systemName: voiceOn ? "speaker.wave.2" : "speaker.slash")
                        .font(.system(size: 18))
                        .foregroundStyle(MeditationNight.text)
                        .frame(width: 48, height: 48)
                        .background(MeditationNight.text.opacity(0.12), in: Circle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(voiceOn ? "Switch to text only" : "Read aloud")

                SessionPauseButton(isPaused: $isPaused) { paused in
                    if paused { speaker.pause() } else { speaker.resume() }
                }

                // Balances the voice button so pause stays centered.
                Color.clear.frame(width: 48, height: 48)
            }
            Text(voiceOn ? "Read aloud by your device's voice" : "Text only")
                .font(Vida.sans(12))
                .foregroundStyle(MeditationNight.textSoft)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
        .animation(.easeInOut(duration: 0.9), value: index)
        .task { await run() }
        .onDisappear { speaker.stop() }
    }

    private func run() async {
        startedAt = .now
        chime.ring()
        try? await Task.sleep(for: .seconds(4))
        for (position, segment) in script.segments.enumerated() {
            if Task.isCancelled { return }
            index = position
            if voiceOn {
                await speaker.speak(segment.text)
            } else {
                // Time to read it, the same as hearing it.
                await wait(GuidedScript.speakingSeconds(segment.text))
            }
            // Quiet time, paused while she's paused.
            await wait(segment.pauseSeconds)
        }
        guard !Task.isCancelled else { return }
        chime.ring()
        onFinish(Int(Date.now.timeIntervalSince(startedAt)))
    }

    private func wait(_ seconds: Double) async {
        var waited = 0.0
        while waited < seconds {
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(250))
            if !isPaused { waited += 0.25 }
        }
    }
}

struct TimerRunner: View {
    let minutes: Int
    let onFinish: (Int) -> Void

    @State private var remaining = 0
    @State private var isPaused = false
    @State private var startedAt = Date.now
    private let chime = MeditationChime.shared

    private var total: Int { minutes * 60 }

    /// A new, gentle line every couple of minutes, so a long sit has company.
    private var cue: String {
        let cues = [
            "Sit comfortably and let your attention rest on your breath.",
            "When your mind wanders, notice where it went, and come back.",
            "Let your shoulders drop and your jaw soften.",
            "Nothing to fix. Breathing is enough.",
        ]
        let elapsed = total - remaining
        return cues[(elapsed / 120) % cues.count]
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle().stroke(MeditationNight.text.opacity(0.12), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: total == 0 ? 0 : CGFloat(total - remaining) / CGFloat(total))
                    .stroke(MeditationNight.text.opacity(0.7), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)
                Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                    .font(Vida.serif(46))
                    .foregroundStyle(MeditationNight.text.opacity(isPaused ? 0.5 : 1))
                    .monospacedDigit()
            }
            .frame(width: 260, height: 260)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(remaining / 60) minutes \(remaining % 60) seconds left")

            Text(cue)
                .font(Vida.sans(15))
                .foregroundStyle(MeditationNight.textSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 1.2), value: cue)
            Spacer()
            SessionPauseButton(isPaused: $isPaused)
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

// MARK: - Guides

/// The chosen guide, remembered on this device.
enum MeditationGuidePreference {
    static let key = "meditation.guideID"
    static let guides = VoicedLibrary.loadGuides()
    static var defaultID: String { guides.first?.id ?? "guide" }

    static func guide(for id: String) -> MeditationGuide {
        guides.first { $0.id == id } ?? guides.first ?? MeditationGuide(id: "guide", name: "Your guide", description: "")
    }
}

/// "AI voice", shown wherever a guide is chosen or heard.
struct AIVoiceTag: View {
    var onDark = false

    var body: some View {
        Text("AI voice")
            .font(Vida.sans(10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(onDark ? MeditationNight.text : Vida.moss)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .overlay { Capsule().strokeBorder(onDark ? MeditationNight.text.opacity(0.4) : Vida.moss.opacity(0.5), lineWidth: 0.8) }
    }
}

/// Choose who guides your sessions, with a short preview of each.
struct GuidePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(MeditationGuidePreference.key) private var guideID = MeditationGuidePreference.defaultID
    @State private var previewing: String?
    @State private var player: AVPlayer?
    @State private var previewTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose your guide")
                            .font(Vida.serif(28))
                            .foregroundStyle(Vida.forest)
                        Text("Every guide is an AI-generated voice, made for VIDA LAB with ElevenLabs. No one sat down and recorded these sessions. Tap play to hear a few seconds.")
                            .font(Vida.sans(14))
                            .foregroundStyle(Vida.inkSoft)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(MeditationGuidePreference.guides) { guide in
                        row(guide)
                    }
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
        .onDisappear(perform: stopPreview)
    }

    private func row(_ guide: MeditationGuide) -> some View {
        let selected = guide.id == guideID
        return HStack(spacing: 14) {
            Button { togglePreview(guide) } label: {
                Image(systemName: previewing == guide.id ? "stop.fill" : "play.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Vida.onForest)
                    .frame(width: 44, height: 44)
                    .background(Vida.moss, in: Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(previewing == guide.id ? "Stop preview" : "Preview \(guide.name)")

            Button {
                guideID = guide.id
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(guide.name).font(Vida.sans(16, weight: .semibold)).foregroundStyle(Vida.forest)
                            AIVoiceTag()
                        }
                        Text(guide.description)
                            .font(Vida.sans(13))
                            .foregroundStyle(Vida.inkSoft)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(selected ? Vida.moss : Vida.hairline)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(guide.name), AI voice. \(guide.description)")
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        }
        .paperCard(padding: 14)
    }

    private func togglePreview(_ guide: MeditationGuide) {
        if previewing == guide.id {
            stopPreview()
            return
        }
        stopPreview()
        guard let url = GuideAudioService.shared.previewURL(guide: guide.id) else { return }
        MeditationAudioSession.begin()
        let item = AVPlayerItem(url: url)
        // Skip the quiet lead-in so the voice starts right away.
        item.seek(to: CMTime(seconds: 2, preferredTimescale: 600), completionHandler: nil)
        let player = AVPlayer(playerItem: item)
        self.player = player
        previewing = guide.id
        player.play()
        previewTask = Task {
            try? await Task.sleep(for: .seconds(12))
            if !Task.isCancelled { stopPreview() }
        }
    }

    private func stopPreview() {
        previewTask?.cancel()
        player?.pause()
        player = nil
        previewing = nil
    }
}

/// Plays a guide's recording with the words following along, and falls back
/// to the device's voice reading the same script if the file can't be had.
struct VoicedRunner: View {
    let session: VoicedSession
    let guide: MeditationGuide
    let onFinish: (Int) -> Void

    private enum Mode { case loading, playing, fallback }

    @State private var mode: Mode = .loading
    @State private var player: AVAudioPlayer?
    @State private var cues: [VoicedCue] = []
    @State private var duration: Double = 1
    @State private var now: Double = 0
    @State private var isPaused = false
    @State private var startedAt = Date.now
    private let chime = MeditationChime.shared

    private var cueIndex: Int? { VoicedLibrary.cueIndex(at: now, in: cues) }

    private var currentText: String {
        guard let index = cueIndex, session.segments.indices.contains(index) else {
            return mode == .loading ? "Getting \(guide.name) ready." : "Settle in. \(guide.name) will begin in a moment."
        }
        return session.segments[index].text
    }

    var body: some View {
        Group {
            if mode == .fallback {
                GuidedRunner(script: session.fallbackScript, onFinish: onFinish)
            } else {
                VStack(spacing: 24) {
                    SessionProgressLine(fraction: now / max(1, duration))
                        .padding(.top, 8)
                    Spacer()
                    Text(currentText)
                        .font(Vida.serif(25))
                        .foregroundStyle(MeditationNight.text.opacity(isPaused ? 0.5 : 1))
                        .multilineTextAlignment(.center)
                        .lineSpacing(7)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(cueIndex ?? -1)
                        .transition(.opacity)
                        .accessibilityAddTraits(.updatesFrequently)
                    Spacer()
                    if mode == .loading {
                        ProgressView().tint(MeditationNight.text).frame(height: 64)
                    } else {
                        SessionPauseButton(isPaused: $isPaused) { paused in
                            if paused { player?.pause() } else { player?.play() }
                        }
                    }
                    HStack(spacing: 8) {
                        Text("Guided by \(guide.name)")
                            .font(Vida.sans(12))
                            .foregroundStyle(MeditationNight.textSoft)
                        AIVoiceTag(onDark: true)
                    }
                    .accessibilityElement(children: .combine)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
                .animation(.easeInOut(duration: 0.9), value: cueIndex)
            }
        }
        .task { await run() }
        .onDisappear { player?.stop() }
    }

    private func run() async {
        startedAt = .now
        do {
            let (file, entry) = try await GuideAudioService.shared.audio(guide: guide.id, session: session.id)
            let player = try AVAudioPlayer(contentsOf: file)
            player.prepareToPlay()
            self.player = player
            cues = entry.cues
            duration = max(1, player.duration)
        } catch {
            // Offline, or the file isn't there: the device reads the same words.
            mode = .fallback
            return
        }
        chime.ring()
        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled, let player else { return }
        mode = .playing
        player.play()
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(250))
            if player.isPlaying || isPaused {
                now = player.currentTime
                continue
            }
            // Stopped without a tap on pause. Near the end, the recording is
            // over; anywhere else, a call or another app interrupted it, so
            // it waits as paused instead of ending the session.
            if now >= duration - 4 { break }
            isPaused = true
        }
        guard !Task.isCancelled else { return }
        now = duration
        chime.ring()
        onFinish(Int(Date.now.timeIntervalSince(startedAt)))
    }
}
