import SwiftUI

/// Vida Experiments: small personal studies that quietly teach scientific literacy.
struct ExperimentsView: View {
    @Environment(VidaStore.self) private var store
    @State private var showPaywall: Bool = false
    @State private var detail: Experiment?
    @State private var proposing: ExperimentTemplate?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    if !store.experiments.isEmpty { running }
                    if !store.isPlus { allowanceNote }
                    catalogue
                    literacyNote
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .vidaScrollChrome("The Lab")
            .vidaMenu()
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(item: $detail) { ExperimentDetailView(experiment: $0) }
        .sheet(item: $proposing) { template in
            ExperimentProposalView(template: template) {
                store.start(template)
                proposing = nil
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Vida.headline("Run a study\non ", accent: "yourself.")
                .tracking(Vida.displayTracking)
            Text("Pick a question, track two things for a couple of weeks, then read your own result. This is how real evidence gets made, at any scale.")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
        .vidaParallaxHeader()
    }

    private var running: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(eyebrow: "In progress", title: "Your experiments")
                .padding(.horizontal, 2)
            VStack(spacing: 12) {
                ForEach(store.experiments) { experiment in
                    Button {
                        detail = experiment
                    } label: {
                        RunningExperimentCard(
                            experiment: experiment,
                            elapsed: store.daysElapsed(in: experiment),
                            loggedToday: store.isLogged(experiment, on: store.today),
                            missingDays: store.missingDays(in: experiment).count
                        )
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    @ViewBuilder
    private var allowanceNote: some View {
        if store.freeExperimentsRemaining > 0 {
            HStack(spacing: 12) {
                Image(systemName: "flask")
                    .font(.system(size: 14))
                    .foregroundStyle(Vida.moss)
                Text("Vida Free runs \(VidaStore.freeExperimentLimit) experiments at a time. You have \(store.freeExperimentsRemaining) slot\(store.freeExperimentsRemaining == 1 ? "" : "s") open.")
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.inkSoft)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Vida.sage.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            PlusLockCard(
                title: "Both of your free labs are running",
                message: "Finish or end one to start another, or open Vida+ to run as many experiments at once as you like."
            ) { showPaywall = true }
        }
    }

    private var catalogue: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(eyebrow: "Choose a question", title: "The labs")
                .padding(.horizontal, 2)
            VStack(spacing: 12) {
                ForEach(ExperimentTemplate.all) { template in
                    let isRunning = store.isRunning(template)
                    Button {
                        if isRunning {
                            detail = store.experiments.first { $0.templateID == template.id }
                        } else if store.canStartExperiment {
                            proposing = template
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        LabCard(
                            template: template,
                            isRunning: isRunning,
                            isLocked: !isRunning && !store.canStartExperiment
                        )
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private var literacyNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "A note on method")
            Text("These are observational experiments, not controlled trials. You aren't randomised, you know what you're testing, and life interferes. That means a result here is a strong hint about you, not proof about anyone. Knowing that distinction is most of scientific literacy.")
                .font(Vida.sans(13))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Vida.sky.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct LabCard: View {
    let template: ExperimentTemplate
    let isRunning: Bool
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "flask")
                    .font(.system(size: 11))
                Text(template.labName.uppercased())
                    .font(Vida.sans(10, weight: .semibold))
                    .tracking(1.4)
                Spacer()
                if isRunning {
                    Text("RUNNING")
                        .font(Vida.sans(9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Vida.cream)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Vida.moss, in: Capsule())
                } else if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                }
            }
            .foregroundStyle(Vida.taupe)

            Text(template.question)
                .font(Vida.serif(19))
                .foregroundStyle(Vida.forest)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(template.blurb)
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                metaChip(systemImage: "calendar", text: "\(template.durationDays) days")
                metaChip(systemImage: template.driver.symbol, text: template.driver.title)
                metaChip(systemImage: "arrow.right", text: template.outcome.title)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }

    private func metaChip(systemImage: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 9))
            Text(text)
                .font(Vida.sans(11, weight: .medium))
        }
        .foregroundStyle(Vida.moss)
    }
}

struct RunningExperimentCard: View {
    let experiment: Experiment
    let elapsed: Int
    let loggedToday: Bool
    let missingDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow(text: experiment.title, color: Vida.moss)
                Spacer()
                Text("Day \(elapsed) of \(experiment.durationDays)")
                    .font(Vida.number(12))
                    .foregroundStyle(Vida.taupe)
            }

            Text(experiment.question)
                .font(Vida.serif(19))
                .foregroundStyle(Vida.forest)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            ProgressBar(progress: Double(elapsed) / Double(experiment.durationDays))
                .frame(height: 5)

