import Foundation

/// A month, read back.
///
/// Wrapped-style in shape — a handful of cards, one number each — but not in
/// tone. The genre's usual move is to celebrate a big total, and for someone
/// tracking a chronic illness "you logged pain on 22 days" is not a
/// celebration. So Lab Notes reports rather than congratulates, and never
/// frames a worse month as a personal failure.
nonisolated struct LabNotes: Identifiable, Sendable {
    /// First day of the month being reported on.
    let month: Date
    let checkInDays: Int
    let daysInMonth: Int
    let cards: [LabNoteCard]

    var id: Date { month }

    var monthName: String {
        month.formatted(.dateTime.month(.wide).year())
    }

    /// Below this there isn't a month worth reading back, and showing one
    /// anyway makes the app look like it wasn't paying attention.
    static let minimumCheckInDays = 5
}

/// One screen of the recap.
nonisolated struct LabNoteCard: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable {
        case consistency, meal, signal, pattern, experiment, closing
    }

    let kind: Kind
    /// Small text above the headline.
    let eyebrow: String
    /// The big one. Kept short — this is the thing read at a glance.
    let headline: String
    /// A sentence of context underneath.
    let detail: String
    let symbol: String

    var id: String { kind.rawValue + headline }
}

nonisolated enum LabNotesEngine {

    /// Builds the recap for the month containing `reference`.
    ///
    /// Returns nil when the month is too thin to say anything honest about.
    static func build(
        month reference: Date,
        logs: [DayLog],
        meals: [MealEntry],
        experiments: [Experiment],
        links: [PatternLink],
        profile: HealthProfile,
        calendar: Calendar = .current
    ) -> LabNotes? {
        guard let interval = calendar.dateInterval(of: .month, for: reference) else { return nil }
        let start = interval.start
        let end = interval.end

        let monthLogs = logs.filter { $0.date >= start && $0.date < end }
        let monthMeals = meals.filter { $0.date >= start && $0.date < end }
        let checkInDays = monthLogs.filter { !$0.readings.isEmpty }.count

        guard checkInDays >= LabNotes.minimumCheckInDays else { return nil }

        let daysInMonth = calendar.range(of: .day, in: .month, for: start)?.count ?? 30

        var cards: [LabNoteCard] = [
            consistencyCard(checkInDays: checkInDays, daysInMonth: daysInMonth)
        ]

        if let meal = mealCard(monthMeals) { cards.append(meal) }
        cards.append(contentsOf: signalCards(monthLogs, profile: profile))
        if let pattern = patternCard(links) { cards.append(pattern) }
        if let experiment = experimentCard(experiments, start: start, end: end) {
            cards.append(experiment)
        }
        cards.append(closingCard(checkInDays: checkInDays))

        return LabNotes(
            month: start,
            checkInDays: checkInDays,
            daysInMonth: daysInMonth,
            cards: cards
        )
    }

    // MARK: - Cards

    private static func consistencyCard(checkInDays: Int, daysInMonth: Int) -> LabNoteCard {
        let share = Double(checkInDays) / Double(daysInMonth)
        let detail: String
        switch share {
        case 0.9...:
            detail = "Almost every day. That's a genuinely unusual run of data to have about yourself."
        case 0.5..<0.9:
            detail = "Enough days to see shape rather than noise, which is the whole point."
        default:
            detail = "Every logged day still counts. Patterns need repetition, not perfection."
        }

        return LabNoteCard(
            kind: .consistency,
            eyebrow: "You showed up",
            headline: "\(checkInDays) days",
            detail: detail,
            symbol: "calendar"
        )
    }

    private static func mealCard(_ meals: [MealEntry]) -> LabNoteCard? {
        let favourites = MealInsights.favourites(in: meals, limit: 3)
        guard let top = favourites.first, top.count >= 2 else { return nil }

        var detail = "You logged it \(top.count) times."
        if favourites.count > 1 {
            let others = favourites.dropFirst().map(\.name).joined(separator: " and ")
            detail += " Then \(others)."
        }
        if let comfort = top.averageComfort {
            detail += comfort >= 6.5
                ? " It usually sat well."
                : (comfort <= 3.5 ? " It often didn't sit well — worth a closer look." : "")
        }

        return LabNoteCard(
            kind: .meal,
            eyebrow: "On repeat",
            headline: top.name,
            detail: detail,
            symbol: "fork.knife"
        )
    }

    /// The two signals that moved most, up or down.
    ///
    /// Direction is reported plainly and never praised or scolded. Pain going
    /// up is information, not a report card — and so is energy going down.
    ///
    /// That rules out `higherIsBetter` here. Reading "better" over a rising
    /// number quietly turns the recap into a verdict on how well she managed
    /// an illness she didn't choose, and the same logic makes a bad month read
    /// as a personal failure. The verbs stay symmetrical for the same reason:
    /// "eased" sounds like relief, which is right for pain and wrong for
    /// everything else.
    private static func signalCards(_ logs: [DayLog], profile: HealthProfile) -> [LabNoteCard] {
        let categories = SignalCategory.checkInSet.filter(profile.includes)
        var movements: [(category: SignalCategory, first: Double, second: Double, change: Double)] = []

        let sorted = logs.sorted { $0.date < $1.date }
        let midpoint = sorted.count / 2
        guard midpoint >= 2 else { return [] }

        let firstHalf = sorted.prefix(midpoint)
        let secondHalf = sorted.suffix(sorted.count - midpoint)

        for category in categories {
            let early = firstHalf.compactMap { $0.reading(for: category)?.value }
            let late = secondHalf.compactMap { $0.reading(for: category)?.value }
            guard early.count >= 2, late.count >= 2 else { continue }

            let earlyAverage = early.reduce(0, +) / Double(early.count)
            let lateAverage = late.reduce(0, +) / Double(late.count)
            let change = lateAverage - earlyAverage
            guard abs(change) >= 0.8 else { continue }

            movements.append((category, earlyAverage, lateAverage, change))
        }

        return movements
            .sorted { abs($0.change) > abs($1.change) }
            .prefix(2)
            .map { movement in
                let rose = movement.change > 0

                return LabNoteCard(
                    kind: .signal,
                    eyebrow: "\(movement.category.title) \(rose ? "rose" : "fell")",
                    headline: String(format: "%.1f → %.1f", movement.first, movement.second),
                    // Says what the two numbers are. Without it the headline
                    // is a pair of decimals with no stated comparison.
                    detail: "Second half of the month, against the first.",
                    symbol: movement.category.symbol
                )
            }
    }

    private static func patternCard(_ links: [PatternLink]) -> LabNoteCard? {
        guard let strongest = links.max(by: { $0.magnitude < $1.magnitude }) else { return nil }
        return LabNoteCard(
            kind: .pattern,
            eyebrow: "\(strongest.descriptor.lowercased()) link",
            headline: "\(strongest.a.title) & \(strongest.b.title)",
            detail: "Vida keeps seeing these two move together across \(strongest.sampleSize) days. It's a correlation in your own data, not a cause.",
            symbol: "point.3.connected.trianglepath.dotted"
        )
    }

    private static func experimentCard(
        _ experiments: [Experiment],
        start: Date,
        end: Date
    ) -> LabNoteCard? {
        let active = experiments.filter { $0.startDate < end }
        guard !active.isEmpty else { return nil }

        return LabNoteCard(
            kind: .experiment,
            eyebrow: "In the lab",
            headline: active.count == 1 ? "1 experiment" : "\(active.count) experiments",
            detail: active.count == 1
                ? "You tested something properly instead of guessing at it."
                : "You tested several things properly instead of guessing at them.",
            symbol: "flask"
        )
    }

    private static func closingCard(checkInDays: Int) -> LabNoteCard {
        LabNoteCard(
            kind: .closing,
            eyebrow: "That was your month",
            headline: "Still here",
            detail: "\(checkInDays) days of evidence about your own body that nobody can tell you isn't real. That's what this is for.",
            symbol: "leaf"
        )
    }
}
