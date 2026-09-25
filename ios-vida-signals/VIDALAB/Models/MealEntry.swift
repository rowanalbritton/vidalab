import Foundation

nonisolated enum MealKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snack: "Snack"
        }
    }

    var symbol: String {
        switch self {
        case .breakfast: "sunrise"
        case .lunch: "sun.max"
        case .dinner: "moon"
        case .snack: "leaf"
        }
    }

    /// A reasonable guess from the clock, so logging lunch at one o'clock
    /// takes one tap fewer than it otherwise would.
    static func likely(at date: Date = .now, calendar: Calendar = .current) -> MealKind {
        switch calendar.component(.hour, from: date) {
        case 0..<11: .breakfast
        case 11..<15: .lunch
        case 15..<21: .dinner
        default: .snack
        }
    }
}

/// One thing eaten.
///
/// Deliberately not a nutrition tracker. Vida doesn't want calories or
/// macros — it wants a name it can count, so "the weeks you ate porridge you
/// slept better" becomes answerable. Asking for grams would get the field
/// abandoned inside a week, and would turn a symptom app into a diet app for
/// an audience that frequently has a complicated history with those.
nonisolated struct MealEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var date: Date
    var kind: MealKind
    var name: String
    var note: String
    /// Optional 0–10: how it sat afterwards. The one number worth asking for,
    /// because it is the bridge to the digestion signal.
    var howItSat: Int?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        kind: MealKind? = nil,
        name: String,
        note: String = "",
        howItSat: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.kind = kind ?? MealKind.likely(at: date)
        self.name = name
        self.note = note
        self.howItSat = howItSat
    }

    /// The key meals are grouped by when counting favourites.
    ///
    /// Case and punctuation are dropped so "Porridge", "porridge" and
    /// "porridge!" are one meal rather than three — otherwise the favourites
    /// list is just a record of how consistently someone types.
    var groupingKey: String {
        name
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

/// A meal someone ate often enough to be worth naming back to them.
nonisolated struct MealTally: Identifiable, Hashable, Sendable {
    /// The spelling the member used most often, not the normalised key —
    /// reading "porridge and berries" back is warmer than "porridge berries".
    let name: String
    let count: Int
    /// Average of `howItSat`, when they said. Nil when they never did.
    let averageComfort: Double?

    var id: String { name }
}

nonisolated enum MealInsights {
    /// Most-logged meals, most frequent first.
    ///
    /// Ties break alphabetically rather than by insertion order, so the same
    /// month always produces the same list — a recap that reshuffles itself
    /// between openings looks broken.
    static func favourites(in meals: [MealEntry], limit: Int = 5) -> [MealTally] {
        guard !meals.isEmpty else { return [] }

        var groups: [String: [MealEntry]] = [:]
        for meal in meals {
            let key = meal.groupingKey
            guard !key.isEmpty else { continue }
            groups[key, default: []].append(meal)
        }

        return groups
            .map { _, entries in
                MealTally(
                    name: mostCommonSpelling(in: entries),
                    count: entries.count,
                    averageComfort: averageComfort(in: entries)
                )
            }
            .sorted {
                $0.count == $1.count
                    ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    : $0.count > $1.count
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func mostCommonSpelling(in entries: [MealEntry]) -> String {
        var counts: [String: Int] = [:]
        for entry in entries {
            let trimmed = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            counts[trimmed, default: 0] += 1
        }
        return counts
            .sorted {
                $0.value == $1.value
                    ? $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
                    : $0.value > $1.value
            }
            .first?.key
            ?? entries.first?.name
            ?? ""
    }

    private static func averageComfort(in entries: [MealEntry]) -> Double? {
        let rated = entries.compactMap(\.howItSat)
        guard !rated.isEmpty else { return nil }
        return Double(rated.reduce(0, +)) / Double(rated.count)
    }
}
