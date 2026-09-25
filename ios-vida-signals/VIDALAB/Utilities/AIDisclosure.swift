import Foundation

/// The one-time permission shown before Ask Vida sends anything to an AI model.
///
/// App Review guideline 5.1.2(i) requires telling people where their personal
/// data goes, naming third-party AI explicitly, and getting permission before
/// the first share. A typed health question is personal data, so it can't be
/// sent on the strength of a label printed underneath the answer afterwards.
///
/// The same stored flag backs the toggle in Settings, which is how permission
/// is withdrawn: with it off, a question the cited library can't answer gets
/// the library's own "no match" response instead of an AI call.
nonisolated enum AIDisclosure {
    static let acceptedKey = "vida.ai.disclosure.accepted.v1"

    /// Who processes the question. Keep this accurate: the disclosure is only
    /// worth anything if it names the service the `ask-vida` function actually
    /// calls. Confirmed 2026-09-25: the deployed `ask-vida` Edge Function sends
    /// the question to OpenAI's Responses API (api.openai.com). If the function
    /// ever switches providers, change this line in the same release.
    static let providerDescription = "OpenAI, a third-party AI provider"

    static let title = "Send this question to AI?"

    static var message: String {
        "Vida's cited library doesn't have an answer for this. To write one, VIDA LAB sends the question you typed to \(providerDescription). "
            + "Your check-ins, meals, and Apple Health data aren't included unless you've turned on the approved health summary in Settings. "
            + "VIDA LAB never uses what you send for advertising. You can turn this off at any time in Settings."
    }
}
