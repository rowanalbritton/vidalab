import SwiftUI

/// Identifiable wrapper so a chosen day can drive `.sheet(item:)`.
nonisolated struct LogDay: Identifiable, Hashable {
    let date: Date
    var id: Date { date }
}

/// Logs both signals of an experiment for a single day.
///
/// An experiment compares two things, so it only produces a usable data point
/// when both are recorded. Logging them together in one sheet is what makes the
/// result trustworthy — and it works for past days too, so a missed day can be
/// filled in while it's still fresh.
struct ExperimentDayLogView: View {
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let experiment: Experiment
    let date: Date

    @State private var driverValue: Double = 5
    @State private var outcomeValue: Double = 5
    @State private var didLoad: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    signalCard(
                        category: experiment.driver,
                        value: $driverValue,
                        role: "What you're changing"
                    )
                    signalCard(
                        category: experiment.outcome,
                        value: $outcomeValue,
                        role: "What you're watching"
                    )
                    armPreview
                    saveButton
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(Vida.sans(15))
                        .foregroundStyle(Vida.inkSoft)
                }
                ToolbarItem(placement: .principal) {
                    Text(isToday ? "TODAY" : dayLabel.uppercased())
                        .font(Vida.sans(12, weight: .bold))
                        .tracking(2.0)
                        .foregroundStyle(Vida.forest)
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
        .onAppear(perform: loadExisting)
    }

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    private var dayLabel: String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// Prefills from anything already logged that day so editing never
    /// silently resets a value she set earlier.
    private func loadExisting() {
        guard !didLoad else { return }
        didLoad = true
        let log = store.log(on: date)
        driverValue = log?.reading(for: experiment.driver)?.value
            ?? (experiment.driver == .sleep ? 7.5 : 5)
        outcomeValue = log?.reading(for: experiment.outcome)?.value
            ?? (experiment.outcome == .sleep ? 7.5 : 5)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: experiment.title, color: Vida.moss)
            Text(experiment.question)
                .font(Vida.serif(25))
                .foregroundStyle(Vida.forest)
                .fixedSize(horizontal: false, vertical: true)
            Text(isToday
                 ? "Two quick readings and today becomes a data point."
                 : "Filling in \(dayLabel). Logging from memory is fine — an approximate answer beats a gap.")
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private func signalCard(category: SignalCategory, value: Binding<Double>, role: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: category.symbol)
                    .font(.system(size: 14))
                    .foregroundStyle(category.accent)
                Eyebrow(text: role)
            }

            Text(category.prompt)
                .font(Vida.sans(16, weight: .medium))
                .foregroundStyle(Vida.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(readout(category, value.wrappedValue))
                    .font(Vida.number(38, weight: .regular))
                    .foregroundStyle(Vida.forest)
                    .contentTransition(.numericText())
                Text(category.unitLabel)
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.taupe)
            }

            Slider(
                value: value,
                in: category == .sleep ? 0...12 : 0...10,
                step: category == .sleep ? 0.25 : 1
            )
            .tint(category.accent)

            HStack {
                Text(category == .sleep ? "None" : "None")
                Spacer()
                Text(category == .sleep ? "12 hours" : "Very high")
            }
            .font(Vida.sans(11))
            .foregroundStyle(Vida.taupe)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
        .animation(.snappy, value: value.wrappedValue)
    }

    private func readout(_ category: SignalCategory, _ value: Double) -> String {
        guard category == .sleep else { return "\(Int(value))" }
        let hours = Int(value)
        let minutes = Int((value - Double(hours)) * 60)
        return "\(hours)h \(String(format: "%02d", minutes))m"
    }

    /// Shows which arm of the study this day will land in, so the method stays
    /// visible rather than happening invisibly in the background.
    private var armPreview: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 14))
                .foregroundStyle(Vida.skyDeep)
            VStack(alignment: .leading, spacing: 4) {
                Text("This day counts as")
                    .font(Vida.sans(12))
                    .foregroundStyle(Vida.inkSoft)
                Text(driverValue >= experiment.threshold ? experiment.highArmLabel : experiment.lowArmLabel)
                    .font(Vida.sans(15, weight: .semibold))
                    .foregroundStyle(Vida.forest)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Vida.sky.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.snappy, value: driverValue >= experiment.threshold)
    }

    private var saveButton: some View {
        Button {
            store.logExperiment(experiment, driver: driverValue, outcome: outcomeValue, on: date)
            dismiss()
        } label: {
            Text(isToday ? "Log today" : "Save this day")
                .font(Vida.sans(17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Vida.forest, in: Capsule())
                .foregroundStyle(Vida.cream)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Day-by-day strip across an experiment window. Filled = both signals logged,
/// half = one, hollow = nothing yet. Tapping any day opens the log sheet.
struct ExperimentDayStrip: View {
    let days: [ExperimentDay]
    let onSelect: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(text: "Your logging")
                Spacer()
                Text("\(days.filter(\.isComplete).count) of \(days.count) days")
                    .font(Vida.number(12))
                    .foregroundStyle(Vida.taupe)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 34), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(days) { day in
                    Button {
                        onSelect(day.date)
                    } label: {
                        dayCell(day)
                    }
                    .buttonStyle(PressableStyle())
                }
            }

            HStack(spacing: 14) {
                legend(color: Vida.moss, label: "Logged")
                legend(color: Vida.sage.opacity(0.55), label: "Partial")
                legend(color: Vida.shell, label: "Empty")
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }

    private func dayCell(_ day: ExperimentDay) -> some View {
        let isToday = Calendar.current.isDateInToday(day.date)
        return VStack(spacing: 4) {
            Text(day.date.formatted(.dateTime.day()))
                .font(Vida.number(11))
                .foregroundStyle(day.isComplete ? Vida.cream : Vida.inkSoft)
            Circle()
                .fill(day.isComplete ? Vida.cream.opacity(0.9) : .clear)
                .frame(width: 3, height: 3)
        }
        .frame(width: 34, height: 38)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(fill(for: day))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isToday ? Vida.forest : .clear, lineWidth: 1.4)
        }
    }

    private func fill(for day: ExperimentDay) -> Color {
        if day.isComplete { return Vida.moss }
        if day.isPartial { return Vida.sage.opacity(0.55) }
        return Vida.shell
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 9, height: 9)
            Text(label)
                .font(Vida.sans(11))
                .foregroundStyle(Vida.taupe)
        }
    }
}
