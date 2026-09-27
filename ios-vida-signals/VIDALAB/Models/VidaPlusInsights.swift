import Foundation

/// The three Vida+ AI tools the website offers, now in the app: Body Weather,
/// the Vida Differential, and the Appointment Concierge.
///
/// Check-ins are encrypted on this device, so the server can't read them.
/// Each request carries a summary built here instead, limited to daily scores
/// and tags from the member's own check-ins. Notes, meals, medications,
/// Apple Health imports, and sample data are never included.
nonisolated enum InsightFeature: String, CaseIterable, Identifiable, Sendable, Codable {
    case bodyWeather = "body_weather"
    case differential
    case concierge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bodyWeather: "Body Weather"
        case .differential: "The Vida Differential"
        case .concierge: "Appointment Concierge"
        }
    }

    var tagline: String {
        switch self {
        case .bodyWeather: "A 7-day look ahead at your energy, mood, and harder days"
        case .differential: "Conditions your patterns may be worth exploring with a doctor"
        case .concierge: "Prepare for a visit, find a doctor near you, and request an appointment"
        }
    }

    var symbol: String {
        switch self {
        case .bodyWeather: "cloud.sun"
        case .differential: "list.bullet.clipboard"
        case .concierge: "stethoscope"
        }
    }

    /// Mirrors the server's minimum, so the screen can say so before asking.
    var minimumDays: Int {
        switch self {
        case .bodyWeather, .differential: 7
        case .concierge: 3
        }
    }
}

// MARK: - Request

nonisolated struct InsightDay: Codable, Equatable, Sendable {
    let date: String
    let scores: [String: Double]
    let tags: [String]
}

nonisolated struct InsightContext: Codable, Equatable, Sendable {
    var focusAreas: [String]
    var conditions: [String]
    var tracksCycle: Bool
    var visitReason: String
    var conditionName: String
}

nonisolated struct InsightRequest: Codable, Equatable, Sendable {
    let feature: InsightFeature
    let today: String
    let checkIns: [InsightDay]
    let context: InsightContext

    /// How many days of history go up. Matches the website's 90-day window.
    static let dayLimit = 90

    static func dayString(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The member's own check-ins as scores and tags. Pure, for testing.
    static func days(from logs: [DayLog], calendar: Calendar = .current) -> [InsightDay] {
        FirstWeekGuide.memberLogs(logs)
            .sorted { $0.date < $1.date }
            .suffix(dayLimit)
            .compactMap { log in
                var scores: [String: Double] = [:]
                for category in log.loggedCategories {
                    if let reading = log.reading(for: category) {
                        scores[category.rawValue] = (reading.value * 10).rounded() / 10
                    }
                }
                var seen = Set<String>()
                let tags = log.readings.flatMap(\.tags).filter { seen.insert($0.lowercased()).inserted }
                guard !scores.isEmpty || !tags.isEmpty else { return nil }
                return InsightDay(date: dayString(log.date, calendar: calendar), scores: scores, tags: Array(tags.prefix(15)))
            }
    }
}

// MARK: - Results

nonisolated struct BodyWeatherResult: Codable, Equatable, Sendable {
    struct Day: Codable, Equatable, Sendable, Identifiable {
        let day: String
        let date: String
        let energy: String
        let mood: String
        let riskLevel: String
        let riskAreas: [String]
        let headline: String
        let why: String
        let actions: [String]

        var id: String { date + day }

        enum CodingKeys: String, CodingKey {
            case day, date, energy, mood, headline, why, actions
            case riskLevel = "risk_level"
            case riskAreas = "risk_areas"
        }
    }

    let summary: String
    let patterns: [String]
    let forecast: [Day]
    let topTriggers: [String]
    let weeklyActions: [String]
    let disclaimer: String

    enum CodingKeys: String, CodingKey {
        case summary, patterns, forecast, disclaimer
        case topTriggers = "top_triggers"
        case weeklyActions = "weekly_actions"
    }
}

nonisolated struct DifferentialResult: Codable, Equatable, Sendable {
    struct Candidate: Codable, Equatable, Sendable, Identifiable {
        let condition: String
        let matchStrength: String
        let why: String
        let testsToConsider: [String]
        let specialists: [String]
        let redFlags: [String]

        var id: String { condition }

        enum CodingKeys: String, CodingKey {
            case condition, why, specialists
            case matchStrength = "match_strength"
            case testsToConsider = "tests_to_consider"
            case redFlags = "red_flags"
        }
    }

    let summary: String
    let patterns: [String]
    let differentials: [Candidate]
    let advocacyNotes: [String]
    let nextSteps: [String]
    let disclaimer: String

    enum CodingKeys: String, CodingKey {
        case summary, patterns, differentials, disclaimer
        case advocacyNotes = "advocacy_notes"
        case nextSteps = "next_steps"
    }
}

nonisolated struct ConciergeResult: Codable, Equatable, Sendable {
    struct Metric: Codable, Equatable, Sendable, Identifiable {
        let label: String
        let value: String
        let context: String

        var id: String { label + value }
    }

    let visitSummary: String
    let symptomNarrative: String
    let keyMetrics: [Metric]
    let questionsToAsk: [String]
    let testsToRequest: [String]
    let advocacyScript: String
    let whatToBring: [String]
    /// Kinds of specialist worth seeing, for the "find one near you" step.
    /// Optional so results saved before it existed still decode.
    let specialistsToSee: [String]?
    let disclaimer: String

    enum CodingKeys: String, CodingKey {
        case disclaimer
        case specialistsToSee = "specialists_to_see"
        case visitSummary = "visit_summary"
        case symptomNarrative = "symptom_narrative"
        case keyMetrics = "key_metrics"
        case questionsToAsk = "questions_to_ask"
        case testsToRequest = "tests_to_request"
        case advocacyScript = "advocacy_script"
        case whatToBring = "what_to_bring"
    }
}

/// A generated result, whichever feature produced it.
nonisolated enum InsightResult: Equatable, Sendable {
    case bodyWeather(BodyWeatherResult)
    case differential(DifferentialResult)
    case concierge(ConciergeResult)
}

/// What the server said, in the shape the screen needs.
nonisolated enum InsightOutcome: Equatable, Sendable {
    case ready(InsightResult, generatedAt: Date)
    /// Not enough check-ins yet, or Claude declined. The message is for display.
    case notice(String)
    case needsPlus
    case failed(String)
}

/// The server's JSON envelope. `result` is decoded per feature.
nonisolated struct InsightEnvelope<Result: Decodable>: Decodable {
    let status: String?
    let message: String?
    let error: String?
    let result: Result?
    /// ISO 8601 with fractional seconds; parsed by the service.
    let generatedAt: String?
}
