import Foundation

/// One diary entry: free writing about her life, on its own or as the last,
/// optional step of a check-in. Entries stay on this device.
nonisolated struct DiaryEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    /// The day the entry is about (local start of day).
    var date: Date
    var text: String
    /// Set when it was written at the end of a morning or evening check-in.
    var period: CheckInPeriod?
    /// The gentle prompt shown while writing, if one was used.
    var prompt: String?
    var createdAt: Date = .now
    var updatedAt: Date = .now

    static let limit = 20_000
}

/// Soft prompts for a blank page. Never questions about symptoms: the
/// check-in already asked those, and the diary is for the rest of life.
enum DiaryPrompts {
    static let all: [String] = [
        "What took up most of your mind today?",
        "Something small that went right.",
        "Who did you spend time with, and how did it feel?",
        "What would you tell yourself from this morning?",
        "Something you're looking forward to.",
        "What drained you today, and what refilled you?",
        "A moment you want to remember.",
        "What are you carrying that you could set down?",
        "Where did your body feel most at ease today?",
        "What's been on repeat: a song, a thought, a worry?"
    ]

    /// Same prompt all day, a new one tomorrow.
    static func forToday(_ date: Date = .now) -> String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[day % all.count]
    }

    static func forCheckIn(_ period: CheckInPeriod) -> String {
        switch period {
        case .morning: "Anything on your mind as the day starts?"
        case .evening: "Anything else about today you want to remember?"
        }
    }
}
