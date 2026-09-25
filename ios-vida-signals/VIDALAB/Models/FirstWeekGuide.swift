import Foundation

/// The "Your first week" checklist: the handful of habits that make Vida
/// useful, each one ticked off by actually doing it.
///
/// Without this, someone who skipped the sample data sees a Pattern Map that
/// stays empty for days with no hint of why. Each step here is a thing that
/// either feeds the pattern engine or shows off a part of the app they may
/// not have found.
///
/// Pure logic over the store's data, so it can be tested without a view.
nonisolated enum FirstWeekGuide {
    /// Stored so a dismissed card stays gone across launches.
    static let dismissedKey = "vida.guide.firstWeek.dismissed.v1"
    /// Set by Ask Vida on the first submitted question. Questions themselves
    /// aren't persisted, so this is the only record that one was asked.
    static let askedKey = "vida.guide.askedQuestion.v1"
    /// Whether the app tour has been shown, automatically or by choice.
    static let tourSeenKey = "vida.guide.tourSeen.v1"

    enum Step: String, CaseIterable, Identifiable {
        case firstCheckIn, bothHalves, threeDays, appleHealth, askVida, experiment, doctorPrep

        var id: String { rawValue }

        var title: String {
            switch self {
            case .firstCheckIn: "Log your first check-in"
            case .bothHalves: "Check in morning and evening on the same day"
            case .threeDays: "Check in three days in a row"
            case .appleHealth: "Connect Apple Health"
            case .askVida: "Ask Vida a question"
            case .experiment: "Start an experiment"
            case .doctorPrep: "Save a doctor prep note"
            }
        }

        var detail: String {
            switch self {
            case .firstCheckIn:
                "About 30 seconds. It's the one thing Apple Health can't measure: how you feel."
            case .bothHalves:
                "Mornings and evenings tell different stories. Logging both is what lets Vida see how one shapes the other."
            case .threeDays:
                "Patterns need a run of days to compare. Short check-ins every day beat long ones now and then."
            case .appleHealth:
                "Brings in sleep, steps and cycle data automatically, so there's less to type."
            case .askVida:
                "Get a plain-language answer from cited research, with the sources shown."
            case .experiment:
                "Test one change, like an earlier bedtime, and see whether it moves how you feel."
            case .doctorPrep:
                "Turn what you've logged into questions and notes for your next appointment."
            }
        }

        var symbol: String {
            switch self {
            case .firstCheckIn: "sun.max"
            case .bothHalves: "sun.haze"
            case .threeDays: "calendar"
            case .appleHealth: "heart.text.square"
            case .askVida: "bubble.left.and.text.bubble.right"
            case .experiment: "flask"
            case .doctorPrep: "stethoscope"
            }
        }
    }

    /// Day logs that contain at least one check-in the member entered
    /// themselves.
    ///
    /// Filters out two kinds of reading that would otherwise tick steps for
    /// free: sample data, which is generated without an entry timestamp, and
    /// Apple Health imports, which arrive without anyone checking in.
    static func memberLogs(_ logs: [DayLog]) -> [DayLog] {
        logs.compactMap { log in
            let own = log.readings.filter { $0.isManual && $0.recordedAt != nil }
            guard !own.isEmpty else { return nil }
            var filtered = log
            filtered.readings = own
            return filtered
        }
    }

    /// Longest run of consecutive calendar days with a member check-in.
    static func longestRun(in logs: [DayLog], calendar: Calendar = .current) -> Int {
        let days = Set(logs.map { calendar.startOfDay(for: $0.date) }).sorted()
        var best = 0
        var current = 0
        var previous: Date?
        for day in days {
            if let previous,
               let next = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(next, inSameDayAs: day) {
                current += 1
            } else {
                current = 1
            }
            best = max(best, current)
            previous = day
        }
        return best
    }

    struct Inputs {
        var logs: [DayLog]
        var healthSyncEnabled: Bool
        var hasAskedQuestion: Bool
        var experimentCount: Int
        var prepCount: Int
    }

    static func completed(_ inputs: Inputs, calendar: Calendar = .current) -> Set<Step> {
        let own = memberLogs(inputs.logs)
        var done: Set<Step> = []
        if !own.isEmpty { done.insert(.firstCheckIn) }
        if own.contains(where: { $0.completedPeriods.count == CheckInPeriod.allCases.count }) {
            done.insert(.bothHalves)
        }
        if longestRun(in: own, calendar: calendar) >= 3 { done.insert(.threeDays) }
        if inputs.healthSyncEnabled { done.insert(.appleHealth) }
        if inputs.hasAskedQuestion { done.insert(.askVida) }
        if inputs.experimentCount > 0 { done.insert(.experiment) }
        if inputs.prepCount > 0 { done.insert(.doctorPrep) }
        return done
    }
}
