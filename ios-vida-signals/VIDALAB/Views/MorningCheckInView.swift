import SwiftUI
import UIKit

/// The short morning check-in: two questions, under a minute, straight into the
/// daily log.
///
/// The full flow asks about everything the morning can answer. Most mornings
/// nobody has the capacity for that, and a skipped check-in is worth nothing at
/// all. So this one asks the two things that carry the most weight in the
/// pattern engine — what the night was actually like, and what she thinks she
/// has in her today — and writes them as ordinary morning readings. Anything
/// logged here is indistinguishable from the long flow downstream.
struct MorningCheckInView: View {
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Called when she wants the full morning list instead.
    var onExpand: (() -> Void)?

    @State private var step: Step = .sleep
    @State private var hours: Double = 7.5
    @State private var quality: SleepQuality = .okay
    @State private var outlook: EnergyOutlook = .some
    @State private var savedFromHealth: Bool = false
    @State private var appeared: Bool = false

    private enum Step: Int, CaseIterable { case sleep, energy, done }

    var body: some View {
        NavigationStack {
            ZStack {
                VidaCanvas().ignoresSafeArea()
                DawnBackdrop(progress: backdropProgress)

                VStack(spacing: 0) {
                    if step != .done {
                        DawnArc(progress: step == .sleep ? 0.45 : 1)
                            .frame(height: 3)
                            .padding(.horizontal, 22)
                            .padding(.top, 4)
                    }

                    switch step {
                    case .sleep: sleepStep
                    case .energy: energyStep
                    case .done: doneStep
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step != .done {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { dismiss() }
                            .font(Vida.sans(15))
                            .foregroundStyle(Vida.inkSoft)
                    }
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 6) {
                            Image(systemName: "sunrise")
                                .font(.system(size: 10))
                            Text("MORNING · \(step == .sleep ? 1 : 2) OF 2")
                                .font(Vida.sans(12, weight: .semibold))
                                .tracking(1.6)
                        }
                        .foregroundStyle(Vida.taupe)
                    }
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
        .onAppear(perform: restoreDraft)
    }

    private var backdropProgress: Double {
        switch step {
        case .sleep: 0.2
        case .energy: 0.6
        case .done: 1
        }
    }

    /// Picks up whatever today already knows — her own earlier answer, or the
    /// night Apple Health already delivered — so she is never asked to retype it.
    private func restoreDraft() {
        guard !appeared else { return }
        appeared = true
        let draft = store.todayMorningDraft
        hours = draft.sleepHours
        quality = draft.quality
        outlook = draft.outlook
        savedFromHealth = store.morningSleepCameFromHealth
    }

    // MARK: - Step one: the night

    private var sleepStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How was\nthe night?")
                            .font(Vida.serif(34))
                            .foregroundStyle(Vida.forest)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(savedFromHealth
                             ? "Apple Health filled in the hours. Only you can say what they were like."
                             : "Two questions this morning. The rest can wait until tonight.")
                            .font(Vida.sans(15))
                            .foregroundStyle(Vida.inkSoft)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 14)

                    hoursCard

                    VStack(alignment: .leading, spacing: 12) {
                        Text("And how did it feel?")
                            .font(Vida.sans(15, weight: .semibold))
                            .foregroundStyle(Vida.ink)

                        VStack(spacing: 0) {
                            ForEach(Array(SleepQuality.allCases.enumerated()), id: \.element) { index, option in
                                QualityRow(option: option, isSelected: quality == option) {
                                    select(option)
                                }
                                if index < SleepQuality.allCases.count - 1 { HairlineDivider() }
                            }
                        }
                        .paperCard(padding: 6)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            footer(primary: "Next", secondary: nil) {
                advance(to: .energy)
            }
        }
    }

    private var hoursCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(MorningCheckIn.hoursLabel((hours * 4).rounded() / 4))
                    .font(Vida.serif(48))
                    .foregroundStyle(Vida.forest)
                    .contentTransition(.numericText())
                Text("asleep")
                    .font(Vida.sans(14))
                    .foregroundStyle(Vida.taupe)
                Spacer(minLength: 0)
                if savedFromHealth {
                    Text("FROM HEALTH")
                        .font(Vida.sans(9, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(Vida.skyDeep)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Vida.sky.opacity(0.18), in: Capsule())
                }
            }

