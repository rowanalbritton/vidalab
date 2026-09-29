import Foundation

/// How one tracked signal moved between last week and this one.
nonisolated struct WeeklySignalChange: Identifiable, Hashable {
    var id: String { category.rawValue }
    let category: SignalCategory
    let thisWeek: Double
    let lastWeek: Double?
    let readings: Int

    /// Change from last week in raw units. `nil` when there's nothing to compare.
    var delta: Double? {
        guard let lastWeek else { return nil }
        return thisWeek - lastWeek
    }

    /// Whether the move was in the direction she'd want. `nil` when flat or
    /// uncomparable — Vida refuses to spin a rounding error as progress.
    var isImprovement: Bool? {
        guard let delta, abs(delta) >= changeThreshold else { return nil }
        return category.higherIsBetter ? delta > 0 : delta < 0
    }

    /// Below this, a change is noise rather than news.
    private var changeThreshold: Double { category == .sleep ? 0.4 : 0.6 }

    var display: String { WeeklySignalChange.format(thisWeek, category) }

    var deltaDisplay: String? {
        guard let delta, abs(delta) >= changeThreshold else { return nil }
        let magnitude = WeeklySignalChange.format(abs(delta), category, isDelta: true)
        return delta > 0 ? "+\(magnitude)" : "−\(magnitude)"
    }

    static func format(_ value: Double, _ category: SignalCategory, isDelta: Bool = false) -> String {
        if category == .sleep {
            let hours = Int(value)
            let minutes = Int((value - Double(hours)) * 60)
            if isDelta && hours == 0 { return "\(minutes)m" }
            return minutes == 0 ? "\(hours)h" : "\(hours)h \(String(format: "%02d", minutes))m"
        }
        return String(format: "%.1f", value)
    }
}

/// A full week, read back to her. This is the artefact she can hand to a
/// clinician, send to herself, or simply use to see that a bad week was in
/// fact a bad week and not a failure of character.
nonisolated struct WeeklyReport {
    let weekStart: Date
    let weekEnd: Date
    let name: String
    let daysLogged: Int
    let checkInsCompleted: Int
    let possibleCheckIns: Int
    /// Changes for the signals her profile says matter most.
    let focusChanges: [WeeklySignalChange]
    let bestDay: (date: Date, score: Double)?
    let hardestDay: (date: Date, score: Double)?
    let newConnections: [PatternLink]
    let runningExperiments: [String]
    let goals: [HealthGoal]
    let conditionNames: [String]

    var hasEnoughData: Bool { daysLogged >= 2 }

    var rangeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: weekStart)) – \(formatter.string(from: weekEnd))"
    }

    var consistency: Double {
        guard possibleCheckIns > 0 else { return 0 }
        return min(1, Double(checkInsCompleted) / Double(possibleCheckIns))
    }

    /// The one-line summary at the top. Never congratulatory when the data
    /// doesn't support it, and never bleak when it does.
    var headline: String {
        guard hasEnoughData else {
            return "Not enough of this week is logged to say anything honest about it."
        }
        let improved = focusChanges.filter { $0.isImprovement == true }
        let worsened = focusChanges.filter { $0.isImprovement == false }

        if improved.isEmpty && worsened.isEmpty {
            return "A steady week. Nothing moved far enough to call it a change."
        }
        if worsened.isEmpty {
            let names = improved.prefix(2).map { $0.category.title.lowercased() }
            return "A better week for \(names.joined(separator: " and "))."
        }
        if improved.isEmpty {
            let names = worsened.prefix(2).map { $0.category.title.lowercased() }
            return "A harder week for \(names.joined(separator: " and "))."
        }
        return "A mixed week: \(improved[0].category.title.lowercased()) improved while \(worsened[0].category.title.lowercased()) got harder."
    }

    /// What she should do with this week, framed by the goals she chose.
    var nextStep: String {
        if !hasEnoughData {
            return "Two check-ins a day is all it takes. Next week's report gets sharper with every one you log."
        }
        if consistency < 0.5 {
            return "You logged about \(Int(consistency * 100))% of your check-ins. Getting that above half is what turns these reports into evidence."
        }
        if !newConnections.isEmpty {
            return "Vida found something new in your data this week. The Patterns tab explains what it might mean, and offers an experiment to test it properly."
        }
        if goals.contains(.prepareAppointments) {
            return "You have enough here for Doctor Prep. It turns this week into dates, numbers and questions you can hand over."
        }
        if goals.contains(.findTriggers) || goals.contains(.trackTreatment) {
            return "A Lab experiment is the honest way to test a suspicion. Two weeks of logging both signals gives you a real before-and-after."
        }
        return "Keep going. Patterns need about two weeks of data before they mean anything, and you're building that."
    }

    /// Plain-text rendering used for the email body and the share sheet.
    var plainText: String {
        var lines: [String] = []
        lines.append("VIDA LAB: Your week")
        lines.append(rangeLabel)
        if !name.isEmpty { lines.append("For \(name)") }
        lines.append("")
        lines.append(headline)
        lines.append("")

        lines.append("CONSISTENCY")
        lines.append("\(daysLogged) day\(daysLogged == 1 ? "" : "s") logged · \(checkInsCompleted) of \(possibleCheckIns) check-ins")
        lines.append("")

        if !focusChanges.isEmpty {
            lines.append("YOUR KEY SIGNALS")
            for change in focusChanges {
                var line = "· \(change.category.title): \(change.display)"
                if let delta = change.deltaDisplay {
                    line += " (\(delta) vs last week)"
                } else if change.lastWeek != nil {
                    line += " (about the same as last week)"
                }
                lines.append(line)
            }
            lines.append("")
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMM"
        if let best = bestDay {
            lines.append("EASIEST DAY: \(formatter.string(from: best.date))")
        }
        if let hardest = hardestDay {
            lines.append("HARDEST DAY: \(formatter.string(from: hardest.date))")
        }
        if bestDay != nil || hardestDay != nil { lines.append("") }

        if !newConnections.isEmpty {
            lines.append("PATTERNS WORTH NOTICING")
            for link in newConnections {
                lines.append("· \(PatternExplainer.shortMeaning(for: link)) (\(link.sampleSize) days of data)")
            }
            lines.append("")
        }

        if !runningExperiments.isEmpty {
            lines.append("EXPERIMENTS RUNNING")
            for title in runningExperiments { lines.append("· \(title)") }
            lines.append("")
        }

        lines.append("WHAT TO DO NEXT")
        lines.append(nextStep)
        lines.append("")
        lines.append("—")
        lines.append("This is a record of what you logged, not a diagnosis. Two things moving together doesn't mean one caused the other. VIDA LAB is an educational tool and does not replace care from a qualified clinician.")

        return lines.joined(separator: "\n")
    }
}

