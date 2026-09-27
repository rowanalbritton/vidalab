import Foundation

/// Body measurements read from Apple Health: what an Apple Watch, an Oura
/// Ring, or another wearable records overnight and through the day. Read on
/// demand to show trends, never stored in the journal or backed up, and never
/// sent anywhere.
nonisolated enum BodyMetricKind: String, CaseIterable, Identifiable, Sendable {
    case restingHeartRate
    case heartRateVariability
    case respiratoryRate
    case wristTemperature
    case oxygenSaturation
    case steps
    case activeEnergy
    case mindfulMinutes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .restingHeartRate: "Resting heart rate"
        case .heartRateVariability: "Heart rate variability"
        case .respiratoryRate: "Breathing rate"
        case .wristTemperature: "Overnight temperature"
        case .oxygenSaturation: "Blood oxygen"
        case .steps: "Steps"
        case .activeEnergy: "Active energy"
        case .mindfulMinutes: "Mindful minutes"
        }
    }

    var unit: String {
        switch self {
        case .restingHeartRate: "bpm"
        case .heartRateVariability: "ms"
        case .respiratoryRate: "breaths/min"
        case .wristTemperature: "°C"
        case .oxygenSaturation: "%"
        case .steps: "steps"
        case .activeEnergy: "kcal"
        case .mindfulMinutes: "min"
        }
    }

    var symbol: String {
        switch self {
        case .restingHeartRate: "heart"
        case .heartRateVariability: "waveform.path.ecg"
        case .respiratoryRate: "lungs"
        case .wristTemperature: "thermometer.medium"
        case .oxygenSaturation: "drop"
        case .steps: "figure.walk"
        case .activeEnergy: "flame"
        case .mindfulMinutes: "leaf"
        }
    }

    /// Where it usually comes from, for the empty state.
    var source: String {
        switch self {
        case .restingHeartRate, .heartRateVariability, .respiratoryRate: "Apple Watch, Oura Ring, and most wearables"
        case .wristTemperature: "Apple Watch Series 8 or later, and Oura Ring"
        case .oxygenSaturation: "Apple Watch Series 6 or later, and some rings"
        case .steps: "iPhone, Apple Watch, and most wearables"
        case .activeEnergy: "Apple Watch and most fitness wearables"
        case .mindfulMinutes: "Apple Watch Mindfulness, Oura sessions, and meditation apps"
        }
    }

    /// Daily totals rather than daily averages.
    var isCumulative: Bool {
        switch self {
        case .steps, .activeEnergy, .mindfulMinutes: true
        default: false
        }
    }

    /// How many decimals a value is shown with.
    var decimals: Int {
        switch self {
        case .respiratoryRate, .wristTemperature: 1
        default: 0
        }
    }

    /// A change smaller than this reads as "about your usual".
    var steadyThreshold: Double {
        switch self {
        case .restingHeartRate: 2
        case .heartRateVariability: 4
        case .respiratoryRate: 0.5
        case .wristTemperature: 0.3
        case .oxygenSaturation: 1
        case .steps: 1000
        case .activeEnergy: 60
        case .mindfulMinutes: 3
        }
    }

    func format(_ value: Double) -> String {
        if self == .steps || self == .activeEnergy {
            return value.formatted(.number.precision(.fractionLength(0)))
        }
        return value.formatted(.number.precision(.fractionLength(decimals)))
    }
}

nonisolated struct BodyMetricDay: Identifiable, Hashable, Sendable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// One metric over the last 30 days, with this week compared to her usual.
nonisolated struct BodyMetricSeries: Identifiable, Sendable {
    let kind: BodyMetricKind
    /// Oldest first.
    let days: [BodyMetricDay]

    var id: String { kind.id }
    var latest: BodyMetricDay? { days.last }

    /// The last 7 days (today and the six before it) against the rest.
    func comparison(now: Date = .now, calendar: Calendar = .current) -> BodyMetricComparison? {
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else { return nil }
        let recent = days.filter { $0.date >= weekStart }.map(\.value)
        let usual = days.filter { $0.date < weekStart }.map(\.value)
        guard recent.count >= 3, usual.count >= 5 else { return nil }
        let recentAverage = recent.reduce(0, +) / Double(recent.count)
        let usualAverage = usual.reduce(0, +) / Double(usual.count)
        return BodyMetricComparison(kind: kind, recent: recentAverage, usual: usualAverage)
    }
}

nonisolated struct BodyMetricComparison: Equatable, Sendable {
    let kind: BodyMetricKind
    let recent: Double
    let usual: Double

    var delta: Double { recent - usual }
    var isSteady: Bool { abs(delta) < kind.steadyThreshold }

    /// Plain, non-alarming wording. Describes the change and the common
    /// everyday reasons for it; never a diagnosis.
    var summary: String {
        let amount = "\(kind.format(abs(delta))) \(kind.unit)"
        if isSteady { return "About your usual this week." }
        let direction = delta > 0 ? "higher" : "lower"
        switch kind {
        case .restingHeartRate:
            return delta > 0
                ? "\(amount) higher than your usual this week. Short sleep, stress, alcohol, illness, and the days before a period can all nudge it up."
                : "\(amount) lower than your usual this week, often a sign of good recovery."
        case .heartRateVariability:
            return delta > 0
                ? "\(amount) higher than your usual this week, which often goes with better recovery."
                : "\(amount) lower than your usual this week. Stress, short sleep, hard training, or feeling unwell can all lower it for a while."
        case .wristTemperature:
            return "\(amount) \(direction) than your usual overnight. Temperature shifts across the menstrual cycle and when you're unwell."
        case .respiratoryRate:
            return "\(amount) \(direction) than your usual overnight."
        case .oxygenSaturation:
            return "\(amount) \(direction) than your usual. Readings vary with fit and movement; persistent low readings are worth raising with a doctor."
        case .steps, .activeEnergy, .mindfulMinutes:
            return "\(amount) a day \(direction) than your usual this week."
        }
    }
}
