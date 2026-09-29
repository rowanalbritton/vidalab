import SwiftUI

/// Her diary: free writing about her life, with each day's check-in woven
/// into the page it belongs to. Writing at the end of a check-in lands here
/// automatically; she can also open the diary and write any time.
struct DiaryView: View {
    @Environment(VidaStore.self) private var store
    @State private var editing: DiaryEntry?
    @State private var query: String = ""

    private var days: [Date] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return store.diaryDays }
        return store.diaryDays.filter { day in
            store.diaryEntries(on: day).contains { $0.text.localizedStandardContains(trimmed) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                Button { newEntry() } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(Vida.onForest)
                            .frame(width: 44, height: 44)
                            .background(Vida.forest, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Write today")
                                .font(Vida.sans(17, weight: .medium))
                                .foregroundStyle(Vida.forest)
                            Text(DiaryPrompts.forToday())
                                .font(Vida.serifItalic(15))
                                .foregroundStyle(Vida.inkSoft)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .paperCard(padding: 18)
                }
                .buttonStyle(PressableStyle())

                if days.isEmpty {
                    QuietEmptyState(
                        symbol: "book.closed",
                        title: query.isEmpty ? "A blank first page" : "Nothing matches",
                        message: query.isEmpty
                            ? "Write whenever you like, or add a few lines at the end of a check-in. Your check-ins appear here beside your words."
                            : "Try another word."
                    )
                    .paperCard(padding: 8)
                } else {
                    ForEach(days, id: \.self) { day in
                        dayPage(day)
                    }
                }
            }
            .padding(.horizontal, Vida.Space.gutter)
            .padding(.bottom, 40)
            .readableColumn()
        }
        .scrollIndicators(.hidden)
        .vidaScrollChrome("Diary")
        .vidaBackground()
        .searchable(text: $query, prompt: "Search your diary")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { DiaryEditor(entry: $0) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Vida.headline("Your ", accent: "diary")
                .tracking(Vida.displayTracking)
            Text("Your life in your words, with each day's check-in beside it. Everything here stays on this phone.")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
        .vidaParallaxHeader()
    }

    // MARK: - A day

    private func dayPage(_ day: Date) -> some View {
        let entries = store.diaryEntries(on: day)
        let log = store.log(on: day)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(Vida.sans(12, weight: .semibold))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Vida.taupe)
                Spacer()
                if Calendar.current.isDateInToday(day) {
                    Text("Today")
                        .font(Vida.sans(11, weight: .semibold))
                        .foregroundStyle(Vida.moss)
                }
            }

            if let log, !log.readings.isEmpty {
                checkInStrip(log)
            }

            ForEach(entries) { entry in
                Button { editing = entry } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        if let period = entry.period {
                            Label(period == .morning ? "After the morning check-in" : "After the evening check-in", systemImage: period.symbol)
                                .font(Vida.sans(11, weight: .medium))
                                .foregroundStyle(Vida.taupe)
                        }
                        Text(entry.text)
                            .font(Vida.serifItalic(17))
                            .foregroundStyle(Vida.ink)
                            .lineSpacing(5)
                            .multilineTextAlignment(.leading)
                            .lineLimit(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(PressableStyle())
            }

            if entries.isEmpty {
                Button {
                    editing = DiaryEntry(date: day, text: "", prompt: DiaryPrompts.forToday(day))
                } label: {
                    Label("Add a few words to this day", systemImage: "plus")
                        .font(Vida.sans(13, weight: .medium))
                        .foregroundStyle(Vida.moss)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }

    /// The day's check-in, compact: each signal she logged and its value.
    private func checkInStrip(_ log: DayLog) -> some View {
        let categories = SignalCategory.allCases.filter { log.loggedCategories.contains($0) }
        return ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(categories) { category in
                    if let reading = log.reading(for: category) {
                        HStack(spacing: 5) {
                            Circle().fill(category.accent).frame(width: 6, height: 6)
                            Text(category.title)
                                .foregroundStyle(Vida.inkSoft)
                            Text(category == .sleep ? "\(reading.value.formatted(.number.precision(.fractionLength(0...1))))h" : "\(Int(reading.value.rounded()))")
                                .foregroundStyle(Vida.forest)
                                .monospacedDigit()
                        }
                        .font(Vida.sans(12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Vida.shell.opacity(0.7), in: Capsule())
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .combine)
    }

    private func newEntry() {
        editing = DiaryEntry(
            date: Calendar.current.startOfDay(for: .now),
            text: "",
            prompt: DiaryPrompts.forToday()
        )
    }
}

/// A full page for writing. Saves on Done; clearing the text removes it.
struct DiaryEditor: View {
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var entry: DiaryEntry
    @State private var confirmDelete = false
    @FocusState private var focused: Bool

    private var isExisting: Bool { store.diary.contains { $0.id == entry.id } }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(Vida.sans(12, weight: .semibold))
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Vida.taupe)
                    if let prompt = entry.prompt {
                        Text(prompt)
                            .font(Vida.display(24))
                            .tracking(Vida.displayTracking)
                            .foregroundStyle(Vida.forest)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                TextEditor(text: $entry.text)
                    .font(Vida.serifItalic(19))
                    .foregroundStyle(Vida.ink)
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                    .focused($focused)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .background { VidaCanvas().ignoresSafeArea() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isExisting {
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Image(systemName: "trash")
                        }
                        .foregroundStyle(Vida.taupe)
                        .accessibilityLabel("Delete entry")
                    } else {
                        Button("Cancel") { dismiss() }
                            .font(Vida.sans(15))
                            .foregroundStyle(Vida.inkSoft)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        store.saveDiary(entry)
                        dismiss()
                    }
                    .font(Vida.sans(15, weight: .semibold))
                    .foregroundStyle(Vida.moss)
                }
            }
            .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.deleteDiary(entry)
                    dismiss()
                }
            }
            .onAppear {
                if entry.text.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focused = true }
                }
            }
        }
    }
}
