import SwiftUI
import MessageUI

/// A week, read back to her.
///
/// This is deliberately the least "app-like" screen in VIDA LAB — it is closer
/// to a printed summary than a dashboard, because its job is to be handed over,
/// sent, or simply believed. Nothing here is scored, ranked, or gamified.
struct WeeklyReportView: View {
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var weeksAgo: Int = 0
    @State private var showMailComposer: Bool = false
    @State private var showEmailSetup: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var showPaywall: Bool = false
    @State private var mailUnavailable: Bool = false

    private var report: WeeklyReport { store.weeklyReport(weeksAgo: weeksAgo) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    weekPicker
                    hero
                    if report.hasEnoughData {
                        consistencyCard
                        if !report.focusChanges.isEmpty { signalsSection }
                        dayExtremes
                        if !report.newConnections.isEmpty { connectionsSection }
                        if !report.runningExperiments.isEmpty { experimentsSection }
                    } else {
                        // Names the actual count and offers the way forward,
                        // rather than a bare "nothing here".
                        QuietEmptyState(
                            symbol: "calendar",
                            title: store.loggedDayCount == 0 ? "Nothing logged yet" : "Not enough for a summary",
                            message: store.loggedDayCount == 0
                                ? "Once you've checked in a few times, this becomes a week you can read, send, or hand to a doctor."
                                : "You've logged \(store.loggedDayCount) day\(store.loggedDayCount == 1 ? "" : "s"). Vida won't summarise a week it doesn't have — a few more check-ins and this fills in."
                        )
                        .paperCard(padding: 8)
                    }
                    nextStepCard
                    sendSection
                    disclaimer
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("YOUR WEEK")
                        .font(Vida.sans(12, weight: .bold))
                        .tracking(2.4)
                        .foregroundStyle(Vida.forest)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Vida.sans(15, weight: .medium))
                        .foregroundStyle(Vida.moss)
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
        .sheet(isPresented: $showEmailSetup) {
            ReportEmailSetupView { sendNow() }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [report.plainText])
        }
        .sheet(isPresented: $showMailComposer) {
            MailComposeView(
                recipient: store.reportEmail,
                subject: "Your VIDA LAB week — \(report.rangeLabel)",
                body: report.plainText
            ) { sent in
                if sent { store.markReportSent() }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert("Mail isn't set up", isPresented: $mailUnavailable) {
            Button("Share instead") { showShareSheet = true }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This device has no Mail account configured. You can still share the report to any app — including your notes, or a message to yourself.")
        }
    }

    // MARK: - Week picker

    @ViewBuilder
    private var weekPicker: some View {
        if store.loggedDayCount > 7 {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(0..<max(1, store.reportHistoryWeeks), id: \.self) { offset in
                        SelectChip(
                            label: offset == 0 ? "This week" : (offset == 1 ? "Last week" : "\(offset) weeks ago"),
                            isSelected: weeksAgo == offset
                        ) {
                            withAnimation(.snappy) { weeksAgo = offset }
                        }
                    }
                    if !store.isPlus {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 9))
                                Text("Full archive")
                            }
                            .font(Vida.sans(14))
                            .foregroundStyle(Vida.moss)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 10)
                            .background { Capsule().fill(Vida.sage.opacity(0.16)) }
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: report.rangeLabel)
            Text(report.headline)
                .font(Vida.serif(29))
                .foregroundStyle(Vida.forest)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if !report.conditionNames.isEmpty {
                Text("Focused on what matters for \(report.conditionNames.joined(separator: ", ").lowercased()).")
                    .font(Vida.sans(14))
                    .foregroundStyle(Vida.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Consistency

    private var consistencyCard: some View {
        HStack(spacing: 18) {
            ZStack {
                ProgressRing(progress: report.consistency, lineWidth: 6)
                    .frame(width: 52, height: 52)
                Text("\(Int(report.consistency * 100))")
                    .font(Vida.number(16))
                    .foregroundStyle(Vida.forest)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(report.checkInsCompleted) of \(report.possibleCheckIns) check-ins")
                    .font(Vida.sans(15, weight: .medium))
                    .foregroundStyle(Vida.forest)
                Text("across \(report.daysLogged) day\(report.daysLogged == 1 ? "" : "s")")
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.inkSoft)
            }

            Spacer(minLength: 0)
        }
        .paperCard(padding: 18)
    }

    // MARK: - Signals

    private var signalsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(eyebrow: "Compared with last week", title: "Your key signals")
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
                ForEach(Array(report.focusChanges.enumerated()), id: \.element.id) { index, change in
                    WeeklyChangeRow(change: change)
                    if index < report.focusChanges.count - 1 { HairlineDivider() }
                }
            }
            .paperCard(padding: 18)
        }
    }

    // MARK: - Best and hardest day

    @ViewBuilder
    private var dayExtremes: some View {
        if report.bestDay != nil || report.hardestDay != nil {
            HStack(spacing: 12) {
                if let best = report.bestDay {
                    dayCard(title: "Easiest day", date: best.date, tint: Vida.moss, symbol: "sun.max")
                }
                if let hardest = report.hardestDay {
                    dayCard(title: "Hardest day", date: hardest.date, tint: Vida.blush, symbol: "cloud.rain")
                }
            }
        }
    }

    private func dayCard(title: String, date: Date, tint: Color, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(tint)
            Text(title)
                .font(Vida.sans(12))
                .foregroundStyle(Vida.taupe)
            Text(date.formatted(.dateTime.weekday(.wide)))
                .font(Vida.serif(19))
                .foregroundStyle(Vida.forest)
            Text(date.formatted(.dateTime.day().month(.abbreviated)))
                .font(Vida.sans(12))
                .foregroundStyle(Vida.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 16)
    }

    // MARK: - Connections

    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(eyebrow: "Worth noticing", title: "Patterns this week")
                .padding(.horizontal, 2)

            VStack(spacing: 10) {
                ForEach(report.newConnections) { link in
                    HStack(alignment: .top, spacing: 12) {
                        ConnectionGlyph(strength: link.magnitude)
                            .frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(PatternExplainer.shortMeaning(for: link))
                                .font(Vida.sans(15, weight: .medium))
                                .foregroundStyle(Vida.forest)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(PatternExplainer.confidence(for: link).rawValue) · \(link.sampleSize) days")
                                .font(Vida.sans(12))
                                .foregroundStyle(Vida.taupe)
                        }
                        Spacer(minLength: 0)
                    }
                    .paperCard(padding: 16)
                }
            }
        }
    }

    private var experimentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Running in the Lab")
            ForEach(report.runningExperiments, id: \.self) { title in
                HStack(spacing: 10) {
                    Image(systemName: "flask")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Vida.moss)
                    Text(title)
                        .font(Vida.sans(14))
                        .foregroundStyle(Vida.ink)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 18)
    }

    // MARK: - Next step

    private var nextStepCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "What to do next", color: Vida.moss)
            Text(report.nextStep)
                .font(Vida.sans(15))
                .foregroundStyle(Vida.ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Vida.sage.opacity(0.16), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Send

    private var sendSection: some View {
        VStack(spacing: 10) {
            Button {
                if store.reportEmail.isEmpty {
                    showEmailSetup = true
                } else {
                    sendNow()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "envelope")
                        .font(.system(size: 14))
                    Text(store.reportEmail.isEmpty ? "Email this to me" : "Send to \(store.reportEmail)")
                        .lineLimit(1)
                }
                .font(Vida.sans(16, weight: .semibold))
                .foregroundStyle(Vida.onForest)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Vida.forest, in: Capsule())
            }
            .buttonStyle(PressableStyle())

            Button {
                showShareSheet = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13))
                    Text("Share or save")
                }
                .font(Vida.sans(15, weight: .medium))
                .foregroundStyle(Vida.moss)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(PressableStyle())

            if !store.reportEmail.isEmpty {
                Button {
                    showEmailSetup = true
                } label: {
                    Text("Change email address")
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.taupe)
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.top, 4)
    }

    private func sendNow() {
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            mailUnavailable = true
        }
    }

    private var disclaimer: some View {
        Text("This is a record of what you logged, not a diagnosis. Two things moving together doesn't mean one caused the other. VIDA LAB is an educational tool and doesn't replace care from a qualified clinician.")
            .font(Vida.sans(11))
            .foregroundStyle(Vida.taupe)
            .lineSpacing(4)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }
}

