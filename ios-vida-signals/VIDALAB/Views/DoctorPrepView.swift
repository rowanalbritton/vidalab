import SwiftUI

/// Guided interview that turns lived experience into a clinician-ready summary.
struct DoctorPrepView: View {
    @Environment(VidaStore.self) private var store
    @State private var showInterview: Bool = false
    @State private var showPaywall: Bool = false
    @State private var snapshot: DoctorPrep?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header

                    Button {
                        if store.canCreatePrep { showInterview = true } else { showPaywall = true }
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "text.document")
                                .font(.system(size: 20, weight: .light))
                                .foregroundStyle(Vida.cream)
                                .frame(width: 46, height: 46)
                                .background(Vida.forest, in: Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Prepare for an appointment")
                                    .font(Vida.serif(21))
                                    .foregroundStyle(Vida.forest)
                                    .multilineTextAlignment(.leading)
                                Text("About five minutes")
                                    .font(Vida.sans(13))
                                    .foregroundStyle(Vida.inkSoft)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: store.canCreatePrep ? "arrow.right" : "lock.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Vida.moss)
                        }
                        .paperCard(padding: 20)
                    }
                    .buttonStyle(PressableStyle())

                    InsightLaunchCard(feature: .concierge)

                    if !store.isPlus {
                        if store.canCreatePrep {
                            HStack(spacing: 12) {
                                Image(systemName: "text.document")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Vida.moss)
                                Text("Your first Health Snapshot is free: the full interview, your tracked data, and the shareable summary.")
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
                                title: "You've used your free snapshot",
                                message: "Your saved snapshot stays yours forever. Vida+ lets you build a fresh one for every appointment."
                            ) { showPaywall = true }
                        }
                    }

                    whatItDoes

                    if !store.preps.isEmpty { saved }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .vidaScrollChrome("Doctor Prep")
            .vidaMenu()
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showInterview) { PrepInterviewView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(item: $snapshot) { HealthSnapshotView(prep: $0) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Walk in able\nto explain it.")
                .font(Vida.display(34))
                .tracking(Vida.displayTracking)
                .foregroundStyle(Vida.forest)
            Text("Appointments are short and easy to freeze up in. Vida turns what you've tracked into a clear one-page summary and a list of questions worth asking.")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
        .vidaParallaxHeader()
    }

    private var whatItDoes: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "What you'll walk out with")
            row("list.clipboard", "A Health Snapshot", "Your concern, when it started, how often, how severe, and what it stops you doing, in the structure a clinician expects.")
            row("chart.line.uptrend.xyaxis", "Your own data", "Frequency and severity pulled straight from what you've logged, so you're not relying on memory in the room.")
            row("questionmark.circle", "Questions to ask", "Specific, answerable questions, including the ones that are hard to think of under pressure.")
            row("square.and.arrow.up", "Something to share", "Save or share it before you go in.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }

    private func row(_ symbol: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(Vida.moss)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Vida.sans(15, weight: .semibold))
                    .foregroundStyle(Vida.ink)
                Text(body)
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.inkSoft)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var saved: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(eyebrow: "Yours", title: "Saved snapshots")
                .padding(.horizontal, 2)
            VStack(spacing: 10) {
                ForEach(store.preps) { prep in
                    Button {
                        snapshot = prep
                    } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(prep.concern)
                                    .font(Vida.sans(16, weight: .semibold))
                                    .foregroundStyle(Vida.forest)
                                    .multilineTextAlignment(.leading)
                                Text(prep.createdAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(Vida.sans(12))
                                    .foregroundStyle(Vida.taupe)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Vida.taupe)
                        }
                        .paperCard(padding: 18)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }
}

// MARK: - Interview

struct PrepInterviewView: View {
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var step: Int = 0
    @State private var concern: String = ""
    @State private var bodyArea: String = ""
    @State private var onset: String = ""
    @State private var frequency: String = ""
    @State private var typicalSeverity: Double = 5
    @State private var worstSeverity: Double = 8
    @State private var symptoms: Set<String> = []
    @State private var impact: Set<String> = []
    @State private var tried: Set<String> = []
    @State private var questions: Set<String> = []
    @State private var result: DoctorPrep?

