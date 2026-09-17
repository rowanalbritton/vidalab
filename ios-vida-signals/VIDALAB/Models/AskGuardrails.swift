import Foundation

/// What Vida is allowed to do with a given question.
///
/// Every question is classified before a single word of an answer is produced.
/// Three of the four outcomes are refusals of one kind or another, and that is
/// deliberate: a health app that guesses is worse than a health app that says
/// it doesn't know.
nonisolated enum AskOutcome: Equatable {
    /// Language suggesting a medical emergency. Guidance is shown above all else.
    case emergency(EmergencyGuidance)
    /// A diagnosis, medication or non-health request. Scripted redirect, never a guess.
    case outOfScope(ScopeRefusal)
    /// A cited answer from the library.
    case answer(VidaAnswer)
    /// In scope, but the library has nothing cited to say about it.
    case noMatch
}

/// Emergency guidance. Deliberately short and unhedged — this is the one place
/// in the app where Vida tells someone what to do.
nonisolated struct EmergencyGuidance: Equatable {
    let headline: String
    let body: String
    let action: String
}

/// A scripted refusal plus the thing Vida *can* usefully do instead. A refusal
/// without a next step is a dead end, which is its own kind of failure.
nonisolated struct ScopeRefusal: Equatable {
    let headline: String
    let body: String
    /// Questions from the library that are adjacent to what she actually asked.
    let alternatives: [String]
}

nonisolated enum AskGuardrails {

    // MARK: - Emergency

    /// Phrases that mean "stop answering questions and get help".
    ///
    /// Matched loosely and on purpose. A false positive costs someone a mildly
    /// irritating card; a false negative costs something that cannot be undone.
    private static let emergencyPhrases: [String] = [
        "chest pain", "can't breathe", "cant breathe", "trouble breathing",
        "struggling to breathe", "short of breath suddenly",
        "kill myself", "killing myself", "suicidal", "suicide", "end my life",
        "want to die", "hurt myself", "self harm", "self-harm",
        "overdose", "took too many", "poisoned",
        "soaking a pad", "soaking through", "bleeding through a pad",
        "haemorrhage", "hemorrhage", "won't stop bleeding", "wont stop bleeding",
        "passed out", "passing out", "fainted", "collapsed",
        "worst headache of my life", "sudden severe headache",
        "slurred speech", "face drooping", "numb on one side",
        "coughing up blood", "vomiting blood", "blood in my vomit",
        "severe abdominal pain", "can't stop vomiting", "cant stop vomiting",
        "emergency", "call 911", "999", "112"
    ]

    /// Mental-health crises get different wording than physical ones — being
    /// told to "go to A&E for a suspected clot" when you said you want to die is
    /// its own small cruelty.
    private static let crisisPhrases: [String] = [
        "kill myself", "killing myself", "suicidal", "suicide", "end my life",
        "want to die", "hurt myself", "self harm", "self-harm"
    ]

    static func emergency(in query: String) -> EmergencyGuidance? {
        let lower = normalized(query)
        guard emergencyPhrases.contains(where: { lower.contains($0) }) else { return nil }

        if crisisPhrases.contains(where: { lower.contains($0) }) {
            return EmergencyGuidance(
                headline: "Please talk to someone now",
                body: "What you're describing needs a person, not an app. If you're in immediate danger, call your local emergency number. In the US you can call or text 988 for the Suicide & Crisis Lifeline; in the UK call 116 123 for Samaritans. They are free, confidential, and open right now.",
                action: "You deserve support from someone who can actually help."
            )
        }

        return EmergencyGuidance(
            headline: "This needs urgent care, not an app",
            body: "The symptoms you've described can be signs of something that needs to be seen straight away. Call your local emergency number or go to an emergency department now. If it turns out to be nothing, that is a good outcome, not a wasted trip.",
            action: "Vida can't assess urgent symptoms and won't try."
        )
    }

    // MARK: - Out of scope

    /// "Do I have X" — a request for a diagnosis.
    private static let diagnosisPhrases: [String] = [
        "do i have", "do you think i have", "could i have", "might i have",
        "am i", "is this", "what's wrong with me", "whats wrong with me",
        "what do i have", "diagnose", "diagnosis", "is it cancer",
        "do i need surgery", "should i be worried"
    ]

    /// Requests for a drug, a dose, or permission to take something.
    private static let medicationPhrases: [String] = [
        "how much ibuprofen", "how much paracetamol", "how much tylenol",
        "how many mg", "what dose", "dosage", "should i take",
        "can i take", "is it safe to take", "stop taking", "come off",
        "which pill", "birth control should i", "prescribe", "antibiotic"
    ]

    static func scopeRefusal(for query: String) -> ScopeRefusal? {
        let lower = normalized(query)

        if medicationPhrases.contains(where: { lower.contains($0) }) {
            return ScopeRefusal(
                headline: "Vida won't advise on medication",
                body: "Doses, interactions and whether to start or stop something depend on your history, your other prescriptions and your kidneys and liver. Only a prescriber with your records can answer that safely, and a pharmacist can usually answer it today for free.",
                alternatives: alternatives(excluding: lower)
            )
        }

        if diagnosisPhrases.contains(where: { lower.contains($0) }) {
            return ScopeRefusal(
                headline: "Vida can't tell you what you have",
                body: "Naming a condition takes an examination, usually tests, and a clinician who can weigh everything together. Vida is built to do the part that's genuinely hard for a doctor to do in fifteen minutes: show them what your body has actually been doing over weeks.",
                alternatives: alternatives(excluding: lower)
            )
        }

        return nil
    }

    /// Three suggestions that aren't just a repeat of what she typed.
    private static func alternatives(excluding lower: String) -> [String] {
        Array(
            AskVidaLibrary.suggested
                .filter { !lower.contains($0.lowercased().prefix(12)) }
                .prefix(3)
        )
    }

    // MARK: - Classification

    /// Runs the whole ladder in priority order: emergency, then scope, then the
    /// cited library, then an honest "no".
    static func classify(_ query: String) -> AskOutcome {
        if let guidance = emergency(in: query) { return .emergency(guidance) }
        if let refusal = scopeRefusal(for: query) { return .outOfScope(refusal) }
        if let answer = AskVidaLibrary.citedMatch(for: query) { return .answer(answer) }
        return .noMatch
    }

    private static func normalized(_ query: String) -> String {
        query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Hard ceiling on a question, so the field stops accepting text rather than
    /// failing after she's typed three paragraphs.
    static let questionLimit: Int = 300
}
