import Foundation

// Vida+ meditation: breathing guides, guided sessions read from the Vida
// Apothecary's meditation scripts, and an unguided timer. Like Oura's
// sessions, each one can show its effect, here as a quick before-and-after
// stress check rather than a heart-rate reading.

/// A paced breathing pattern. Durations are in seconds; a zero phase is skipped.
nonisolated struct BreathPattern: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let summary: String
    let inhale: Double
    let holdIn: Double
    let exhale: Double
    let holdOut: Double
    /// A second, short inhale right after the first, for the physiological sigh.
    let topUp: Double
    /// Part of Vida+. The two simplest patterns are free for everyone.
    var isPremium: Bool = false

    var cycleSeconds: Double { inhale + topUp + holdIn + exhale + holdOut }

    static let all: [BreathPattern] = [
        BreathPattern(id: "resonant", title: "Resonant breathing", summary: "Slow, even breaths, about five and a half a minute. Steadying at any time of day.", inhale: 5.5, holdIn: 0, exhale: 5.5, holdOut: 0, topUp: 0),
        BreathPattern(id: "box", title: "Box breathing", summary: "In, hold, out, hold, four counts each. Useful before something stressful.", inhale: 4, holdIn: 4, exhale: 4, holdOut: 4, topUp: 0, isPremium: true),
        BreathPattern(id: "478", title: "4-7-8 breathing", summary: "A long hold and longer exhale that many people use to wind down for sleep.", inhale: 4, holdIn: 7, exhale: 8, holdOut: 0, topUp: 0, isPremium: true),
        BreathPattern(id: "sigh", title: "Physiological sigh", summary: "Two inhales through the nose, then a long exhale. A quick reset when you feel wound up.", inhale: 2, holdIn: 0, exhale: 6, holdOut: 0, topUp: 1),
    ]

    static func find(_ id: String) -> BreathPattern? { all.first { $0.id == id } }

    /// "In 4 · hold 7 · out 8", in whole or half seconds.
    var rhythm: String {
        func seconds(_ value: Double) -> String {
            value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
        }
        var parts = ["in \(seconds(inhale))"]
        if topUp > 0 { parts.append("in \(seconds(topUp))") }
        if holdIn > 0 { parts.append("hold \(seconds(holdIn))") }
        parts.append("out \(seconds(exhale))")
        if holdOut > 0 { parts.append("hold \(seconds(holdOut))") }
        let joined = parts.joined(separator: " · ")
        return joined.prefix(1).uppercased() + joined.dropFirst()
    }

    enum Phase: String, Sendable {
        case inhale = "Breathe in"
        case topUp = "In again"
        case holdIn = "Hold"
        case exhale = "Breathe out"
        case holdOut = "Hold empty"
    }

    /// The phases of one cycle, in order, skipping any of zero length.
    var phases: [(phase: Phase, seconds: Double)] {
        [(.inhale, inhale), (.topUp, topUp), (.holdIn, holdIn), (.exhale, exhale), (.holdOut, holdOut)]
            .filter { $0.1 > 0 }
    }

    /// Full cycles that fit in `minutes`, at least one.
    func cycles(forMinutes minutes: Int) -> Int {
        max(1, Int((Double(minutes) * 60 / cycleSeconds).rounded()))
    }
}

/// What's free and what's Vida+. The quiet timer, two breathing patterns, and
/// the first few guided sessions are open to everyone, so anyone can find out
/// whether meditating helps them before paying for it.
nonisolated enum MeditationAccess {
    static let freeGuidedCount = 3

    /// Guided sessions arrive in the Apothecary's own order; the first few are free.
    static func isGuidedFree(_ id: String, in ordered: [String]) -> Bool {
        guard let position = ordered.firstIndex(of: id) else { return false }
        return position < freeGuidedCount
    }
}

/// The part of the day, used to suggest a session that fits it.
nonisolated enum MeditationMoment: String, Equatable, Sendable {
    case morning, midday, evening, night

    static func at(_ date: Date, calendar: Calendar = .current) -> MeditationMoment {
        switch calendar.component(.hour, from: date) {
        case 5..<11: .morning
        case 11..<17: .midday
        case 17..<21: .evening
        default: .night
        }
    }

    var title: String {
        switch self {
        case .morning: "Start the day steady"
        case .midday: "A reset for the middle of the day"
        case .evening: "Let the day settle"
        case .night: "Ease toward sleep"
        }
    }

    /// The breathing pattern that suits this time, and a free one to fall back
    /// on without Vida+.
    func breathPattern(isPlus: Bool) -> BreathPattern? {
        let preferred: String = switch self {
        case .morning, .evening: "resonant"
        case .midday: "sigh"
        case .night: "478"
        }
        guard let pattern = BreathPattern.find(preferred) else { return nil }
        if pattern.isPremium && !isPlus { return BreathPattern.find("resonant") }
        return pattern
    }

    /// The guided shelf that suits this time.
    var guidedSubcategory: String {
        switch self {
        case .morning: "morning"
        case .midday: "mindfulness"
        case .evening: "body-scan"
        case .night: "sleep"
        }
    }
}

