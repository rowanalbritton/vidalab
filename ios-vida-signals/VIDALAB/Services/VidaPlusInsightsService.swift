import Foundation
import Supabase

/// Runs the Vida+ AI tools through the `vida-plus-insights` Edge Function and
/// keeps the last result for each on this device.
///
/// Every generation is a paid Claude call, so a result is kept until the member
/// asks for a fresh one. The cache is per account: a shared iPad must never
/// show one person's forecast to another.
nonisolated enum VidaPlusInsightsService {
    /// Sends the request and sorts the reply into what the screen can show.
    static func generate(_ request: InsightRequest) async -> InsightOutcome {
        do {
            return try await vidaSupabase.functions.invoke(
                "vida-plus-insights",
                options: FunctionInvokeOptions(body: request)
            ) { data, _ in
                try outcome(from: data, feature: request.feature)
            }
        } catch FunctionsError.httpError(let code, let data) {
            if code == 403 { return .needsPlus }
            let message = (try? JSONDecoder().decode(InsightEnvelope<EmptyResult>.self, from: data))?.error
            return .failed(message ?? "Vida couldn't answer just now. Please try again in a moment.")
        } catch is URLError {
            return .failed("You seem to be offline. Check your connection and try again.")
        } catch {
            return .failed("Vida couldn't answer just now. Please try again in a moment.")
        }
    }

    /// Decodes a 2xx body. Pure, for testing.
    static func outcome(from data: Data, feature: InsightFeature) throws -> InsightOutcome {
        let decoder = JSONDecoder()
        let head = try decoder.decode(InsightEnvelope<EmptyResult>.self, from: data)
        if head.status != "ok" {
            return .notice(head.message ?? "There's nothing to show yet.")
        }
        let generatedAt = head.generatedAt.flatMap(parseDate) ?? .now
        switch feature {
        case .bodyWeather:
            guard let result = try decoder.decode(InsightEnvelope<BodyWeatherResult>.self, from: data).result else {
                return .failed("That answer couldn't be read. Please try again.")
            }
            return .ready(.bodyWeather(result), generatedAt: generatedAt)
        case .differential:
            guard let result = try decoder.decode(InsightEnvelope<DifferentialResult>.self, from: data).result else {
                return .failed("That answer couldn't be read. Please try again.")
            }
            return .ready(.differential(result), generatedAt: generatedAt)
        case .concierge:
            guard let result = try decoder.decode(InsightEnvelope<ConciergeResult>.self, from: data).result else {
                return .failed("That answer couldn't be read. Please try again.")
            }
            return .ready(.concierge(result), generatedAt: generatedAt)
        }
    }

    private static func parseDate(_ text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }

    /// Stands in for `result` when only the envelope's status matters.
    struct EmptyResult: Decodable {}

    // MARK: - Cache

    private struct Cached: Codable {
        let generatedAt: Date
        let bodyWeather: BodyWeatherResult?
        let differential: DifferentialResult?
        let concierge: ConciergeResult?
    }

    private static func cacheURL(_ feature: InsightFeature, userID: String) -> URL {
        let safeID = userID.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("vida-plus-insights", isDirectory: true)
            .appendingPathComponent("\(safeID)-\(feature.rawValue).json", isDirectory: false)
    }

    static func save(_ result: InsightResult, generatedAt: Date, userID: String) {
        let cached: Cached
        let feature: InsightFeature
        switch result {
        case .bodyWeather(let value):
            cached = Cached(generatedAt: generatedAt, bodyWeather: value, differential: nil, concierge: nil)
            feature = .bodyWeather
        case .differential(let value):
            cached = Cached(generatedAt: generatedAt, bodyWeather: nil, differential: value, concierge: nil)
            feature = .differential
        case .concierge(let value):
            cached = Cached(generatedAt: generatedAt, bodyWeather: nil, differential: nil, concierge: value)
            feature = .concierge
        }
        let url = cacheURL(feature, userID: userID)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(cached) else { return }
        // Health-derived text: protected until the device is unlocked.
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    static func load(_ feature: InsightFeature, userID: String) -> (InsightResult, Date)? {
        guard let data = try? Data(contentsOf: cacheURL(feature, userID: userID)),
              let cached = try? JSONDecoder().decode(Cached.self, from: data) else { return nil }
        switch feature {
        case .bodyWeather: return cached.bodyWeather.map { (.bodyWeather($0), cached.generatedAt) }
        case .differential: return cached.differential.map { (.differential($0), cached.generatedAt) }
        case .concierge: return cached.concierge.map { (.concierge($0), cached.generatedAt) }
        }
    }

    /// Removes every saved result for this account, e.g. on account deletion
    /// or when AI permission is withdrawn.
    static func clearAll(userID: String) {
        for feature in InsightFeature.allCases {
            try? FileManager.default.removeItem(at: cacheURL(feature, userID: userID))
        }
    }
}

/// Consent for the Claude-powered Vida+ tools. Separate from Ask Vida's, which
/// names a different provider and sends different data.
nonisolated enum ClaudeInsightsDisclosure {
    static let acceptedKey = "vida.ai.claudeInsights.accepted.v1"

    static let title = "Send your check-ins to Anthropic?"

    static let message = "To build this, Vida sends Anthropic, a third-party AI provider, a summary of up to 90 days of your own check-ins: daily scores like sleep, energy, mood, and pain, plus the tags you added, and the focus areas and conditions you chose in the app. Your notes, meals, medications, Apple Health data, name, and email are never sent. Anthropic uses it only to write your result. You can withdraw this in Settings at any time."
}
