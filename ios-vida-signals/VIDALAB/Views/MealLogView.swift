import SwiftUI

/// Logging what you ate.
///
/// One field that matters — the name — and everything else optional. Vida
/// asks for no calories and no macros: the goal is a countable name so
/// patterns can find it, not a food diary. For an audience with a frequently
/// complicated history around food, the difference is the whole design.
struct MealLogView: View {
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Nil when adding, set when editing an existing entry.
    var editing: MealEntry?
    var date: Date = .now

    @State private var name = ""
    @State private var note = ""
    @State private var kind: MealKind = .likely()
    @State private var howItSat: Double = 5
    @State private var ratedComfort = false
    @FocusState private var nameFocused: Bool

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    kindPicker

                    VStack(alignment: .leading, spacing: 9) {
                        Eyebrow(text: "What was it?")
                        TextField("Porridge and berries", text: $name, axis: .vertical)
                            .font(Vida.sans(17))
                            .foregroundStyle(Vida.ink)
                            .tint(Vida.moss)
                            .lineLimit(1...3)
                            .focused($nameFocused)
                            .padding(14)
                            .background(Vida.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Vida.hairline, lineWidth: 0.9)
                            }
                        Text("A name is enough. Vida counts what repeats — it doesn't want portions or calories.")
                            .font(Vida.sans(12))
                            .foregroundStyle(Vida.taupe)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    recentSuggestions
                    comfortSlider

                    VStack(alignment: .leading, spacing: 9) {
                        Eyebrow(text: "Anything to add")
                        TextField("Optional", text: $note, axis: .vertical)
                            .font(Vida.sans(15))
                            .foregroundStyle(Vida.ink)
                            .tint(Vida.moss)
                            .lineLimit(2...6)
                            .padding(14)
                            .background(Vida.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Vida.hairline, lineWidth: 0.9)
                            }
                    }

                    if editing != nil {
                        Button(role: .destructive) {
                            if let editing { store.deleteMeal(id: editing.id) }
                            dismiss()
                        } label: {
                            Label("Delete this meal", systemImage: "trash")
                                .font(Vida.sans(15))
                                .foregroundStyle(Vida.clay)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .vidaBackground()
            .navigationTitle(editing == nil ? "Add a meal" : "Edit meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(Vida.sans(15))
                        .foregroundStyle(Vida.inkSoft)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(Vida.sans(15, weight: .semibold))
                        .disabled(!canSave)
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
        .onAppear(perform: loadExisting)
    }

    // MARK: - Pieces

    private var kindPicker: some View {
        HStack(spacing: 8) {
            ForEach(MealKind.allCases) { option in
                Button {
                    kind = option
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: option.symbol)
                            .font(.system(size: 15, weight: .light))
                        Text(option.title)
                            .font(Vida.sans(12, weight: kind == option ? .semibold : .regular))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(kind == option ? Vida.onForest : Vida.inkSoft)
                    .background(kind == option ? Vida.forest : Vida.paper,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(kind == option ? .clear : Vida.hairline, lineWidth: 0.8)
                    }
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(kind == option ? [.isSelected] : [])
            }
        }
    }

    /// Recently logged names, so a repeat meal is one tap. This is also what
    /// makes the favourites count meaningful — people who retype end up with
    /// five spellings of the same breakfast.
    @ViewBuilder
    private var recentSuggestions: some View {
        let suggestions = recentNames
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                Eyebrow(text: "Again?")
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                name = suggestion
                                nameFocused = false
                            } label: {
                                Text(suggestion)
                                    .font(Vida.sans(13))
                                    .foregroundStyle(Vida.forest)
                                    .lineLimit(1)
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 8)
                                    .background(Vida.sage.opacity(0.2), in: Capsule())
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var recentNames: [String] {
        var seen: Set<String> = []
        var names: [String] = []
        for meal in store.meals.sorted(by: { $0.date > $1.date }) {
            let trimmed = meal.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = meal.groupingKey
            guard !trimmed.isEmpty, !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            names.append(trimmed)
            if names.count == 8 { break }
        }
        return names
    }

    private var comfortSlider: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Eyebrow(text: "How did it sit?")
                Spacer()
                Text(ratedComfort ? "\(Int(howItSat))" : "—")
                    .font(Vida.sans(14, weight: .medium))
                    .foregroundStyle(ratedComfort ? Vida.moss : Vida.taupe)
            }

            Slider(value: $howItSat, in: 0...10, step: 1) { editing in
                if editing { ratedComfort = true }
            }
            .tint(Vida.moss)
            .onChange(of: howItSat) { _, _ in ratedComfort = true }

            Text(ratedComfort
                 ? "Rated. This is what links a meal to your digestion signal."
                 : "Optional — skip it and Vida just records the meal.")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.taupe)
        }
    }

    // MARK: - Persistence

    private func loadExisting() {
        guard let editing else { return }
        name = editing.name
        note = editing.note
        kind = editing.kind
        if let sat = editing.howItSat {
            howItSat = Double(sat)
            ratedComfort = true
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if var editing {
            editing.name = trimmed
            editing.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            editing.kind = kind
            editing.howItSat = ratedComfort ? Int(howItSat) : nil
            store.updateMeal(editing)
        } else {
            store.addMeal(
                MealEntry(
                    date: date,
                    kind: kind,
                    name: trimmed,
                    note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                    howItSat: ratedComfort ? Int(howItSat) : nil
                )
            )
        }
        dismiss()
    }
}

/// Today's meals, with a way to add one. Sits on the home screen under the
/// signals so food is logged in the same pass as everything else.
struct TodayMealsSection: View {
    @Environment(VidaStore.self) private var store
    @State private var showComposer = false
    @State private var editing: MealEntry?

    private var todayMeals: [MealEntry] { store.meals(on: store.today) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // The heading's trailing closure is its tap action, so the link
            // itself is "Add a meal" rather than a separate button.
            SectionHeading(
                eyebrow: "Today",
                title: "What you ate",
                action: { showComposer = true },
                actionLabel: "Add a meal"
            )
            .padding(.horizontal, 2)

            if todayMeals.isEmpty {
                Button {
                    showComposer = true
                } label: {
                    HStack(spacing: 11) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(Vida.sage)
                        Text("Add what you've eaten today")
                            .font(Vida.sans(14))
                            .foregroundStyle(Vida.inkSoft)
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Vida.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PressableStyle())
            } else {
                VStack(spacing: 9) {
                    ForEach(todayMeals) { meal in
                        Button {
                            editing = meal
                        } label: {
                            HStack(alignment: .top, spacing: 13) {
                                Image(systemName: meal.kind.symbol)
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundStyle(Vida.moss)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(meal.name)
                                        .font(Vida.sans(15, weight: .medium))
                                        .foregroundStyle(Vida.forest)
                                        .multilineTextAlignment(.leading)
                                    Text(meal.kind.title)
                                        .font(Vida.sans(12))
                                        .foregroundStyle(Vida.taupe)
                                }
                                Spacer(minLength: 0)
                                if let sat = meal.howItSat {
                                    Text("\(sat)")
                                        .font(Vida.sans(13, weight: .medium))
                                        .foregroundStyle(Vida.inkSoft)
                                }
                            }
                            .padding(15)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Vida.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
        .sheet(isPresented: $showComposer) { MealLogView() }
        .sheet(item: $editing) { meal in MealLogView(editing: meal, date: meal.date) }
    }
}