            Slider(value: $hours, in: 0...12, step: 0.25)
                .tint(Vida.skyDeep)

            HStack {
                Text("None")
                Spacer()
                Text("12 hours")
            }
            .font(Vida.sans(12))
            .foregroundStyle(Vida.taupe)
        }
        .paperCard(padding: 20)
        .animation(Vida.Motion.gentle, value: hours)
    }

    private func select(_ option: SleepQuality) {
        guard quality != option else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) { quality = option }
    }

    // MARK: - Step two: the day ahead

    private var energyStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What do you\nhave today?")
                            .font(Vida.serif(34))
                            .foregroundStyle(Vida.forest)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("A guess is fine. Comparing what you expected against what the day actually took is where the useful part lives.")
                            .font(Vida.sans(15))
                            .foregroundStyle(Vida.inkSoft)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 14)

                    VStack(spacing: 14) {
                        EnergyGauge(level: outlook.rawValue)
                            .frame(height: 74)

                        Text(outlook.caption)
                            .font(Vida.sans(14))
                            .foregroundStyle(Vida.inkSoft)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .id(outlook)
                            .transition(.opacity)
                    }
                    .frame(maxWidth: .infinity)
                    .paperCard(padding: 20)

                    VStack(spacing: 0) {
                        ForEach(Array(EnergyOutlook.allCases.reversed().enumerated()), id: \.element) { index, option in
                            OutlookRow(option: option, isSelected: outlook == option) {
                                select(option)
                            }
                            if index < EnergyOutlook.allCases.count - 1 { HairlineDivider() }
                        }
                    }
                    .paperCard(padding: 6)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            footer(primary: "Log my morning", secondary: "Back") {
                finish()
            } onSecondary: {
                advance(to: .sleep)
            }
        }
    }

    private func select(_ option: EnergyOutlook) {
        guard outlook != option else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) { outlook = option }
    }

    // MARK: - Done

    private var doneStep: some View {
        VStack(spacing: 24) {
            Spacer()

            LeafProgressMark(progress: max(0.3, store.todayPeriodCompletion))
                .frame(width: 78, height: 104)

            VStack(spacing: 10) {
                Text("Morning logged.")
                    .font(Vida.serif(33))
                    .foregroundStyle(Vida.forest)
                Text(closingMessage)
                    .font(Vida.sans(15))
                    .foregroundStyle(Vida.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
            }

            HStack(spacing: 22) {
                LoggedStat(label: "Sleep", value: MorningCheckIn.hoursLabel((hours * 4).rounded() / 4), caption: quality.title)
                Rectangle()
                    .fill(Vida.hairline.opacity(0.6))
                    .frame(width: 0.7, height: 40)
                LoggedStat(label: "Energy", value: "\(Int(outlook.value))/10", caption: outlook.title)
            }
            .paperCard(padding: 18)
            .padding(.horizontal, 22)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(Vida.sans(17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Vida.forest, in: Capsule())
                        .foregroundStyle(Vida.onForest)
                }
                .buttonStyle(PressableStyle())

                if onExpand != nil {
                    Button {
                        dismiss()
                        onExpand?()
                    } label: {
                        Text("Add pain, mood or cycle")
                            .font(Vida.sans(15, weight: .medium))
                            .foregroundStyle(Vida.moss)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 14)
        }
    }

    private var closingMessage: String {
        if store.hasCompleted(.evening) {
            return "Both halves of today are in. That's the pairing the patterns are built from."
        }
        let days = store.loggedDayCount
        if days < 5 {
            return "Vida will ask again this evening. You're \(days) day\(days == 1 ? "" : "s") into building something readable."
        }
        return "Vida will ask again this evening. What the day cost you is the other half of the story."
    }

    // MARK: - Footer

    @ViewBuilder
    private func footer(
        primary: String,
        secondary: String?,
        action: @escaping () -> Void,
        onSecondary: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 0) {
            HairlineDivider()
            HStack(spacing: 12) {
                if let secondary, let onSecondary {
                    Button(action: onSecondary) {
                        Text(secondary)
                            .font(Vida.sans(16, weight: .medium))
                            .foregroundStyle(Vida.inkSoft)
                            .padding(.vertical, 17)
                            .padding(.horizontal, 20)
                    }
                    .buttonStyle(PressableStyle())
                }

                Button(action: action) {
                    Text(primary)
                        .font(Vida.sans(17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Vida.forest, in: Capsule())
                        .foregroundStyle(Vida.onForest)
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
        }
        .background(Vida.cream)
    }

    // MARK: - Actions

    private func advance(to next: Step) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.smooth(duration: 0.35)) { step = next }
    }

    private func finish() {
        store.logMorning(
            MorningCheckIn(sleepHours: hours, quality: quality, outlook: outlook)
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.smooth(duration: 0.45)) { step = .done }
    }
}

// MARK: - Pieces

/// One sleep-quality option: symbol, name, and the line that makes it concrete.
private struct QualityRow: View {
    let option: SleepQuality
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Vida.skyDeep.opacity(0.16) : Vida.shell.opacity(0.6))
                        .frame(width: 34, height: 34)
                    Image(systemName: option.symbol)
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(isSelected ? Vida.skyDeep : Vida.taupe)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(Vida.sans(15, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(Vida.ink)
                    Text(option.caption)
                        .font(Vida.sans(12))
                        .foregroundStyle(Vida.taupe)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Vida.moss)
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(isSelected ? 1 : 0.6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
    }
}

/// One energy-outlook option.
private struct OutlookRow: View {
    let option: EnergyOutlook
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                LevelPips(level: option.rawValue, isSelected: isSelected)
                    .frame(width: 34)

                Text(option.title)
                    .font(Vida.sans(15, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(Vida.ink)

                Spacer(minLength: 0)

                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Vida.moss)
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(isSelected ? 1 : 0.6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 13)
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Five small bars showing where a level sits, used in the option rows.
private struct LevelPips: View {
    let level: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { index in
                Capsule()
                    .fill(index <= level ? (isSelected ? Vida.moss : Vida.sage) : Vida.shell)
                    .frame(width: 4, height: 6 + CGFloat(index) * 2.6)
            }
        }
        .frame(height: 20, alignment: .bottom)
    }
}

/// The big animated readout at the top of the energy step.
private struct EnergyGauge: View {
    let level: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(1...5, id: \.self) { index in
                let active = index <= level
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(active ? Vida.moss.opacity(0.28 + Double(index) * 0.13) : Vida.shell)
                    .frame(height: 24 + CGFloat(index) * 10)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(active ? Vida.moss.opacity(0.45) : .clear, lineWidth: 0.8)
                    }
                    .scaleEffect(y: active ? 1 : 0.96, anchor: .bottom)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.68), value: level)
    }
}

