import Foundation

/// Vida asks twice a day, because the two halves of a day answer different
/// questions. Morning captures what the night did to you — sleep, waking pain,
/// starting energy. Evening captures what the day did to you — how it went,
/// what you ate, what it cost. Asking once forces a whole day into a single
/// average and loses the shape entirely.
nonisolated enum CheckInPeriod: String, CaseIterable, Codable, Identifiable, Hashable {
    case morning, evening

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: "Morning"
        case .evening: "Evening"
        }
    }

    var symbol: String {
        switch self {
        case .morning: "sunrise"
        case .evening: "moon.stars"
        }
    }

    /// Headline shown at the top of the flow.
    var headline: String {
        switch self {
        case .morning: "How did you\nwake up?"
        case .evening: "How did the\nday go?"
        }
    }

    var caption: String {
        switch self {
        case .morning: "What the night left you with."
        case .evening: "What the day cost you."
        }
    }

    /// Signals this half of the day is actually able to answer.
    var categories: [SignalCategory] {
        switch self {
        case .morning:
            [.sleep, .energy, .mood, .pain, .headache, .cycle]
        case .evening:
            [.energy, .mood, .pain, .headache, .digestion, .stress,
             .movement, .nutrition, .focus, .skin, .cycle]
        }
    }

    /// Prompt wording adjusted for the time of day — "how much energy do you
    /// have" and "how much energy did you have" are different questions.
    func prompt(for category: SignalCategory) -> String {
        switch (self, category) {
        case (.morning, .energy): "How much energy did you wake up with?"
        case (.morning, .mood): "How does your mood feel this morning?"
        case (.morning, .pain): "How much pain did you wake with?"
        case (.morning, .headache): "Any head pain on waking?"
        case (.morning, .cycle): "Bleeding or spotting this morning?"
        case (.evening, .energy): "How much energy did you have today?"
        case (.evening, .mood): "How steady was your mood today?"
        case (.evening, .pain): "How much pain did today bring?"
        case (.evening, .headache): "How intense was your head pain?"
        case (.evening, .focus): "How clear was your thinking today?"
        case (.evening, .movement): "How much did you move today?"
        case (.evening, .nutrition): "How nourished do you feel?"
        case (.evening, .stress): "How much pressure were you under?"
        case (.evening, .digestion): "How was your gut today?"
        default: category.prompt
        }
    }

    /// Which period the current hour belongs to. The boundary is generous on
    /// both sides: someone with chronic fatigue may not be upright until 2pm,
    /// and "morning" should still mean something for her.
    static func current(at date: Date = .now) -> CheckInPeriod {
        Calendar.current.component(.hour, from: date) < 14 ? .morning : .evening
    }

    var greeting: String {
        switch self {
        case .morning: "Good morning"
        case .evening: "Good evening"
        }
    }
}
