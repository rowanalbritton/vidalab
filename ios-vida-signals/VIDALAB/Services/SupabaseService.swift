import Foundation
import Supabase

/// Where the backend lives, and whether it is configured at all.
///
/// `Config` literals are empty until build-time injection fills them in, so a
/// fresh checkout has no URL. Force-unwrapping one here crashed the app during
/// static initialisation — before any view, log line or error message could
/// explain why. Since VIDA LAB is fully usable signed out, a missing backend
/// has to degrade to "account features unavailable", never a launch crash.
nonisolated enum VidaBackend {
    static let url: URL = {
        if let url = URL(string: Config.EXPO_PUBLIC_SUPABASE_URL), url.scheme != nil {
            return url
        }
        // `.invalid` is reserved by RFC 6761 and never resolves, so any stray
        // request fails fast as an ordinary network error rather than
        // reaching something real.
        return URL(string: "https://unconfigured.invalid")!
    }()

    /// True only when both halves of the credential pair are present. One
    /// without the other authenticates nothing, so treat it as unconfigured.
    static var isConfigured: Bool {
        !Config.EXPO_PUBLIC_SUPABASE_ANON_KEY.isEmpty
            && URL(string: Config.EXPO_PUBLIC_SUPABASE_URL)?.scheme != nil
    }
}

/// The one Supabase client for the app.
///
/// Auth and data use the same Supabase client. The SDK persists and refreshes
/// the session, while row-level security scopes every request to `auth.uid()`.
nonisolated let vidaSupabase = SupabaseClient(
    supabaseURL: VidaBackend.url,
    supabaseKey: Config.EXPO_PUBLIC_SUPABASE_ANON_KEY
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
