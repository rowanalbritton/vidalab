import Foundation

/// How the night felt, which is a different question from how long it lasted.
///
/// Six unbroken hours and six hours of waking every ninety minutes are the same
/// number and a completely different morning. Hours go on the reading's value so
/// every existing pattern, report and experiment keeps working; quality rides
/// along as a tag so nothing about the night is lost.
nonisolated enum SleepQuality: String, CaseIterable, Identifiable, Codable, Hashable {
    case rough, broken, okay, solid, deep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rough: "Rough"
        case .broken: "Broken"
        case .okay: "Okay"
        case .solid: "Solid"
        case .deep: "Deep"
        }
    }

    var symbol: String {
        switch self {
        case .rough: "cloud.rain"
        case .broken: "moon.zzz"
        case .okay: "moon"
        case .solid: "moon.stars"
        case .deep: "sparkles"
        }
    }

    /// Written onto the sleep reading, so quality shows up wherever tags do.
    var tag: String {
        switch self {
        case .rough: "Rough night"
        case .broken: "Broken night"
        case .okay: "Okay night"
        case .solid: "Slept solidly"
        case .deep: "Slept deeply"
        }
    }

    var caption: String {
        switch self {
        case .rough: "Barely counted as sleep."
        case .broken: "In and out of it all night."
        case .okay: "Not bad, not restorative."
        case .solid: "Slept through most of it."
        case .deep: "Woke up genuinely rested."
        }
    }

    /// Recovers the quality from a stored reading's tags.
    static func from(tags: [String]) -> SleepQuality? {
        allCases.first { tags.contains($0.tag) }
    }
}

/// What she thinks she has in her today, logged before the day spends it.
///
/// Five steps rather than a 0–10 slider: a forecast is a guess, and a guess
/// doesn't deserve one-decimal precision. The values land on the same 0–10
/// scale everything else uses, so the short flow and the full one agree.
nonisolated enum EnergyOutlook: Int, CaseIterable, Identifiable, Hashable {
    case empty = 1, low, some, steady, full

    var id: Int { rawValue }

    /// The 0–10 value stored on the energy reading.
    var value: Double { Double(rawValue) * 2 - 1 }

    var title: String {
        switch self {
        case .empty: "Running on empty"
        case .low: "Low"
        case .some: "Some"
        case .steady: "Steady"
        case .full: "Full tank"
        }
    }

    var caption: String {
        switch self {
        case .empty: "Today is about getting through it. That's a legitimate plan."
        case .low: "Enough for the essentials, not much beyond them."
        case .some: "Somewhere in the middle — a normal amount of yourself."
        case .steady: "Enough to do the day and still have something left."
        case .full: "One of the good ones. Worth noticing those too."
        }
    }

    /// Tagged on the reading so evening can tell a forecast from a result.
    var tag: String { "Expected \(title.lowercased())" }

    static func nearest(to value: Double) -> EnergyOutlook {
        allCases.min { abs($0.value - value) < abs($1.value - value) } ?? .some
    }
}

/// A short morning check-in: the night, and the day she expects to have.
nonisolated struct MorningCheckIn: Hashable {
    var sleepHours: Double
    var quality: SleepQuality
    var outlook: EnergyOutlook

    /// Hours rounded to the quarter the slider actually offers.
    var roundedHours: Double { (sleepHours * 4).rounded() / 4 }

    /// The two readings this check-in writes into the daily log.
    var readings: [SignalReading] {
        [
            SignalReading(
                category: .sleep,
                value: roundedHours,
                tags: [quality.tag],
                source: .manual,
                period: .morning
            ),
            SignalReading(
                category: .energy,
                value: outlook.value,
                tags: [outlook.tag],
                source: .manual,
                period: .morning
            )
        ]
    }

    var sleepDisplay: String { MorningCheckIn.hoursLabel(roundedHours) }

    static func hoursLabel(_ value: Double) -> String {
        let hours = Int(value)
        let minutes = Int(((value - Double(hours)) * 60).rounded())
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(String(format: "%02d", minutes))m"
    }
}
