import Foundation

/// Where a reading came from. Optional so snapshots saved before Apple Health
/// support was added still decode cleanly — `nil` means the member typed it.
nonisolated enum ReadingSource: String, Codable, Hashable {
    case manual
    case appleHealth

    var label: String {
        switch self {
        case .manual: "You"
        case .appleHealth: "Apple Health"
        }
    }
}

/// A single logged reading for one category on one day.
nonisolated struct SignalReading: Codable, Hashable, Identifiable {
    var id = UUID()
    var category: SignalCategory
    /// 0–10 for most categories; hours for sleep.
    var value: Double
    var tags: [String] = []
    var note: String = ""
    var source: ReadingSource?
    /// Which half of the day this was logged in. Optional so snapshots saved
    /// before twice-daily check-ins still decode cleanly.
    var period: CheckInPeriod?

    /// The exact instant this was recorded, in UTC.
    ///
    /// The `DayLog` it lives in is keyed by the *local* date she was living in
    /// when she logged it — a check-in belongs to the day it felt like, not to
    /// whatever UTC said at the time. This absolute timestamp is kept alongside
    /// so travel across timezones can never reshuffle her history.
    var recordedAt: Date?

    /// The timezone she was in. Optional for decode compatibility.
    var timeZoneIdentifier: String?

    /// Set when the entry is for a day other than the one it was typed on.
    var isBackdated: Bool?

    /// True when the member entered this herself — imports must never overwrite it.
    var isManual: Bool { (source ?? .manual) == .manual }

    /// Marks the reading with the moment and place it was entered.
    mutating func stamp(on day: Date, now: Date = .now) {
        recordedAt = now
        timeZoneIdentifier = TimeZone.current.identifier
        isBackdated = !Calendar.current.isDate(day, inSameDayAs: now)
    }

    /// Longest note Vida will store. Enforced in the field so a long entry is
    /// stopped as it's typed rather than silently truncated on save.
    static let noteLimit: Int = 500
}

/// Everything logged on a given calendar day.
nonisolated struct DayLog: Codable, Hashable, Identifiable {
    var id = UUID()
    var date: Date
    var readings: [SignalReading] = []

    /// The day's value for a category. When both halves of the day recorded it,
    /// the evening reading wins — it is the fuller account of the day.
    func reading(for category: SignalCategory) -> SignalReading? {
        let matches = readings.filter { $0.category == category }
        if let evening = matches.first(where: { $0.period == .evening }) { return evening }
        return matches.first
    }

    func reading(for category: SignalCategory, period: CheckInPeriod) -> SignalReading? {
        readings.first { $0.category == category && $0.period == period }
    }

    var loggedCategories: Set<SignalCategory> {
        Set(readings.map(\.category))
    }

    func categories(in period: CheckInPeriod) -> Set<SignalCategory> {
        Set(readings.filter { $0.period == period }.map(\.category))
    }

    /// True when anything here was entered on a later day than it describes.
    var containsBackdated: Bool {
        readings.contains { $0.isBackdated == true }
    }

    /// A period counts as done once anything was logged in it. Readings saved
    /// before periods existed are credited to the morning so old streaks and
    /// report counts don't silently collapse to zero.
    var completedPeriods: Set<CheckInPeriod> {
        var done: Set<CheckInPeriod> = []
        for reading in readings {
            done.insert(reading.period ?? .morning)
        }
        return done
    }

    func isComplete(_ period: CheckInPeriod) -> Bool {
        completedPeriods.contains(period)
    }
}

/// A discovered relationship between two categories.
nonisolated struct PatternLink: Identifiable, Hashable {
    var id: String { "\(a.rawValue)-\(b.rawValue)" }
    let a: SignalCategory
    let b: SignalCategory
    /// -1…1 correlation coefficient.
    let strength: Double
    let sampleSize: Int

    var magnitude: Double { abs(strength) }

    var isMeaningful: Bool { magnitude >= 0.35 && sampleSize >= 6 }

    var descriptor: String {
        switch magnitude {
        case 0.7...: "Strong"
        case 0.5..<0.7: "Clear"
        case 0.35..<0.5: "Emerging"
        default: "Faint"
        }
    }
}