/// One signal's week-over-week movement, with direction stated in words.
struct WeeklyChangeRow: View {
    let change: WeeklySignalChange

    private var tint: Color {
        switch change.isImprovement {
        case true?: Vida.moss
        case false?: Vida.blush
        default: Vida.taupe
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: change.category.symbol)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(change.category.accent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(change.category.title)
                    .font(Vida.sans(14, weight: .medium))
                    .foregroundStyle(Vida.ink)
                Text(caption)
                    .font(Vida.sans(12))
                    .foregroundStyle(Vida.taupe)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(change.display)
                    .font(Vida.number(16))
                    .foregroundStyle(Vida.forest)
                if let delta = change.deltaDisplay {
                    Text(delta)
                        .font(Vida.number(12))
                        .foregroundStyle(tint)
                }
            }
        }
        .padding(.vertical, 12)
    }

    private var caption: String {
        guard change.lastWeek != nil else {
            return "\(change.readings) reading\(change.readings == 1 ? "" : "s") · no week to compare yet"
        }
        switch change.isImprovement {
        case true?: return "Better than last week"
        case false?: return "Harder than last week"
        default: return "About the same as last week"
        }
    }
}

// MARK: - Email setup

/// Where her report gets sent. The address lives on her device only.
struct ReportEmailSetupView: View {
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var onSave: () -> Void