    private let concerns = ["Pelvic pain", "Heavy or irregular periods", "Headaches or migraine", "Fatigue", "Mood changes", "Digestive symptoms", "Something else"]
    private let onsets = ["Within the last month", "2–6 months ago", "6–12 months ago", "Over a year ago", "As long as I can remember"]
    private let frequencies = ["Every day", "Most days", "Around my period only", "A few times a month", "Occasionally"]
    private let symptomOptions = ["Nausea", "Lower-back pain", "Fatigue", "Pain with bowel movements", "Bloating", "Dizziness", "Heavy bleeding", "Pain during sex", "Headache", "Fainting"]
    private let impactOptions = ["Missed school or work", "Left early", "Cancelled plans", "Stopped a sport", "Couldn't sleep", "Went to A&E or urgent care", "Pushed through"]
    private let triedOptions = ["Over-the-counter painkillers", "Heat", "Rest", "Changed my diet", "Exercise", "Hormonal birth control", "Nothing yet"]
    private let questionOptions = [
        "Could these symptoms warrant further evaluation?",
        "What conditions should be considered?",
        "Are there tests or a specialist referral that might be appropriate?",
        "What can I do to manage symptoms in the meantime?",
        "Should my iron levels be checked?",
        "Is this level of pain expected?",
        "What would make you want to see me again sooner?"
    ]

    private var totalSteps: Int { 7 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressBar(progress: Double(step) / Double(totalSteps))
                    .frame(height: 3)
                    .padding(.horizontal, 22)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        content
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)