/// A personal experiment the user runs on herself.
nonisolated struct Experiment: Codable, Hashable, Identifiable {
    var id = UUID()
    var templateID: String
    var title: String
    var question: String
    var driver: SignalCategory
    var outcome: SignalCategory
    /// Values of `driver` at or above this count as the "high" arm.
    var threshold: Double
    var highArmLabel: String
    var lowArmLabel: String
    var durationDays: Int
    var startDate: Date
    var isComplete: Bool = false

    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: durationDays, to: startDate) ?? startDate
    }
}

nonisolated struct ExperimentTemplate: Identifiable, Hashable {
    let id: String
    let labName: String
    let question: String
    let driver: SignalCategory
    let outcome: SignalCategory
    let threshold: Double
    let highArmLabel: String
    let lowArmLabel: String
    let durationDays: Int
    let blurb: String

    static let all: [ExperimentTemplate] = [
        .init(id: "sleep", labName: "Sleep Lab", question: "Does getting 8+ hours of sleep change my headaches?",
              driver: .sleep, outcome: .headache, threshold: 8,
              highArmLabel: "8+ hour nights", lowArmLabel: "Under 8 hours", durationDays: 14,
              blurb: "Log sleep and head pain for two weeks and compare the two arms."),
        .init(id: "movement", labName: "Movement Lab", question: "Does moving my body change my energy the next day?",
              driver: .movement, outcome: .energy, threshold: 6,
              highArmLabel: "Active days", lowArmLabel: "Quieter days", durationDays: 14,
              blurb: "A gentle look at whether movement pays you back in energy."),
        .init(id: "stress", labName: "Stress Lab", question: "Does stress track with my digestion?",
              driver: .stress, outcome: .digestion, threshold: 6,
              highArmLabel: "High-pressure days", lowArmLabel: "Calmer days", durationDays: 14,
              blurb: "The gut-brain axis is real. See whether yours shows up in your data."),
        .init(id: "nutrition", labName: "Nutrition Lab", question: "Does eating regularly change my mood?",
              driver: .nutrition, outcome: .mood, threshold: 6,
              highArmLabel: "Well-nourished days", lowArmLabel: "Skipped or light days", durationDays: 14,
              blurb: "Blood sugar and mood are closely linked. Test it on yourself."),
        .init(id: "cycle", labName: "Cycle Lab", question: "Is my focus different across my cycle?",
              driver: .cycle, outcome: .focus, threshold: 3,
              highArmLabel: "Bleeding days", lowArmLabel: "Non-bleeding days", durationDays: 28,
              blurb: "One full cycle of data, then a clear comparison."),
        .init(id: "hydration", labName: "Hydration Lab", question: "Does hydration change my head pain?",
              driver: .nutrition, outcome: .headache, threshold: 7,
              highArmLabel: "Well-hydrated days", lowArmLabel: "Low-water days", durationDays: 14,
              blurb: "Dehydration is one of the most common headache triggers. Check yours.")
    ]
}

/// One day inside an experiment window, used for the day-by-day strip.
nonisolated struct ExperimentDay: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let driver: Double?
    let outcome: Double?

    var isComplete: Bool { driver != nil && outcome != nil }
    var isPartial: Bool { !isComplete && (driver != nil || outcome != nil) }
}

nonisolated struct ExperimentResult {
    let highArmRate: Double
    let lowArmRate: Double
    let highArmDays: Int
    let lowArmDays: Int
    let outcome: SignalCategory

    var hasEnoughData: Bool { highArmDays >= 2 && lowArmDays >= 2 }
}

/// A saved doctor-appointment preparation.
nonisolated struct DoctorPrep: Codable, Hashable, Identifiable {
    var id = UUID()
    var concern: String
    var bodyArea: String
    var onset: String
    var frequency: String
    var typicalSeverity: Int
    var worstSeverity: Int
    var associatedSymptoms: [String]
    var impact: [String]
    var triedAlready: [String]
    var questions: [String]
    var createdAt: Date = .now
}
