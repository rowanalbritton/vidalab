import Foundation
import Supabase

/// The one Supabase client for the app.
///
/// Auth is Rork Auth: the access token in the Keychain is a JWT whose `sub`
/// claim drives `user_id()` in every row-level-security policy. Returning `nil`
/// while signed out is deliberate — the SDK then runs as `anon`, which every
/// policy rejects, so a signed-out member simply never syncs.
nonisolated let vidaSupabase = SupabaseClient(
    supabaseURL: URL(string: Config.EXPO_PUBLIC_SUPABASE_URL)!,
    supabaseKey: Config.EXPO_PUBLIC_SUPABASE_ANON_KEY,
    options: .init(
        auth: .init(
            accessToken: {
                // Synchronous Keychain read — never `await` this.
                KeychainHelper.get("access_token")
            }
        )
    )
)

// MARK: - Wire format

/// Every health row is the same shape: an opaque sync key plus ciphertext.
/// The server cannot read any of it (see `VidaCrypto`).

nonisolated struct CheckInRow: Codable, Sendable {
    let userId: String
    let localDate: String
    let ciphertext: String
    let schemaVersion: Int
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case localDate = "local_date"
        case ciphertext
        case schemaVersion = "schema_version"
        case updatedAt = "updated_at"
    }
}

nonisolated struct ClientKeyedRow: Codable, Sendable {
    let userId: String
    let clientId: String
    let ciphertext: String
    let schemaVersion: Int
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case clientId = "client_id"
        case ciphertext
        case schemaVersion = "schema_version"
        case updatedAt = "updated_at"
    }
}

nonisolated struct SavedArticleRow: Codable, Sendable {
    let userId: String
    let articleRef: String
    let ciphertext: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case articleRef = "article_ref"
        case ciphertext
    }
}

nonisolated struct ProfileUpsert: Encodable, Sendable {
    let id: String
    let email: String?
    let name: String?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case updatedAt = "updated_at"
    }
}

/// Membership standing as the server sees it. Read-only to the client: the
/// store of record is RevenueCat, and a client that could write its own tier
/// would be a one-line route to free Vida+.
nonisolated struct EntitlementRow: Codable, Sendable {
    let tier: String
    let status: String
    let source: String?
    let productId: String?
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case tier
        case status
        case source
        case productId = "product_id"
        case expiresAt = "expires_at"
    }
}

/// Date-only key used for `check_ins.local_date`.
nonisolated enum VidaDateKey {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: Calendar.current.startOfDay(for: date))
    }
}