nonisolated enum WeeklyReportEngine {
    /// Builds the report for a week. `weeksAgo: 0` is the current week.
    static func build(
        logs: [DayLog],
        profile: HealthProfile,
        links: [PatternLink],
        experiments: [Experiment],
        name: String,
        weeksAgo: Int = 0,
        today: Date = Calendar.current.startOfDay(for: .now)
    ) -> WeeklyReport {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: -7 * weeksAgo, to: today) ?? today
        let start = calendar.date(byAdding: .day, value: -6, to: end) ?? end
        let priorStart = calendar.date(byAdding: .day, value: -7, to: start) ?? start
        let priorEnd = calendar.date(byAdding: .day, value: -1, to: start) ?? start

        let thisWeekLogs = logs.filter { $0.date >= start && $0.date <= end }
        let lastWeekLogs = logs.filter { $0.date >= priorStart && $0.date <= priorEnd }

        // Focus signals come from her profile, capped so the report stays
        // readable — five numbers you act on beat twelve you skim.
        let focus = Array(profile.focusSignals.prefix(5))
        let changes: [WeeklySignalChange] = focus.compactMap { category in
            let current = values(of: category, in: thisWeekLogs)
            guard !current.isEmpty else { return nil }
            let prior = values(of: category, in: lastWeekLogs)
            return WeeklySignalChange(
                category: category,
                thisWeek: average(current),
                lastWeek: prior.isEmpty ? nil : average(prior),
                readings: current.count
            )
        }

        let scored = thisWeekLogs.compactMap { log -> (Date, Double)? in
            guard let score = dayScore(log) else { return nil }
            return (log.date, score)
        }

        let checkIns = thisWeekLogs.reduce(0) { $0 + $1.completedPeriods.count }
        let daysElapsed = min(7, (calendar.dateComponents([.day], from: start, to: today).day ?? 6) + 1)

        return WeeklyReport(
            weekStart: start,
            weekEnd: end,
            name: name,
            daysLogged: thisWeekLogs.count,
            checkInsCompleted: checkIns,
            possibleCheckIns: max(1, daysElapsed * 2),
            focusChanges: changes,
            bestDay: scored.max(by: { $0.1 < $1.1 }).map { (date: $0.0, score: $0.1) },
            hardestDay: scored.min(by: { $0.1 < $1.1 }).map { (date: $0.0, score: $0.1) },
            newConnections: Array(links.filter(\.isMeaningful).prefix(3)),
            runningExperiments: experiments.map(\.title),
            goals: profile.goals,
            conditionNames: profile.conditionNames
        )
    }

    private static func values(of category: SignalCategory, in logs: [DayLog]) -> [Double] {
        logs.compactMap { $0.reading(for: category)?.value }
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// A rough "how was this day" score: good things add, bad things subtract.
    /// Only used to surface the easiest and hardest day, never shown as a number
    /// — nobody needs their pain scored out of ten by an app.
    private static func dayScore(_ log: DayLog) -> Double? {
        let relevant = log.readings.filter { $0.category != .cycle }
        guard relevant.count >= 2 else { return nil }
        var total = 0.0
        for reading in relevant {
            let normalized = reading.category == .sleep
                ? min(10, reading.value / 9.0 * 10)
                : reading.value
            total += reading.category.higherIsBetter ? normalized : (10 - normalized)
        }
        return total / Double(relevant.count)
    }
}