nonisolated enum MeditationKind: String, Codable, Sendable {
    case breathing, guided, timer
}

/// One finished session, kept on this device.
nonisolated struct MeditationSession: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    let date: Date
    let kind: MeditationKind
    let title: String
    let seconds: Int
    /// 0 (calm) to 10 (very stressed), when she answered.
    var stressBefore: Int?
    var stressAfter: Int?

    var stressChange: Int? {
        guard let stressBefore, let stressAfter else { return nil }
        return stressAfter - stressBefore
    }
}

nonisolated struct MeditationStats: Equatable, Sendable {
    let minutesThisWeek: Int
    let sessionsThisWeek: Int
    /// Consecutive days with a session, ending today or yesterday.
    let streakDays: Int
    /// Average after-minus-before stress across sessions with both answers.
    let averageStressChange: Double?

    static func from(_ sessions: [MeditationSession], now: Date = .now, calendar: Calendar = .current) -> MeditationStats {
        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        let thisWeek = sessions.filter { week?.contains($0.date) ?? false }
        let minutes = thisWeek.reduce(0) { $0 + $1.seconds } / 60

        let days = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor), let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) {
            cursor = yesterday
        }
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        let changes = sessions.compactMap(\.stressChange)
        let average = changes.isEmpty ? nil : Double(changes.reduce(0, +)) / Double(changes.count)
        return MeditationStats(minutesThisWeek: minutes, sessionsThisWeek: thisWeek.count, streakDays: streak, averageStressChange: average)
    }
}

/// A guided session built from one of the Apothecary's meditation scripts.
///
/// The scripts are short step lists meant to be read and then practiced, so a
/// 15-minute body scan is only a minute of reading. The session speaks one
/// step at a time and leaves quiet time after each, spreading the steps across
/// the length the script names, the way recorded meditations are paced.
nonisolated struct GuidedScript: Equatable, Sendable {
    struct Segment: Equatable, Sendable {
        let text: String
        /// Quiet time after the segment is spoken.
        let pauseSeconds: Double
    }

    let title: String
    let segments: [Segment]
    /// Shown before starting, never read aloud.
    let tip: String?

    static let closing = "When you're ready, let your breath return to its own rhythm, and gently come back to the room."

    /// Rough speaking time for a slow, calm voice.
    static func speakingSeconds(_ text: String) -> Double {
        Double(text.split(whereSeparator: \.isWhitespace).count) / 2.2
    }

    static func make(title: String, content: String, minutes: Int) -> GuidedScript {
        var spoken: [String] = []
        var tip: String?
        for block in MarkdownBlocks.blocks(from: content) {
            let raw: String
            switch block {
            case .heading(let text): raw = text
            case .bullet(_, let text): raw = text
            case .paragraph(let text): raw = text
            }
            let plain = plainText(raw)
            guard !plain.isEmpty else { continue }
            if plain.lowercased().hasPrefix("tip:") {
                tip = String(plain.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                continue
            }
            spoken.append(plain)
        }
        spoken.append(closing)

        let total = Double(max(1, minutes)) * 60
        let speaking = spoken.reduce(0) { $0 + speakingSeconds($1) }
        // Silence is shared between every step but the closing line.
        let gaps = max(1, spoken.count - 1)
        let pause = max(6, (total - speaking) / Double(gaps))
        let segments = spoken.enumerated().map { index, text in
            Segment(text: text, pauseSeconds: index == spoken.count - 1 ? 0 : pause)
        }
        return GuidedScript(title: title, segments: segments, tip: tip)
    }

    var totalSeconds: Double {
        segments.reduce(0) { $0 + Self.speakingSeconds($1.text) + $1.pauseSeconds }
    }

    /// Removes Markdown emphasis and link syntax so the voice doesn't read it.
    static func plainText(_ text: String) -> String {
        var result = text
        // [label](url) -> label
        result = result.replacing(/\[([^\]]+)\]\([^)]*\)/) { String($0.1) }
        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(of: "__", with: "")
        result = result.replacingOccurrences(of: "*", with: "")
        result = result.replacingOccurrences(of: "`", with: "")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Scripts that are really a breathing pattern play better as one.
    static func breathPattern(forTitle title: String) -> BreathPattern? {
        let lowered = title.lowercased()
        if lowered.contains("4-7-8") { return .find("478") }
        if lowered.contains("box breathing") { return .find("box") }
        if lowered.contains("resonant") || lowered.contains("coherent") { return .find("resonant") }
        if lowered.contains("sigh") { return .find("sigh") }
        return nil
    }
}