            HStack(spacing: 6) {
                Image(systemName: loggedToday ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 11))
                Text(callToAction)
                    .font(Vida.sans(13, weight: .medium))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(loggedToday ? Vida.taupe : Vida.moss)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }

    /// Always tells her the single most useful next action for this study.
    private var callToAction: String {
        if elapsed >= experiment.durationDays { return "Finished: read your result" }
        if !loggedToday { return "Log today's two signals" }
        if missingDays > 0 {
            return "Today is in · \(missingDays) earlier day\(missingDays == 1 ? "" : "s") still open"
        }
        return "Fully logged so far: see where it stands"
    }
}

// MARK: - Proposal

struct ExperimentProposalView: View {
    @Environment(\.dismiss) private var dismiss
    let template: ExperimentTemplate
    let onStart: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: template.labName, color: Vida.moss)
                        Text(template.question)
                            .font(Vida.serif(27))
                            .foregroundStyle(Vida.forest)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)

                    protocolSection

                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "What you'll compare")
                        armRow(label: template.highArmLabel, color: Vida.moss)
                        armRow(label: template.lowArmLabel, color: Vida.taupe)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .paperCard(padding: 20)

                    Button {
                        onStart()
                    } label: {
                        Text("Start the experiment")
                            .font(Vida.sans(17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Vida.forest, in: Capsule())
                            .foregroundStyle(Vida.cream)
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(Vida.sans(15))
                        .foregroundStyle(Vida.inkSoft)
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
    }

    private var protocolSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow(text: "The protocol")
            step(1, "Log \(template.driver.title.lowercased()) and \(template.outcome.title.lowercased()) every day for \(template.durationDays) days.")
            step(2, "Vida splits your days into two groups based on your \(template.driver.title.lowercased()).")
            step(3, "At the end, you'll see how often \(template.outcome.title.lowercased()) showed up in each group, and what you can and can't conclude from that.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(Vida.serif(15))
                .foregroundStyle(Vida.cream)
                .frame(width: 24, height: 24)
                .background(Vida.moss, in: Circle())
            Text(text)
                .font(Vida.sans(15))
                .foregroundStyle(Vida.ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func armRow(label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(Vida.sans(15, weight: .medium))
                .foregroundStyle(Vida.ink)
        }
    }
}

// MARK: - Detail & result

struct ExperimentDetailView: View {
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let experiment: Experiment

    @State private var loggingDay: LogDay?
    @State private var confirmEnd: Bool = false

    private var result: ExperimentResult { store.result(for: experiment) }
    private var elapsed: Int { store.daysElapsed(in: experiment) }
    private var days: [ExperimentDay] { store.days(in: experiment) }
    private var loggedToday: Bool { store.isLogged(experiment, on: store.today) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "\(experiment.title) · Day \(elapsed) of \(experiment.durationDays)", color: Vida.moss)
                        Text(experiment.question)
                            .font(Vida.serif(27))
                            .foregroundStyle(Vida.forest)
                            .fixedSize(horizontal: false, vertical: true)
                        ProgressBar(progress: Double(elapsed) / Double(experiment.durationDays))
                            .frame(height: 5)
                            .padding(.top, 4)
                    }
                    .padding(.top, 8)

                    todayCard

                    ExperimentDayStrip(days: days) { date in
                        loggingDay = LogDay(date: date)
                    }

                    if result.hasEnoughData {
                        resultCard
                        conclusionCard
                        if elapsed >= experiment.durationDays { completionNote }
                    } else {
                        stillCollectingCard
                    }

                    Button(role: .destructive) {
                        confirmEnd = true
                    } label: {
                        Text(elapsed >= experiment.durationDays ? "Close this experiment" : "End this experiment early")
                            .font(Vida.sans(15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Vida.taupe.opacity(0.14), in: Capsule())
                            .foregroundStyle(Vida.inkSoft)
                    }
                    .buttonStyle(PressableStyle())
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
        .sheet(item: $loggingDay) { day in
            ExperimentDayLogView(experiment: experiment, date: day.date)
        }
        .alert(elapsed >= experiment.durationDays ? "Close this experiment?" : "End this experiment early?",
               isPresented: $confirmEnd) {
            Button(elapsed >= experiment.durationDays ? "Close it" : "End it", role: .destructive) {
                store.stop(experiment)
                dismiss()
            }
            Button("Keep it running", role: .cancel) { }
        } message: {
            Text("Everything you logged stays in your history and keeps feeding your Pattern Map. This only frees the lab slot.")
        }
    }

    /// The primary action of the whole screen: log today's two signals.
    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: loggedToday ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 14))
                    .foregroundStyle(loggedToday ? Vida.moss : Vida.taupe)
                Eyebrow(text: loggedToday ? "Today is logged" : "Today is open",
                        color: loggedToday ? Vida.moss : Vida.taupe)
            }

            Text(loggedToday
                 ? "Both signals are in for today. You can adjust them if something changed."
                 : "Log \(experiment.driver.title.lowercased()) and \(experiment.outcome.title.lowercased()) together. An experiment only gains a data point when it has both.")
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                todayReadout(experiment.driver)
                todayReadout(experiment.outcome)
            }

            Button {
                loggingDay = LogDay(date: store.today)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: loggedToday ? "pencil" : "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text(loggedToday ? "Edit today's entry" : "Log today")
                        .font(Vida.sans(16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(loggedToday ? Vida.sage.opacity(0.3) : Vida.forest, in: Capsule())
                .foregroundStyle(loggedToday ? Vida.forest : Vida.cream)
            }
            .buttonStyle(PressableStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }

    private func todayReadout(_ category: SignalCategory) -> some View {
        let reading = store.log(on: store.today)?.reading(for: category)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: category.symbol)
                    .font(.system(size: 10))
                    .foregroundStyle(category.accent)
                Text(category.title)
                    .font(Vida.sans(11))
                    .foregroundStyle(Vida.taupe)
            }
            Text(readingText(category, reading?.value))
                .font(Vida.number(19, weight: .regular))
                .foregroundStyle(reading == nil ? Vida.taupe : Vida.forest)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Vida.shell.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func readingText(_ category: SignalCategory, _ value: Double?) -> String {
        guard let value else { return "—" }
        guard category == .sleep else { return "\(Int(value))" }
        let hours = Int(value)
        let minutes = Int((value - Double(hours)) * 60)
        return "\(hours)h \(String(format: "%02d", minutes))m"
    }

    /// Empty state that tells her exactly how far off a readable result is.
    private var stillCollectingCard: some View {
        let needed = max(0, 2 - result.highArmDays) + max(0, 2 - result.lowArmDays)
        return VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Not readable yet")
            Text(needed == 0
                 ? "Keep logging. Your groups are nearly balanced."
                 : "About \(needed) more logged day\(needed == 1 ? "" : "s") before this can be read.")
                .font(Vida.serif(20))
                .foregroundStyle(Vida.forest)
                .fixedSize(horizontal: false, vertical: true)
            Text("A comparison needs at least two days in each group. You have \(result.highArmDays) in “\(experiment.highArmLabel.lowercased())” and \(result.lowArmDays) in “\(experiment.lowArmLabel.lowercased())”. Showing you a result before then would be guessing, and this app doesn't guess.")
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Eyebrow(text: "Your result so far")

            Text("\(experiment.outcome.title) showed up on:")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)

            armBar(label: experiment.highArmLabel, rate: result.highArmRate, days: result.highArmDays, color: Vida.moss)
            armBar(label: experiment.lowArmLabel, rate: result.lowArmRate, days: result.lowArmDays, color: Vida.blush)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }

    private func armBar(label: String, rate: Double, days: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(Vida.sans(14, weight: .medium))
                    .foregroundStyle(Vida.ink)
                Spacer()
                Text("\(Int(rate * 100))%")
                    .font(Vida.number(22, weight: .regular))
                    .foregroundStyle(Vida.forest)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Vida.shell)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * rate)
                }
            }
            .frame(height: 6)
            Text("\(days) day\(days == 1 ? "" : "s") in this group")
                .font(Vida.sans(11))
                .foregroundStyle(Vida.taupe)
        }
        .animation(.smooth(duration: 0.6), value: rate)
    }

    private var conclusionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "What can we conclude?", color: Vida.skyDeep)

            Text(conclusionText)
                .font(Vida.sans(15))
                .foregroundStyle(Vida.ink)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            HairlineDivider()

            Text(correlationCaveat)
                .font(Vida.sans(13))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Vida.sky.opacity(0.12), in: RoundedRectangle(cornerRadius: Vida.cardRadius, style: .continuous))
    }

    private var completionNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 15))
                .foregroundStyle(Vida.moss)
            Text("This experiment has run its full \(experiment.durationDays) days. Closing it keeps your logged data and frees the slot for another question.")
                .font(Vida.sans(13))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Vida.sage.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var correlationCaveat: String {
        let possibleConfounders = store.profile.tracksCycle
            ? "stress, your cycle, an illness, or a busy week"
            : "stress, an illness, a medication change, or a busy week"
        return "Correlation isn't causation. These two things moved together in your data, but a third factor (\(possibleConfounders)) could be driving both. What you have is a well-founded hypothesis about yourself, and that's genuinely useful."
    }

    private var conclusionText: String {
        let gap = abs(result.highArmRate - result.lowArmRate)
        if gap < 0.12 {
            return "The two groups look about the same so far. That's a real finding. It suggests \(experiment.driver.title.lowercased()) may not be the main driver of your \(experiment.outcome.title.lowercased()), and it frees you to look elsewhere."
        }
        let higher = result.highArmRate > result.lowArmRate ? experiment.highArmLabel : experiment.lowArmLabel
        let lower = result.highArmRate > result.lowArmRate ? experiment.lowArmLabel : experiment.highArmLabel
        return "There's a visible difference: \(experiment.outcome.title.lowercased()) appeared more often on \(higher.lowercased()) than on \(lower.lowercased()), a gap of about \(Int(gap * 100)) percentage points. That's worth taking seriously as a pattern in your life."
    }
}
