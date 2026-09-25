import Foundation
import Supabase

/// Handles the narrow, consented boundary between an on-device journal and Ask Vida.
nonisolated enum AskVidaAIService {
    private static let consentTable = "ai_processing_consents"

    static func healthSummarySharingEnabled(for userID: String) async -> Bool {
        do {
            let rows: [AIConsentRow] = try await vidaSupabase
                .from(consentTable)
                .select("health_summary_enabled,accepted_at,revoked_at")
                .eq("user_id", value: userID)
                .execute()
                .value
            guard let row = rows.first else { return false }
            return row.healthSummaryEnabled && row.acceptedAt != nil && row.revokedAt == nil
        } catch {
            return false
        }
    }

    static func setHealthSummarySharing(_ enabled: Bool, for userID: String) async throws {
        let now = Date()
        let row = AIConsentWrite(
            userID: userID,
            healthSummaryEnabled: enabled,
            acceptedAt: enabled ? now : nil,
            revokedAt: enabled ? nil : now,
            updatedAt: now
        )

        try await vidaSupabase
            .from(consentTable)
            .upsert(row, onConflict: "user_id")
            .execute()
    }

    /// Generates the only health context the client may send to the AI service.
    /// Raw readings, meals, Apple Health samples, and encrypted backups stay on-device.
    @MainActor
    static func approvedSummary(from store: VidaStore) -> String {
        let areas = store.profile.focusSignals.map(\.title).sorted()
        let activeExperiments = store.experiments
            .filter { !$0.isComplete }
            .map(\.title)
            .sorted()

        var lines = ["Vida journal summary, generated on this device:"]
        lines.append("Check-in days recorded: \(store.logs.count).")
        if !areas.isEmpty {
            lines.append("Member-selected focus areas: \(areas.joined(separator: ", ")).")
        }
        if !activeExperiments.isEmpty {
            lines.append("Active self-tracking experiments: \(activeExperiments.joined(separator: ", ")).")
        }
        lines.append("No raw entries, Apple Health samples, meals, medication list, or identifying information are included.")
        return lines.joined(separator: "\n")
    }

    static func answer(question: String, healthSummary: String?) async throws -> String {
        let request = AskVidaRequest(question: question, healthSummary: healthSummary)
        let decoded: AskVidaResponse = try await vidaSupabase.functions.invoke(
            "ask-vida",
            options: FunctionInvokeOptions(body: request)
        )
        if let error = decoded.error, !error.isEmpty {
            throw AskVidaAIError.message(error)
        }
        guard let answer = decoded.answer?.trimmingCharacters(in: .whitespacesAndNewlines), !answer.isEmpty else {
            throw AskVidaAIError.message("Ask Vida could not generate a response. Please try again.")
        }
        return answer
    }
}

nonisolated struct AIConsentRow: Decodable {
    let healthSummaryEnabled: Bool
    let acceptedAt: Date?
    let revokedAt: Date?

    enum CodingKeys: String, CodingKey {
        case healthSummaryEnabled = "health_summary_enabled"
        case acceptedAt = "accepted_at"
        case revokedAt = "revoked_at"
    }
}

nonisolated struct AIConsentWrite: Encodable {
    let userID: String
    let healthSummaryEnabled: Bool
    let acceptedAt: Date?
    let revokedAt: Date?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case healthSummaryEnabled = "health_summary_enabled"
        case acceptedAt = "accepted_at"
        case revokedAt = "revoked_at"
        case updatedAt = "updated_at"
    }
}

nonisolated struct AskVidaRequest: Encodable {
    let question: String
    let healthSummary: String?
}

nonisolated struct AskVidaResponse: Decodable {
    let answer: String?
    let error: String?
}

nonisolated enum AskVidaAIError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message): message
        }
    }
}