/// Small labelled figure on the confirmation screen.
private struct LoggedStat: View {
    let label: String
    let value: String
    let caption: String

    var body: some View {
        VStack(spacing: 4) {
            Eyebrow(text: label)
            Text(value)
                .font(Vida.number(20, weight: .semibold))
                .foregroundStyle(Vida.forest)
            Text(caption)
                .font(Vida.sans(12))
                .foregroundStyle(Vida.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Two-segment progress line drawn as a shallow sunrise arc.
private struct DawnArc: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Vida.shell)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Vida.skyDeep, Vida.moss],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * min(1, max(0.04, progress)))
            }
        }
        .animation(.smooth(duration: 0.5), value: progress)
    }
}

/// A slow warm glow that rises as the flow progresses — dawn, not decoration.
private struct DawnBackdrop: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(Vida.blush.opacity(0.22))
                    .frame(width: geo.size.width * 1.1)
                    .blur(radius: 70)
                    .offset(x: -geo.size.width * 0.2,
                            y: geo.size.height * (0.62 - progress * 0.32))
                Circle()
                    .fill(Vida.sky.opacity(0.18))
                    .frame(width: geo.size.width * 0.9)
                    .blur(radius: 65)
                    .offset(x: geo.size.width * 0.34,
                            y: geo.size.height * (0.9 - progress * 0.45))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.smooth(duration: 0.9), value: progress)
    }
}
