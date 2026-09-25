import Foundation
import Supabase

nonisolated enum TreatmentService {
    static func load() async throws -> [TreatmentRecord] {
        try await vidaSupabase
            .from("treatments")
            .select()
            .order("created_date", ascending: false)
            .execute()
            .value
    }

    static func add(_ draft: TreatmentDraft, userID: String) async throws -> TreatmentRecord {
        try await vidaSupabase
            .from("treatments")
            .insert(draft.record(userID: userID))
            .select()
            .single()
            .execute()
            .value
    }

    static func remove(id: UUID) async throws {
        try await vidaSupabase
            .from("treatments")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

nonisolated struct TreatmentRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let type: String
    let startDate: Date?
    let endDate: Date?
    let dosage: String?
    let effectiveness: Int?
    let sideEffects: String?
    let notes: String?
    let status: String
    let createdDate: Date

    enum CodingKeys: String, CodingKey {
        case id, name, type, dosage, effectiveness, status, notes
        case startDate = "start_date"
        case endDate = "end_date"
        case sideEffects = "side_effects"
        case createdDate = "created_date"
    }
}

nonisolated struct TreatmentDraft {
    var name = ""
    var type = "other"
    var status = "current"
    var effectiveness = 3
    var notes = ""

    func record(userID: String) -> TreatmentWrite {
        TreatmentWrite(
            userID: userID,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            effectiveness: effectiveness,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            status: status
        )
    }
}

nonisolated struct TreatmentWrite: Encodable {
    let userID: String
    let name: String
    let type: String
    let effectiveness: Int
    let notes: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case name, type, effectiveness, notes, status
    }
}

private extension String {
    nonisolated var nilIfEmpty: String? { isEmpty ? nil : self }
}