                VStack(spacing: 0) {
                    HairlineDivider()
                    HStack(spacing: 12) {
                        if step > 0 {
                            Button {
                                withAnimation(.smooth) { step -= 1 }
                            } label: {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Vida.inkSoft)
                                    .frame(width: 52, height: 52)
                                    .background(Vida.paper, in: Circle())
                                    .overlay { Circle().strokeBorder(Vida.hairline, lineWidth: 0.9) }
                            }
                            .buttonStyle(PressableStyle())
                        }
                        Button {
                            next()
                        } label: {
                            Text(step == totalSteps - 1 ? "Build my snapshot" : "Continue")
                                .font(Vida.sans(17, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(Vida.forest, in: Capsule())
                                .foregroundStyle(Vida.cream)
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(!canAdvance)
                        .opacity(canAdvance ? 1 : 0.45)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                }
                .background(Vida.cream)
            }
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .font(Vida.sans(15))
                        .foregroundStyle(Vida.inkSoft)
                }
                ToolbarItem(placement: .principal) {
                    Text("\(step + 1) of \(totalSteps)")
                        .font(Vida.sans(12, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(Vida.taupe)
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
        .sheet(item: $result, onDismiss: { dismiss() }) { prep in
            HealthSnapshotView(prep: prep)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0:
            question("What are you seeing someone about?", "Pick the closest fit. You can be more specific in a moment.")
            singleChoice(concerns, selection: $concern)
        case 1:
            question("Can you say a little more?", "In your own words. This goes at the top of your snapshot.")
            TextField("For example: sharp pelvic pain before my period", text: $bodyArea, axis: .vertical)
                .font(Vida.sans(16))
                .foregroundStyle(Vida.ink)
                .tint(Vida.moss)
                .lineLimit(3...6)
                .padding(16)
                .background(Vida.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Vida.hairline, lineWidth: 0.9) }
        case 2:
            question("When did it start?", "An approximate answer is completely fine.")
            singleChoice(onsets, selection: $onset)
        case 3:
            question("How often does it happen?", "")
            singleChoice(frequencies, selection: $frequency)
        case 4:
            question("How severe is it?", "Clinicians will ask for a number. Having one ready makes the conversation much easier.")
            severitySliders
        case 5:
            question("What else comes with it?", "Select everything that applies.")
            FlowChips(options: symptomOptions, selected: symptoms) { toggle($0, in: &symptoms) }
            Text("What has it stopped you doing?")
                .font(Vida.sans(15, weight: .semibold))
                .foregroundStyle(Vida.ink)
                .padding(.top, 6)
            FlowChips(options: impactOptions, selected: impact) { toggle($0, in: &impact) }
            Text("What have you already tried?")
                .font(Vida.sans(15, weight: .semibold))
                .foregroundStyle(Vida.ink)
                .padding(.top, 6)
            FlowChips(options: triedOptions, selected: tried) { toggle($0, in: &tried) }
        default:
            question("What do you want to ask?", "These go on your snapshot as a checklist. Tick the ones you want to bring.")
            VStack(spacing: 10) {
                ForEach(questionOptions, id: \.self) { option in
                    Button {
                        toggle(option, in: &questions)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: questions.contains(option) ? "checkmark.square.fill" : "square")
                                .font(.system(size: 18))
                                .foregroundStyle(questions.contains(option) ? Vida.moss : Vida.taupe)
                            Text(option)
                                .font(Vida.sans(15))
                                .foregroundStyle(Vida.ink)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .paperCard(padding: 16)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private func question(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Vida.serif(27))
                .foregroundStyle(Vida.forest)
                .fixedSize(horizontal: false, vertical: true)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(Vida.sans(15))
                    .foregroundStyle(Vida.inkSoft)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func singleChoice(_ options: [String], selection: Binding<String>) -> some View {
        VStack(spacing: 10) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(Vida.Motion.gentle) { selection.wrappedValue = option }
                } label: {
                    HStack {
                        Text(option)
                            .font(Vida.sans(16))
                            .foregroundStyle(selection.wrappedValue == option ? Vida.cream : Vida.ink)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        if selection.wrappedValue == option {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Vida.cream)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selection.wrappedValue == option ? Vida.forest : Vida.paper)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(selection.wrappedValue == option ? .clear : Vida.hairline, lineWidth: 0.9)
                    }
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private var severitySliders: some View {
        VStack(alignment: .leading, spacing: 24) {
            severityRow("Typical severity", value: $typicalSeverity, color: Vida.sky)
            severityRow("At its worst", value: $worstSeverity, color: Vida.blush)
        }
        .paperCard(padding: 20)
    }

    private func severityRow(_ label: String, value: Binding<Double>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(Vida.sans(15, weight: .medium))
                    .foregroundStyle(Vida.ink)
                Spacer()
                Text("\(Int(value.wrappedValue)) / 10")
                    .font(Vida.serif(24))
                    .foregroundStyle(Vida.forest)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Slider(value: value, in: 0...10, step: 1)
                .tint(color)
        }
        .animation(Vida.Motion.gentle, value: value.wrappedValue)
    }

    private func toggle(_ option: String, in set: inout Set<String>) {
        if set.contains(option) { set.remove(option) } else { set.insert(option) }
    }

    private var canAdvance: Bool {
        switch step {
        case 0: !concern.isEmpty
        case 2: !onset.isEmpty
        case 3: !frequency.isEmpty
        default: true
        }
    }

    private func next() {
        if step < totalSteps - 1 {
            withAnimation(.smooth) { step += 1 }
        } else {
            let prep = DoctorPrep(
                concern: concern,
                bodyArea: bodyArea,
                onset: onset,
                frequency: frequency,
                typicalSeverity: Int(typicalSeverity),
                worstSeverity: Int(worstSeverity),
                associatedSymptoms: symptoms.sorted(),
                impact: impact.sorted(),
                triedAlready: tried.sorted(),
                questions: questions.sorted()
            )
            store.save(prep)
            result = prep
        }
    }
}

// MARK: - Health Snapshot

struct HealthSnapshotView: View {
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let prep: DoctorPrep

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("MY HEALTH SNAPSHOT")
                                .font(Vida.sans(11, weight: .bold))
                                .tracking(2.2)
                                .foregroundStyle(Vida.taupe)
                            Text(prep.concern)
                                .font(Vida.serif(27))
                                .foregroundStyle(Vida.forest)
                                .fixedSize(horizontal: false, vertical: true)
                            if !prep.bodyArea.isEmpty {
                                Text(prep.bodyArea)
                                    .font(Vida.serifItalic(16))
                                    .foregroundStyle(Vida.inkSoft)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        HairlineDivider()

                        field("Started", prep.onset)
                        field("Frequency", prep.frequency)
                        field("Typical severity", "\(prep.typicalSeverity) / 10")
                        field("Highest severity", "\(prep.worstSeverity) / 10")
                        if let window = mostCommonWindow {
                            field("Most commonly occurs", window)
                        }

                        if !prep.associatedSymptoms.isEmpty {
                            listField("Associated symptoms", prep.associatedSymptoms)
                        }
                        if !prep.impact.isEmpty {
                            listField("Impact", prep.impact)
                        }
                        if !prep.triedAlready.isEmpty {
                            listField("Already tried", prep.triedAlready)
                        }

                        if let tracked = trackedSummary {
                            HairlineDivider()
                            VStack(alignment: .leading, spacing: 6) {
                                Eyebrow(text: "From my tracked data")
                                Text(tracked)
                                    .font(Vida.sans(14))
                                    .foregroundStyle(Vida.ink)
                                    .lineSpacing(5)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .vidaBrightenOnScroll()
                            }
                        }

                        if !prep.questions.isEmpty {
                            HairlineDivider()
                            VStack(alignment: .leading, spacing: 12) {
                                Eyebrow(text: "Questions I want to ask")
                                ForEach(prep.questions, id: \.self) { question in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "square")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Vida.taupe)
                                            .padding(.top, 2)
                                        Text(question)
                                            .font(Vida.sans(15))
                                            .foregroundStyle(Vida.ink)
                                            .lineSpacing(4)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }

                        HairlineDivider()

                        Text("Prepared with VIDA LAB on \(prep.createdAt.formatted(date: .long, time: .omitted)). This is a personal record, not a diagnosis.")
                            .font(Vida.sans(11))
                            .foregroundStyle(Vida.taupe)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(24)
                    .background {
                        RoundedRectangle(cornerRadius: Vida.cardRadius, style: .continuous)
                            .fill(Vida.paper)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: Vida.cardRadius, style: .continuous)
                            .strokeBorder(Vida.hairline.opacity(0.5), lineWidth: 0.7)
                    }

                    conciergeCard
                        .padding(.top, 18)

                    ShareLink(item: plainText) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share my Health Snapshot")
                        }
                        .font(Vida.sans(16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Vida.forest, in: Capsule())
                        .foregroundStyle(Vida.cream)
                    }
                    .padding(.top, 22)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
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
    }

    // MARK: - Appointment Concierge

    /// What to say, in her voice, and what to say back when she feels
    /// brushed off. Built from the answers above.
    private var conciergeCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Appointment Concierge", color: Vida.moss)
                Text("Say it in one breath")
                    .font(Vida.display(24))
                    .tracking(Vida.displayTracking)
                    .foregroundStyle(Vida.forest)
            }
            Text(AppointmentConcierge.narrative(for: prep))
                .font(Vida.serifItalic(17))
                .foregroundStyle(Vida.ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            HairlineDivider()

            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "If you feel brushed off")
                ForEach(AppointmentConcierge.script(for: prep), id: \.self) { line in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("If you hear \(line.ifYouHear)")
                            .font(Vida.sans(13, weight: .medium))
                            .foregroundStyle(Vida.taupe)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(line.youCanSay)
                            .font(Vida.sans(15))
                            .foregroundStyle(Vida.ink)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Vida.moss.opacity(0.5)).frame(width: 2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Vida.sage.opacity(0.14), in: RoundedRectangle(cornerRadius: Vida.cardRadius, style: .continuous))
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(Vida.sans(10, weight: .semibold))
                .tracking(1.3)
                .foregroundStyle(Vida.taupe)
            Text(value)
                .font(Vida.sans(16))
                .foregroundStyle(Vida.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func listField(_ label: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(Vida.sans(10, weight: .semibold))
                .tracking(1.3)
                .foregroundStyle(Vida.taupe)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(Vida.sage).frame(width: 4, height: 4).padding(.top, 8)
                    Text(item)
                        .font(Vida.sans(15))
                        .foregroundStyle(Vida.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Pulls the cycle window where pain was most often logged.
    private var mostCommonWindow: String? {
        guard store.profile.tracksCycle, let start = store.lastPeriodStart else { return nil }
        let painDays = store.logs.compactMap { log -> Int? in
            guard let reading = log.reading(for: .pain), reading.value >= 5 else { return nil }
            let days = Calendar.current.dateComponents([.day], from: start, to: log.date).day ?? 0
            return ((days % store.averageCycleLength) + store.averageCycleLength) % store.averageCycleLength + 1
        }
        guard painDays.count >= 3 else { return nil }
        let inWindow = painDays.filter { $0 <= 4 || $0 >= store.averageCycleLength - 2 }.count
        guard Double(inWindow) / Double(painDays.count) > 0.5 else { return nil }
        return "Around 2 days before menstruation through day 3 of bleeding"
    }

    /// What her own tracking adds to the document.
    ///
    /// Always returns something once a single day exists. A sparse record is
    /// still evidence — "three days logged so far" is a true and useful line in
    /// an appointment, and withholding the whole section because it isn't a
    /// month yet would make the document weaker, not more honest.
    private var trackedSummary: String? {
        guard !store.logs.isEmpty else { return nil }

        let painDays = store.logs.filter { ($0.reading(for: .pain)?.value ?? 0) >= 5 }.count
        let window = min(60, store.logs.count)
        var parts: [String] = ["Logged \(store.logs.count) day\(store.logs.count == 1 ? "" : "s") in VIDA LAB."]

        if painDays > 0 {
            parts.append("Pain at 5/10 or above on \(painDays) of the last \(window) day\(window == 1 ? "" : "s").")
        }
        let missed = store.logs.filter { $0.reading(for: .pain)?.tags.contains("Missed school") == true }.count
        if missed > 0 {
            parts.append("Missed school \(missed) time\(missed == 1 ? "" : "s") because of symptoms.")
        }
        // Associations are only quoted once they clear the confidence floor,
        // so a clinician never reads a correlation drawn from four days.
        if let link = store.meaningfulLinks.first {
            parts.append("Noted association between \(link.a.title.lowercased()) and \(link.b.title.lowercased()) across \(link.sampleSize) days.")
        }
        // Name the gap rather than letting a thin record look complete.
        if let caveat = trackingCaveat {
            parts.append(caveat)
        }
        return parts.joined(separator: " ")
    }

    /// States the limits of the record so nobody over-reads it.
    private var trackingCaveat: String? {
        let days = store.logs.count
        if days < PatternReadiness.floor {
            return "This is an early record, with too few days so far to show trends or associations."
        }
        if store.meaningfulLinks.isEmpty {
            return "No associations between symptoms have reached a reportable threshold yet."
        }
        return nil
    }

    private var plainText: String {
        var lines: [String] = [
            "MY HEALTH SNAPSHOT",
            "",
            "Primary concern: \(prep.concern)"
        ]
        if !prep.bodyArea.isEmpty { lines.append("In my words: \(prep.bodyArea)") }
        lines.append(contentsOf: [
            "Started: \(prep.onset)",
            "Frequency: \(prep.frequency)",
            "Typical severity: \(prep.typicalSeverity)/10",
            "Highest severity: \(prep.worstSeverity)/10"
        ])
        if let window = mostCommonWindow { lines.append("Most commonly occurs: \(window)") }
        if !prep.associatedSymptoms.isEmpty {
            lines.append("")
            lines.append("Associated symptoms:")
            lines.append(contentsOf: prep.associatedSymptoms.map { "  - \($0)" })
        }
        if !prep.impact.isEmpty {
            lines.append("")
            lines.append("Impact:")
            lines.append(contentsOf: prep.impact.map { "  - \($0)" })
        }
        if !prep.triedAlready.isEmpty {
            lines.append("")
            lines.append("Already tried:")
            lines.append(contentsOf: prep.triedAlready.map { "  - \($0)" })
        }
        if let tracked = trackedSummary {
            lines.append("")
            lines.append("From my tracked data: \(tracked)")
        }
        if !prep.questions.isEmpty {
            lines.append("")
            lines.append("Questions I want to ask:")
            lines.append(contentsOf: prep.questions.map { "  [ ] \($0)" })
        }
        lines.append("")
        lines.append(AppointmentConcierge.plainText(for: prep))
        lines.append("")
        lines.append("Prepared with VIDA LAB on \(prep.createdAt.formatted(date: .long, time: .omitted)). This is a personal record, not a diagnosis.")
        return lines.joined(separator: "\n")
    }
}
