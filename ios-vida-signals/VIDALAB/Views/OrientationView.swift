import SwiftUI

/// The orientation guide.
///
/// Four questions, asked once: what are you living with, what's worst, what do
/// you want from this, and how long has it been. Every one is skippable, and
/// every answer is editable later — the goal is a body of information Vida can
/// use, not an interrogation.
///
/// The framing matters more than the fields. A woman arriving here has usually
/// spent years being asked to justify her symptoms. These screens are written
/// to make it clear that Vida takes her at her word from the first tap.
struct OrientationView: View {
    @Environment(VidaStore.self) private var store
    @Environment(HealthImportService.self) private var health
    @Environment(\.dismiss) private var dismiss

    /// When true, this is a first-run pass and finishing enters the app.
    var isOnboarding: Bool = false
    var onFinish: (() -> Void)?

    @State private var step: Int = 0
    @State private var conditionIDs: Set<String> = []
    @State private var customCondition: String = ""
    @State private var worstSymptoms: [SignalCategory] = []
    @State private var goals: Set<HealthGoal> = []
    @State private var years: Int?
    @State private var isConnectingHealth: Bool = false
    @State private var healthImported: Int?
    @FocusState private var customFocused: Bool

    /// The Health step is only worth showing on a device that has Health at all.
    private var stepCount: Int { health.isAvailable ? 5 : 4 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressStrip

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch step {
                        case 0: conditionStep
                        case 1: symptomStep
                        case 2: goalStep
                        case 3: durationStep
                        default: healthStep
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .offset(y: 18).combined(with: .opacity),
                        removal: .offset(y: -18).combined(with: .opacity)
                    ))
                }
                .scrollIndicators(.hidden)

                controls
            }
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ABOUT YOU")
                        .font(Vida.sans(12, weight: .bold))
                        .tracking(2.4)
                        .foregroundStyle(Vida.forest)
                }
                if !isOnboarding {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                            .font(Vida.sans(15))
                            .foregroundStyle(Vida.inkSoft)
                    }
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
        .onAppear(perform: loadExisting)
    }

    private func loadExisting() {
        let profile = store.profile
        conditionIDs = Set(profile.conditionIDs)
        customCondition = profile.customCondition
        worstSymptoms = profile.worstSymptoms
        goals = Set(profile.goals)
        years = profile.yearsUnwell
    }

    private var progressStrip: some View {
        HStack(spacing: 5) {
            ForEach(0..<stepCount, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Vida.moss : Vida.shell)
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .animation(.snappy, value: step)
    }

    // MARK: - Step 1 · Conditions

    private var conditionStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(
                eyebrow: "Step one",
                title: "What are you\nliving with?",
                body: "Diagnosed, suspected, or still unnamed — all of it counts. Vida uses this to decide what to watch and what to put in front of you, never to tell you what you have."
            )

            VStack(spacing: 9) {
                ForEach(HealthCondition.catalog) { condition in
                    ConditionRow(
                        condition: condition,
                        isSelected: conditionIDs.contains(condition.id)
                    ) {
                        withAnimation(.snappy) {
                            if conditionIDs.contains(condition.id) {
                                conditionIDs.remove(condition.id)
                            } else {
                                conditionIDs.insert(condition.id)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Something else")
                TextField("Name it yourself", text: $customCondition)
                    .font(Vida.sans(16))
                    .foregroundStyle(Vida.ink)
                    .tint(Vida.moss)
                    .focused($customFocused)
                    .padding(14)
                    .background(Vida.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Vida.hairline, lineWidth: 0.9)
                    }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Step 2 · Worst symptoms

    private var symptomStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(
                eyebrow: "Step two",
                title: "What's worst\nright now?",
                body: "Pick up to four, in the order they affect your life. These go to the top of every check-in and lead your weekly report."
            )

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(SignalCategory.checkInSet) { category in
                    RankedSymptomTile(
                        category: category,
                        rank: worstSymptoms.firstIndex(of: category).map { $0 + 1 }
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if let index = worstSymptoms.firstIndex(of: category) {
                                worstSymptoms.remove(at: index)
                            } else if worstSymptoms.count < 4 {
                                worstSymptoms.append(category)
                            }
                        }
                    }
                }
            }

            if worstSymptoms.count == 4 {
                Text("That's four. Tap one again to swap it out.")
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.taupe)
            }
        }
    }

    // MARK: - Step 3 · Goals

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(
                eyebrow: "Step three",
                title: "What do you\nwant from this?",
                body: "Choose as many as fit. This changes what Vida suggests you do next, and how your weekly report is framed."
            )

            VStack(spacing: 9) {
                ForEach(HealthGoal.allCases) { goal in
                    GoalRow(goal: goal, isSelected: goals.contains(goal)) {
                        withAnimation(.snappy) {
                            if goals.contains(goal) { goals.remove(goal) } else { goals.insert(goal) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 4 · Duration

    private var durationStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(
                eyebrow: "Last one",
                title: "How long has\nthis been going on?",
                body: "Only if you want to say. It's often the single most useful number in a first appointment, and almost nobody is asked for it."
            )

            VStack(spacing: 9) {
                ForEach(durationOptions, id: \.label) { option in
                    Button {
                        withAnimation(.snappy) {
                            years = years == option.value ? nil : option.value
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: years == option.value ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(years == option.value ? Vida.moss : Vida.taupe.opacity(0.6))
                            Text(option.label)
                                .font(Vida.sans(15))
                                .foregroundStyle(Vida.ink)
                            Spacer(minLength: 0)
                        }
                        .paperCard(padding: 16)
                    }
                    .buttonStyle(PressableStyle())
                }
            }

            summaryCard
        }
    }

    // MARK: - Step 5 · Apple Health

    /// Asked last, and only once she can see why it helps. By this point Vida
    /// knows what she's tracking, so the offer can name her own signals instead
    /// of making a generic pitch for permissions.
    private var healthStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(
                eyebrow: "One last thing",
                title: "Let your devices\nfill in the rest.",
                body: healthPitch
            )

            VStack(alignment: .leading, spacing: 0) {
                healthPoint("moon.zzz", "Sleep, without typing it",
                            "Hours actually slept, from your ring, watch or phone.")
                HairlineDivider()
                healthPoint("figure.walk", "How much you moved",
                            "Useful on the days you can't remember whether you overdid it.")
                HairlineDivider()
                healthPoint("arrow.clockwise", "Keeps itself current",
                            "Connect once. Vida updates on its own from then on.")
            }
            .paperCard(padding: 18)

            if let healthImported {
                connectedCard(imported: healthImported)
            } else {
                Button {
                    Task { await connectHealth() }
                } label: {
                    HStack(spacing: 9) {
                        if isConnectingHealth {
                            ProgressView().tint(Vida.onForest)
                        } else {
                            Image(systemName: "heart.text.square")
                                .font(.system(size: 16))
                        }
                        Text(isConnectingHealth ? "Connecting…" : "Connect Apple Health")
                            .font(Vida.sans(16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Vida.forest, in: Capsule())
                    .foregroundStyle(Vida.onForest)
                }
                .buttonStyle(PressableStyle())
                .disabled(isConnectingHealth)
            }

            Text("Read-only, and it never leaves your phone. You can disconnect at any time in Settings.")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.taupe)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Names the signals she just said matter, so the ask is about her.
    private var healthPitch: String {
        let readable = worstSymptoms.filter { $0 == .sleep || $0 == .movement || $0 == .energy }
        if !readable.isEmpty {
            let names = readable.map { $0.title.lowercased() }.joined(separator: " and ")
            return "You said \(names) matters. Your phone and any ring or watch already measure some of that — connect Apple Health and Vida reads it directly, so those days fill themselves in."
        }
        return "Your iPhone already counts your steps, and a ring or watch adds your sleep. Connecting Apple Health means fewer questions at check-in and patterns built on measurement, not memory."
    }

    private func healthPoint(_ symbol: String, _ title: String, _ caption: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(Vida.moss)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Vida.sans(15, weight: .medium))
                    .foregroundStyle(Vida.forest)
                Text(caption)
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.inkSoft)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    private func connectedCard(imported: Int) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 17))
                .foregroundStyle(Vida.moss)
            VStack(alignment: .leading, spacing: 3) {
                Text("Connected")
                    .font(Vida.sans(15, weight: .semibold))
                    .foregroundStyle(Vida.forest)
                Text(imported > 0
                     ? "Brought in \(imported) reading\(imported == 1 ? "" : "s") from the last 90 days. Vida will keep itself up to date from here."
                     : "Nothing to read yet — that's normal. Anything your devices record from now on will appear on its own.")
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.inkSoft)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Vida.sage.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func connectHealth() async {
        isConnectingHealth = true
        let imported = await health.connect(into: store)
        isConnectingHealth = false
        if case .failed = health.phase { return }
        withAnimation(.smooth(duration: 0.4)) { healthImported = imported }
    }

    private var durationOptions: [(label: String, value: Int)] {
        [("Less than a year", 0), ("1–2 years", 2), ("3–5 years", 4),
         ("6–10 years", 8), ("More than 10 years", 12)]
    }

    /// Shows her what Vida now knows — so the payoff is visible before she
    /// commits, not three screens later.
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "What Vida will do with this", color: Vida.moss)

            summaryLine(
                symbol: "list.bullet",
                text: conditionNames.isEmpty
                    ? "Watch your whole picture, since you haven't named a condition."
                    : "Watch the signals that matter for \(conditionNames.joined(separator: " and "))."
            )
            summaryLine(
                symbol: "sunrise",
                text: worstSymptoms.isEmpty
                    ? "Ask about how you're doing twice a day."
                    : "Put \(worstSymptoms.map { $0.title.lowercased() }.joined(separator: ", ")) at the top of every check-in."
            )
            summaryLine(
                symbol: "books.vertical",
                text: "Lead your Library with research on what you're actually dealing with."
            )
            summaryLine(
                symbol: "chart.bar.doc.horizontal",
                text: goals.contains(.prepareAppointments)
                    ? "Build weekly reports you can hand straight to a clinician."
                    : "Send you a weekly report on whether things are moving."
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Vida.sage.opacity(0.16), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.top, 8)
    }

    private var conditionNames: [String] {
        var names = conditionIDs.compactMap { HealthCondition.find($0)?.name }
        let custom = customCondition.trimmingCharacters(in: .whitespaces)
        if !custom.isEmpty { names.append(custom) }
        return Array(names.prefix(2))
    }

    private func summaryLine(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Vida.moss)
                .frame(width: 16)
                .padding(.top, 2)
            Text(text)
                .font(Vida.sans(14))
                .foregroundStyle(Vida.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Shared chrome

    private func stepHeader(eyebrow: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: eyebrow)
            Text(title)
                .font(Vida.serif(30))
                .foregroundStyle(Vida.forest)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
            Text(body)
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controls: some View {
        VStack(spacing: 0) {
            HairlineDivider()
            HStack(spacing: 12) {
                if step > 0 {
                    Button {
                        customFocused = false
                        withAnimation(.smooth(duration: 0.35)) { step -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Vida.inkSoft)
                            .frame(width: 52, height: 52)
                            .background { Circle().strokeBorder(Vida.hairline, lineWidth: 0.9) }
                    }
                    .buttonStyle(PressableStyle())
                }

                Button {
                    advance()
                } label: {
                    Text(primaryTitle)
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

            if skipTitle != nil {
                Button {
                    advance(skipping: true)
                } label: {
                    Text(skipTitle ?? "")
                        .font(Vida.sans(14))
                        .foregroundStyle(Vida.taupe)
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 10)
                .padding(.bottom, 6)
            } else {
                Color.clear.frame(height: 14)
            }
        }
        .background(Vida.cream)
    }

    private var isHealthStep: Bool { health.isAvailable && step == 4 }

    private var primaryTitle: String {
        if isHealthStep { return healthImported == nil ? "Skip for now" : "Start" }
        return step == stepCount - 1 ? "Save and start" : "Continue"
    }

    /// The Health step already has its own primary action, so a second
    /// dismissal link underneath would just be noise.
    private var skipTitle: String? {
        if isHealthStep { return nil }
        return step == 3 ? "Skip this" : "I'd rather not say"
    }

    private func advance(skipping: Bool = false) {
        customFocused = false
        if step < stepCount - 1 {
            withAnimation(.smooth(duration: 0.4)) { step += 1 }
        } else {
            save()
        }
    }

    private func save() {
        var profile = store.profile
        profile.conditionIDs = HealthCondition.catalog
            .map(\.id)
            .filter { conditionIDs.contains($0) }
        profile.customCondition = customCondition.trimmingCharacters(in: .whitespaces)
        profile.worstSymptoms = worstSymptoms
        profile.goals = HealthGoal.allCases.filter { goals.contains($0) }
        profile.yearsUnwell = years
        profile.completedOrientation = true
        store.profile = profile
        store.save()

        if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }
}

// MARK: - Rows

struct ConditionRow: View {
    let condition: HealthCondition
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(isSelected ? Vida.moss : Vida.taupe.opacity(0.55))

                VStack(alignment: .leading, spacing: 3) {
                    Text(condition.name)
                        .font(Vida.sans(15, weight: .medium))
                        .foregroundStyle(Vida.forest)
                        .multilineTextAlignment(.leading)
                    Text(condition.blurb)
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Vida.sage.opacity(0.18) : Vida.paper)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Vida.moss.opacity(0.35) : Vida.hairline.opacity(0.6), lineWidth: 0.8)
            }
        }
        .buttonStyle(PressableStyle())
    }
}

