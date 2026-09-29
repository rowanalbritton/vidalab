import Foundation

/// The Appointment Concierge: turns a saved Doctor Prep into the two things
/// people most often wish they had in the room, a short account of the
/// problem in their own voice and calm words for the moment they feel
/// brushed off.
///
/// Everything is assembled on the phone from her own answers. Nothing here
/// suggests a diagnosis; the script asks for things any patient may
/// reasonably ask for (documentation, a referral, a follow-up plan).
enum AppointmentConcierge {
    struct ScriptLine: Hashable {
        /// What she might hear.
        let ifYouHear: String
        /// What she can say back.
        let youCanSay: String

        /// The lead-in line. A quote reads "If you hear "…"", and a situation
        /// reads "If a test or referral isn't offered.", so neither turns
        /// into "If you hear A test…".
        func lead(hearer: String = "you") -> String {
            if ifYouHear.hasPrefix("\"") { return "If \(hearer) hear \(ifYouHear)" }
            guard let first = ifYouHear.first else { return ifYouHear }
            return "If " + first.lowercased() + ifYouHear.dropFirst()
        }
    }

    // MARK: - Narrative

    /// About thirty seconds of speech: what it is, how long, how often, how
    /// bad, what comes with it, what it costs her, and what she has tried.
    static func narrative(for prep: DoctorPrep) -> String {
        var sentences: [String] = []

        let concern = prep.concern == "Something else" ? "a health problem" : prep.concern.lowercased()
        sentences.append("I've been dealing with \(concern) \(onsetPhrase(prep.onset)).")

        let often = frequencyPhrase(prep.frequency)
        sentences.append("It happens \(often), usually around \(prep.typicalSeverity) out of 10, and at its worst it reaches \(prep.worstSeverity) out of 10.")

        let symptoms = prep.associatedSymptoms.map { $0.lowercased() }
        if !symptoms.isEmpty {
            sentences.append("It often comes with \(list(symptoms)).")
        }

        let impact = prep.impact.filter { $0 != "Pushed through" }.map { impactPhrase($0) }
        if !impact.isEmpty {
            sentences.append("Because of it I have \(list(impact)).")
        }
        if prep.impact.contains("Pushed through") {
            sentences.append("Most of the time I push through it, so it may look milder from the outside than it feels.")
        }

        let tried = prep.triedAlready.filter { $0 != "Nothing yet" }.map { $0.lowercased() }
        if !tried.isEmpty {
            sentences.append("I've already tried \(list(tried)), and it hasn't been enough.")
        }

        sentences.append("I'd like help understanding what's driving it and what we can do next.")
        return sentences.joined(separator: " ")
    }

    // MARK: - Advocacy script

    static func script(for prep: DoctorPrep) -> [ScriptLine] {
        var lines: [ScriptLine] = [
            ScriptLine(
                ifYouHear: "\"That's normal\" or \"It's probably stress.\"",
                youCanSay: "I understand that's common, but this is affecting my daily life at \(prep.worstSeverity) out of 10 at its worst. What would we look for to rule other causes out?"
            ),
            ScriptLine(
                ifYouHear: "\"Let's wait and see.\"",
                youCanSay: "I'm open to that. How long should we wait, what should I track in the meantime, and what would make you want to look further?"
            ),
            ScriptLine(
                ifYouHear: "A test or referral isn't offered.",
                youCanSay: "Could you note in my record that I asked about further testing or a specialist referral, and the reason we decided against it for now?"
            )
        ]
        if prep.impact.contains("Missed school or work") || prep.impact.contains("Left early") {
            lines.append(ScriptLine(
                ifYouHear: "The impact isn't discussed.",
                youCanSay: "It's the reason I've missed school or work. I'd like that written down, and I'd like a plan that helps me stay in the things I care about."
            ))
        }
        if prep.triedAlready.contains(where: { $0 != "Nothing yet" }) {
            lines.append(ScriptLine(
                ifYouHear: "A treatment I've already tried is suggested.",
                youCanSay: "I've tried \(prep.triedAlready.first { $0 != "Nothing yet" }!.lowercased()) already. What would be the next step after that?"
            ))
        }
        return lines
    }

    // MARK: - Plain text

    static func plainText(for prep: DoctorPrep) -> String {
        var lines = ["APPOINTMENT CONCIERGE", "", "In my own words:", narrative(for: prep), "", "If I feel brushed off:"]
        for line in script(for: prep) {
            lines.append("  " + line.lead(hearer: "I"))
            lines.append("  I can say: \(line.youCanSay)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Phrasing

    private static func onsetPhrase(_ onset: String) -> String {
        switch onset {
        case "Within the last month": "for the past few weeks"
        case "2–6 months ago": "for the past few months"
        case "6–12 months ago": "for most of this past year"
        case "Over a year ago": "for more than a year"
        case "As long as I can remember": "for as long as I can remember"
        default: onset.isEmpty ? "for a while now" : "since \(onset.lowercased())"
        }
    }

    private static func frequencyPhrase(_ frequency: String) -> String {
        switch frequency {
        case "Every day": "every day"
        case "Most days": "most days"
        case "Around my period only": "around my period"
        case "A few times a month": "a few times a month"
        case "Occasionally": "now and then"
        default: frequency.isEmpty ? "regularly" : frequency.lowercased()
        }
    }

    private static func impactPhrase(_ impact: String) -> String {
        switch impact {
        case "Missed school or work": "missed school or work"
        case "Left early": "had to leave early"
        case "Cancelled plans": "cancelled plans"
        case "Stopped a sport": "stopped a sport"
        case "Couldn't sleep": "lost sleep"
        case "Went to A&E or urgent care": "needed urgent care"
        default: impact.lowercased()
        }
    }

    private static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        case 2: "\(items[0]) and \(items[1])"
        default: items.dropLast().joined(separator: ", ") + ", and " + items.last!
        }
    }
}