    @State private var email: String = ""
    @State private var weekly: Bool = true
    @FocusState private var focused: Bool

    private var isValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".") && trimmed.count >= 6
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Where should your\nweek go?")
                            .font(Vida.serif(30))
                            .foregroundStyle(Vida.forest)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Your report opens in Mail so you can read it before anything is sent. Vida doesn't email you on its own, and your address never leaves this device.")
                            .font(Vida.sans(15))
                            .foregroundStyle(Vida.inkSoft)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Email address")
                        TextField("you@example.com", text: $email)
                            .font(Vida.serif(22))
                            .foregroundStyle(Vida.forest)
                            .tint(Vida.moss)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focused)
                            .padding(.vertical, 8)
                            .overlay(alignment: .bottom) { HairlineDivider() }
                    }

                    Toggle(isOn: $weekly) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Remind me every Sunday")
                                .font(Vida.sans(15, weight: .medium))
                                .foregroundStyle(Vida.ink)
                            Text("Vida will surface your week on the home screen. You choose whether to send it.")
                                .font(Vida.sans(12))
                                .foregroundStyle(Vida.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(Vida.moss)

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .vidaBackground()
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    HairlineDivider()
                    Button {
                        store.reportEmail = email.trimmingCharacters(in: .whitespaces)
                        store.weeklyReportEnabled = weekly
                        store.save()
                        dismiss()
                        // Give the sheet time to close before opening Mail.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onSave() }
                    } label: {
                        Text("Save and continue")
                            .font(Vida.sans(17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Vida.forest, in: Capsule())
                            .foregroundStyle(Vida.onForest)
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(!isValid)
                    .opacity(isValid ? 1 : 0.45)
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .background(Vida.cream)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(Vida.sans(15))
                        .foregroundStyle(Vida.inkSoft)
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
        .onAppear {
            email = store.reportEmail
            weekly = store.weeklyReportEnabled
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
        }
    }
}

// MARK: - System bridges

/// Mail composer. Using the system composer rather than a server means her
/// health summary never passes through anyone else's infrastructure.
struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    var onFinish: (Bool) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        if !recipient.isEmpty { controller.setToRecipients([recipient]) }
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) { }

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (Bool) -> Void

        init(onFinish: @escaping (Bool) -> Void) {
            self.onFinish = onFinish
        }

        nonisolated func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            let sent = result == .sent
            Task { @MainActor in
                controller.dismiss(animated: true)
                self.onFinish(sent)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}
