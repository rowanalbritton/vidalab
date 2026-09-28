import SwiftUI

/// The daily check-in, now asked twice: once for what the night left you with,
/// once for what the day cost you. Each period offers only the signals it can
/// honestly answer, ordered so the member's own priority symptoms come first.
struct CheckInFlow: View {
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let period: CheckInPeriod

    @State private var selected: [SignalCategory] = []
    @State private var stage: Stage = .choose
    @State private var index: Int = 0
    @State private var value: Double = 5
    @State private var answers: [UUID: Set<String>] = [:]
    @State private var note: String = ""
    @State private var confirmExit: Bool = false

    private enum Stage { case choose, rate, done }

    /// True when the current question holds input that hasn't been saved.
    ///
    /// Closing mid-question used to discard it silently. Someone who just
    /// described the worst headache of her month deserves better than losing it
    /// to a mis-tap on Close.
    private var hasUnsavedInput: Bool {
        guard stage == .rate else { return false }
        return !note.trimmingCharacters(in: .whitespaces).isEmpty
            || !answers.values.flatMap({ $0 }).isEmpty
    }

    private var available: [SignalCategory] {
        store.categories(for: period)
    }

    /// Signals her profile flagged as priorities — shown first and pre-selected.
    private var focus: [SignalCategory] {
        let priorities = Set(store.profile.focusSignals.prefix(4))
        return available.filter { priorities.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VidaCanvas().ignoresSafeArea()
                OrganicBackdrop().opacity(0.6)

                switch stage {
                case .choose: chooseStage
                case .rate: rateStage
                case .done: doneStage
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        if hasUnsavedInput {
                            confirmExit = true
                        } else {
                            dismiss()
                        }
                    }
                    .font(Vida.sans(15))
                    .foregroundStyle(Vida.inkSoft)
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: period.symbol)
                            .font(.system(size: 10))
                        Text(stage == .rate ? "\(index + 1) OF \(selected.count)" : period.title.uppercased())
                            .font(Vida.sans(12, weight: .semibold))
                            .tracking(1.6)
                    }
                    .foregroundStyle(Vida.taupe)
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
        .onAppear(perform: preselectFocus)
        .interactiveDismissDisabled(hasUnsavedInput)
        .confirmationDialog(
            "Save this before you go?",
            isPresented: $confirmExit,
            titleVisibility: .visible
        ) {
            Button("Save and close") {
                saveCurrent()
                dismiss()
            }
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) { }
        } message: {
            Text("You've written something for \(currentCategory.title.lowercased()) that isn't saved yet. Vida keeps partial check-ins — one answer is worth more than none.")
        }
    }

    private var currentCategory: SignalCategory {
        selected.isEmpty ? .energy : selected[min(index, selected.count - 1)]
    }

    /// Her priority signals start ticked, so the common case is one tap.
    private func preselectFocus() {
        guard selected.isEmpty else { return }
        selected = focus
    }

    // MARK: - Choose

    private var chooseStage: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(period.headline)
                            .font(Vida.serif(31))
                            .foregroundStyle(Vida.forest)
                        Text(chooseCaption)
                            .font(Vida.sans(15))
                            .foregroundStyle(Vida.inkSoft)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 6)

                    if !focus.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Eyebrow(text: "What you told us matters most", color: Vida.moss)
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(focus) { category in
                                    CategoryTile(
                                        category: category,
                                        isSelected: selected.contains(category),
                                        isLogged: store.todayLog?.categories(in: period).contains(category) ?? false
                                    ) {
                                        toggle(category)
                                    }
                                }
                            }
                        }
                    }

                    let others = available.filter { !focus.contains($0) }
                    if !others.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            if !focus.isEmpty {
                                Eyebrow(text: "Anything else")
                            }
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(others) { category in
                                    CategoryTile(
                                        category: category,
                                        isSelected: selected.contains(category),
                                        isLogged: store.todayLog?.categories(in: period).contains(category) ?? false
                                    ) {
                                        toggle(category)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 0) {
                HairlineDivider()
                Button {
                    beginRating()
                } label: {
                    Text(selected.isEmpty ? "Choose at least one" : "Continue with \(selected.count)")
                        .font(Vida.sans(17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Vida.forest, in: Capsule())
                        .foregroundStyle(Vida.onForest)
                }
                .buttonStyle(PressableStyle())
                .disabled(selected.isEmpty)
                .opacity(selected.isEmpty ? 0.45 : 1)
                .padding(.horizontal, 22)
                .padding(.top, 14)
            }
            .background(Vida.cream)
        }
    }

    private var chooseCaption: String {
        if store.profile.hasAnyCondition && !focus.isEmpty {
            return "Your priority signals are already ticked. Add anything else you want to note, or just continue."
        }
        return "Choose everything you want to note. There's no wrong answer, and you can skip anything."
    }

    private func toggle(_ category: SignalCategory) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if let i = selected.firstIndex(of: category) {
                selected.remove(at: i)
            } else {
                selected.append(category)
            }
        }
    }

    private func beginRating() {
        guard !selected.isEmpty else { return }
        // Keep the member's priority order rather than tap order.
        selected = available.filter { selected.contains($0) }
        index = 0
        prepare(for: selected[0])
        withAnimation(.smooth(duration: 0.35)) { stage = .rate }
    }

    private func prepare(for category: SignalCategory) {
        if let existing = store.todayLog?.reading(for: category, period: period) {
            value = existing.value
            note = existing.note
            answers = [:]
        } else {
            value = category == .sleep ? 7.5 : 5
            note = ""
            answers = [:]
        }
    }

    // MARK: - Rate

    private var rateStage: some View {
        let category = selected[min(index, selected.count - 1)]
        return VStack(spacing: 0) {
            ProgressBar(progress: Double(index) / Double(max(1, selected.count)))
                .frame(height: 3)
                .padding(.horizontal, 22)

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: category.symbol)
                                .font(.system(size: 15))
                                .foregroundStyle(category.accent)
                            Eyebrow(text: category.title)
                        }
                        Text(period.prompt(for: category))
                            .font(Vida.serif(30))
                            .foregroundStyle(Vida.forest)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 18)

                    valueControl(for: category)

                    ForEach(category.followUps) { question in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(question.prompt)
                                .font(Vida.sans(15, weight: .semibold))
                                .foregroundStyle(Vida.ink)

                            FlowChips(
                                options: question.options,
                                selected: answers[question.id] ?? [],
                                accent: category.accent
                            ) { option in
                                var current = answers[question.id] ?? []
                                if current.contains(option) { current.remove(option) } else { current.insert(option) }
                                answers[question.id] = current
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Anything unusual?")
                            .font(Vida.sans(15, weight: .semibold))
                            .foregroundStyle(Vida.ink)
                        TextField("Optional note", text: $note, axis: .vertical)
                            .font(Vida.sans(15))
                            .foregroundStyle(Vida.ink)
                            .tint(Vida.moss)
                            .lineLimit(2...4)
                            .accessibilityLabel("Note about your \(category.title.lowercased())")
                            .onChange(of: note) { _, newValue in
                                if newValue.count > SignalReading.noteLimit {
                                    note = String(newValue.prefix(SignalReading.noteLimit))
                                }
                            }
                            .padding(14)
                            .background(Vida.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Vida.hairline, lineWidth: 0.9)
                            }

                        // Appears only near the ceiling, so the limit is known
                        // before it's hit rather than after the text vanishes.
                        if note.count > SignalReading.noteLimit - 80 {
                            HStack {
                                Spacer()
                                Text("\(note.count)/\(SignalReading.noteLimit)")
                                    .font(Vida.number(11))
                                    .foregroundStyle(note.count >= SignalReading.noteLimit ? Vida.clay : Vida.taupe)
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .id(category)
            .transition(.opacity)

            VStack(spacing: 0) {
                HairlineDivider()
                HStack(spacing: 12) {
                    Button {
                        advance(saving: false)
                    } label: {
                        Text("Skip")
                            .font(Vida.sans(16, weight: .medium))
                            .foregroundStyle(Vida.inkSoft)
                            .padding(.vertical, 17)
                            .padding(.horizontal, 22)
                    }
                    .buttonStyle(PressableStyle())

                    Button {
                        advance(saving: true)
                    } label: {
                        Text(index == selected.count - 1 ? "Finish" : "Next")
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
    }

    @ViewBuilder
    private func valueControl(for category: SignalCategory) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(valueLabel(for: category))
                    .font(Vida.serif(46))
                    .foregroundStyle(Vida.forest)
                    .contentTransition(.numericText())
                Text(category.unitLabel)
                    .font(Vida.sans(14))
                    .foregroundStyle(Vida.taupe)
            }

            Slider(
                value: $value,
                in: category == .sleep ? 0...12 : 0...10,
                step: category == .sleep ? 0.25 : 1
            )
            .tint(category.accent)

            HStack {
                Text(lowLabel(for: category))
                Spacer()
                Text(highLabel(for: category))
            }
            .font(Vida.sans(12))
            .foregroundStyle(Vida.taupe)
        }
        .paperCard(padding: 20)
        .animation(Vida.Motion.gentle, value: value)
    }

    private func valueLabel(for category: SignalCategory) -> String {
        if category == .sleep {
            let hours = Int(value)
            let minutes = Int((value - Double(hours)) * 60)
            return "\(hours)h \(String(format: "%02d", minutes))m"
        }
        return "\(Int(value))"
    }

    private func lowLabel(for category: SignalCategory) -> String {
        switch category {
        case .sleep: "None"
        case .cycle: "No bleeding"
        case .pain, .headache, .stress: "None"
        default: category.higherIsBetter ? "Very low" : "None"
        }
    }

    private func highLabel(for category: SignalCategory) -> String {
        switch category {
        case .sleep: "12 hours"
        case .cycle: "Very heavy"
        case .pain, .headache: "Worst imaginable"
        case .stress: "Overwhelming"
        default: "Very high"
        }
    }

    /// Writes whatever is on screen right now. Partial is fine — a single
    /// answer is a real data point and is never withheld for being incomplete.
    private func saveCurrent() {
        guard stage == .rate, !selected.isEmpty else { return }
        let category = selected[min(index, selected.count - 1)]
        let tags = answers.values.flatMap { $0 }.sorted()
        store.record(
            SignalReading(
                category: category,
                value: value,
                tags: tags,
                note: String(note.prefix(SignalReading.noteLimit)),
                source: .manual,
                period: period
            ),
            on: .now
        )
    }

    private func advance(saving: Bool) {
        if saving {
            saveCurrent()
        }
        if index == selected.count - 1 {
            withAnimation(.smooth(duration: 0.4)) { stage = .done }
        } else {
            index += 1
            prepare(for: selected[index])
        }
    }

    // MARK: - Done

    private var doneStage: some View {
        VStack(spacing: 22) {
            Spacer()

            LeafProgressMark(progress: max(0.25, store.todayPeriodCompletion))
                .frame(width: 80, height: 108)

            VStack(spacing: 10) {
                Text(period == .morning ? "Morning logged." : "Day logged.")
                    .font(Vida.serif(33))
                    .foregroundStyle(Vida.forest)
                Text(closingMessage)
                    .font(Vida.sans(15))
                    .foregroundStyle(Vida.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
            }

            Spacer()

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
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
        }
    }

    private var closingMessage: String {
        if period == .morning && !store.hasCompleted(.evening) {
            return "Vida will ask again this evening. Two halves of a day tell a different story than one average."
        }
        let days = store.loggedDayCount
        if days < 5 {
            return "Vida needs a handful of days before patterns become trustworthy. You're \(days) in."
        }
        if store.meaningfulLinks.isEmpty {
            return "Nothing conclusive yet — that's a real result too. Keep going and the Pattern Map will fill in."
        }
        return "Your Pattern Map has something new in it."
    }
}

// MARK: - Supporting views

struct CategoryTile: View {
    let category: SignalCategory
    let isSelected: Bool
    let isLogged: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: category.symbol)
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(isSelected ? Vida.onForest : category.accent)
                    Spacer()
                    if isLogged && !isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Vida.sage)
                    }
                }
                Text(category.title)
                    .font(Vida.sans(15, weight: .medium))
                    .foregroundStyle(isSelected ? Vida.onForest : Vida.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .frame(height: 92)
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

/// Wrapping chip layout for follow-up options.
struct FlowChips: View {
    let options: [String]
    let selected: Set<String>
    var accent: Color = Vida.moss
    let onTap: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { option in
                SelectChip(label: option, isSelected: selected.contains(option), accent: accent) {
                    onTap(option)
                }
            }
        }
    }
}

struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Vida.shell)
                Capsule()
                    .fill(Vida.moss)
                    .frame(width: geo.size.width * min(1, max(0, progress)))
            }
        }
        .animation(.smooth(duration: 0.5), value: progress)
    }
}
