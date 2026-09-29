import SwiftUI

/// The ten body areas Vida listens to.
nonisolated enum SignalCategory: String, CaseIterable, Codable, Identifiable, Hashable {
    case cycle, sleep, energy, mood, pain, headache, digestion, skin, focus, movement, nutrition, stress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cycle: "Cycle"
        case .sleep: "Sleep"
        case .energy: "Energy"
        case .mood: "Mood"
        case .pain: "Pain"
        case .headache: "Headaches"
        case .digestion: "Digestion"
        case .skin: "Skin"
        case .focus: "Focus"
        case .movement: "Movement"
        case .nutrition: "Nutrition"
        case .stress: "Stress"
        }
    }

    var symbol: String {
        switch self {
        case .cycle: "moon.stars"
        case .sleep: "bed.double"
        case .energy: "bolt"
        case .mood: "cloud.sun"
        case .pain: "waveform.path"
        case .headache: "brain.head.profile"
        case .digestion: "circle.hexagongrid"
        case .skin: "sparkles"
        case .focus: "scope"
        case .movement: "figure.walk"
        case .nutrition: "leaf"
        case .stress: "wind"
        }
    }

    /// Short prompt shown on the check-in card.
    var prompt: String {
        switch self {
        case .cycle: "Bleeding or spotting today?"
        case .sleep: "How many hours did you sleep?"
        case .energy: "How much energy do you have?"
        case .mood: "How steady does your mood feel?"
        case .pain: "How much pain are you in?"
        case .headache: "How intense is your head pain?"
        case .digestion: "How is your gut feeling?"
        case .skin: "How is your skin today?"
        case .focus: "How clear is your thinking?"
        case .movement: "How much did you move?"
        case .nutrition: "How nourished do you feel?"
        case .stress: "How much pressure are you under?"
        }
    }

    /// Whether a high value is a good thing. Used for phrasing, never for judgement.
    var higherIsBetter: Bool {
        switch self {
        case .energy, .mood, .focus, .movement, .nutrition, .sleep, .skin, .digestion: true
        case .pain, .headache, .stress, .cycle: false
        }
    }

    var unitLabel: String {
        self == .sleep ? "hours" : "0–10"
    }

    var accent: Color {
        switch self {
        case .cycle: Vida.blush
        case .sleep: Vida.skyDeep
        case .energy: Vida.moss
        case .mood: Vida.sky
        case .pain: Vida.taupe
        case .headache: Vida.forest
        case .digestion: Vida.sage
        case .skin: Vida.blush
        case .focus: Vida.skyDeep
        case .movement: Vida.moss
        case .nutrition: Vida.sage
        case .stress: Vida.taupe
        }
    }

    /// The categories offered on the daily check-in grid.
    static let checkInSet: [SignalCategory] = [
        .cycle, .sleep, .energy, .mood, .pain, .headache,
        .digestion, .skin, .focus, .movement, .nutrition, .stress
    ]

    /// Follow-up questions Vida asks after a category is rated.
    var followUps: [FollowUpQuestion] {
        switch self {
        case .headache:
            [
                .init(prompt: "Where is it?", options: ["Forehead", "Temples", "One side", "Behind eyes", "Back of head"]),
                .init(prompt: "Anything else with it?", options: ["Nausea", "Light sensitivity", "Dizziness", "Aura", "None"]),
                .init(prompt: "When did it start?", options: ["On waking", "Morning", "Afternoon", "Evening", "Overnight"])
            ]
        case .pain:
            [
                .init(prompt: "Where is it?", options: ["Pelvis", "Lower back", "Abdomen", "Legs", "Chest", "Joints"]),
                .init(prompt: "What does it feel like?", options: ["Cramping", "Stabbing", "Dull ache", "Burning", "Pressure"]),
                .init(prompt: "Did it affect your day?", options: ["Missed school", "Left early", "Cancelled plans", "Pushed through", "No impact"])
            ]
        case .cycle:
            [
                .init(prompt: "Flow", options: ["Spotting", "Light", "Medium", "Heavy", "None"]),
                .init(prompt: "Anything with it?", options: ["Cramps", "Clots", "Back pain", "Bloating", "Breast tenderness"])
            ]
        case .mood:
            [
                .init(prompt: "Closest to how you feel?", options: ["Anxious", "Low", "Irritable", "Steady", "Bright", "Numb"]),
                .init(prompt: "Anything unusual today?", options: ["Conflict", "Exam or deadline", "Big news", "Alone time", "Nothing notable"])
            ]
        case .sleep:
            [
                .init(prompt: "How did you sleep?", options: ["Woke often", "Trouble falling asleep", "Slept through", "Woke early", "Restless"]),
                .init(prompt: "Before bed you…", options: ["Screens late", "Caffeine after 4pm", "Wound down", "Studied late", "Exercised"])
            ]
        case .digestion:
            [
                .init(prompt: "What are you noticing?", options: ["Bloating", "Cramping", "Constipation", "Loose stools", "Nausea", "Nothing off"])
            ]
        case .nutrition:
            [
                .init(prompt: "Today you had…", options: ["Skipped a meal", "Ate regularly", "Low protein", "Lots of sugar", "Well hydrated", "Low water"])
            ]
        case .movement:
            [
                .init(prompt: "What kind?", options: ["Walking", "Strength", "Running", "Team sport", "Yoga or stretching", "Rest day"])
            ]
        case .stress:
            [
                .init(prompt: "Where is it coming from?", options: ["Work", "School", "Family", "Friends", "Money", "Body stuff", "Future", "Not sure"])
            ]
        case .focus:
            [
                .init(prompt: "What felt hardest?", options: ["Starting", "Staying with it", "Remembering", "Reading", "Nothing, felt clear"])
            ]
        case .skin:
            [
                .init(prompt: "What are you seeing?", options: ["Breakouts on jaw", "Oily", "Dry", "Sensitive", "Clear"])
            ]
        case .energy:
            [
                .init(prompt: "When was it lowest?", options: ["On waking", "Mid-morning", "Afternoon", "Evening", "All day"])
            ]
        }
    }
}

nonisolated struct FollowUpQuestion: Identifiable, Hashable {
    let id = UUID()
    let prompt: String
    let options: [String]
}