/// A symptom tile that shows its position in her priority order, not just
/// whether it's on — because the order is the information.
struct RankedSymptomTile: View {
    let category: SignalCategory
    let rank: Int?
    let action: () -> Void

    private var isSelected: Bool { rank != nil }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: category.symbol)
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(isSelected ? Vida.onForest : category.accent)
                    Spacer()
                    if let rank {
                        Text("\(rank)")
                            .font(Vida.number(12, weight: .bold))
                            .foregroundStyle(Vida.forest)
                            .frame(width: 20, height: 20)
                            .background(Vida.onForest.opacity(0.9), in: Circle())
                    }
                }
                Text(category.title)
                    .font(Vida.sans(15, weight: .medium))
                    .foregroundStyle(isSelected ? Vida.onForest : Vida.ink)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .frame(height: 86)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Vida.forest : Vida.paper)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? .clear : Vida.hairline.opacity(0.7), lineWidth: 0.7)
            }
        }
        .buttonStyle(PressableStyle())
    }
}

struct GoalRow: View {
    let goal: HealthGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: goal.symbol)
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(isSelected ? Vida.moss : Vida.taupe)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.title)
                        .font(Vida.sans(15, weight: .medium))
                        .foregroundStyle(Vida.forest)
                        .multilineTextAlignment(.leading)
                    Text(goal.caption)
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Vida.moss : Vida.taupe.opacity(0.5))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Vida.sage.opacity(0.18) : Vida.paper)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Vida.moss.opacity(0.35) : Vida.hairline.opacity(0.6), lineWidth: 0.8)
            }
        }
        .buttonStyle(PressableStyle())
    }
}
