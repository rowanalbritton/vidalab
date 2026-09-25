import Foundation
import Supabase

/// The one Supabase client for the app.
///
/// Auth and data use the same Supabase client. The SDK persists and refreshes
/// the session, while row-level security scopes every request to `auth.uid()`.
nonisolated let vidaSupabase: SupabaseClient = {
    let localSecrets: [String: String] = {
        guard
            let secretsURL = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: secretsURL),
            let values = try? PropertyListSerialization.propertyList(
                from: data,
                format: nil
            ) as? [String: String]
        else {
            return [:]
        }

        return values
    }()

    let urlString = Config.EXPO_PUBLIC_SUPABASE_URL.isEmpty
        ? localSecrets["EXPO_PUBLIC_SUPABASE_URL"] ?? ""
        : Config.EXPO_PUBLIC_SUPABASE_URL
    let key = Config.EXPO_PUBLIC_SUPABASE_ANON_KEY.isEmpty
        ? localSecrets["EXPO_PUBLIC_SUPABASE_ANON_KEY"] ?? ""
        : Config.EXPO_PUBLIC_SUPABASE_ANON_KEY

    guard
        let url = URL(string: urlString),
        url.scheme == "https",
        url.host != nil,
        !key.isEmpty
    else {
        preconditionFailure(
            "Missing or invalid Supabase configuration. "
                + "Provide EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY "
                + "through generated Config.swift or the ignored Secrets.plist."
        )
    }

    return SupabaseClient(
        supabaseURL: url,
        supabaseKey: key,
        options: .init(
            auth: .init(emitLocalSessionAsInitialSession: true)
        )
    )
}()

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

/// Encoder for Edge Function bodies.
///
/// PostgREST calls go out through the SDK's own encoder, which writes dates as
/// ISO 8601 strings. `FunctionInvokeOptions` does not: it defaults to a plain
/// `JSONEncoder`, so a `Date` is encoded as a bare number of seconds since
/// 2001 and the function rejects the whole batch as malformed. Anything sent to
/// a function must therefore carry this encoder explicitly.
///
/// Fractional seconds are included deliberately. `apply_ios_checkin_event`
/// resolves conflicts by comparing `client_updated_at`, and two edits to the
/// same reading inside one second would otherwise compare equal, which the
/// server reads as stale and discards.
nonisolated let vidaFunctionEncoder: JSONEncoder = {
    // Spelled out field by field on purpose. The `ISO8601FormatStyle` builder
    // methods are additive rather than modifying a full default, so the
    // shorter `.iso8601.time(includingFractionalSeconds: true)` emits a time
    // with no date in front of it.
    let style = Date.ISO8601FormatStyle()
        .year().month().day()
        .dateSeparator(.dash)
        .time(includingFractionalSeconds: true)
        .timeSeparator(.colon)
        .timeZone(separator: .omitted)

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .custom { date, encoder in
        var container = encoder.singleValueContainer()
        try container.encode(style.format(date))
    }
    return encoder
}()

/// Encrypted, per-reading sync event sent only to the authenticated Edge
/// Function. Keeping this separate from `CheckInRow` preserves the existing
/// whole-day backup contract while allowing another client to merge a morning
/// and evening edit independently.
nonisolated struct CheckInSyncEventRequest: Encodable, Sendable {
    let clientId: String
    let localDate: String
    let period: String
    let timezone: String?
    let ciphertext: String
    let schemaVersion: Int
    let clientUpdatedAt: Date
    let deletedAt: Date?
}

nonisolated struct CheckInSyncEventBatch: Encodable, Sendable {
    let events: [CheckInSyncEventRequest]
}

/// The Edge Function returns row details that the app deliberately does not
/// need to inspect while it is in dual-write mode. Decoding an empty model is
/// enough to verify that the function accepted the batch.
nonisolated struct CheckInSyncEventResponse: Decodable, Sendable {}

nonisolated struct CheckInSyncEventRow: Decodable, Sendable {
    let clientId: String
    let localDate: String
    let period: String
    let timezone: String?
    let ciphertext: String
    let schemaVersion: Int
    let clientUpdatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case localDate = "local_date"
        case period
        case timezone
        case ciphertext
        case schemaVersion = "schema_version"
        case clientUpdatedAt = "client_updated_at"
        case deletedAt = "deleted_at"
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

/// The passphrase-wrapped copy of the sync key (see `VidaKeyEscrow`).
///
/// Safe to store in plain columns: salt and iteration count are public inputs
/// by design, and `wrapped_key` is useless without the passphrase, which never
/// leaves the device.
nonisolated struct SyncKeyRow: Codable, Sendable {
    let userId: String
    let kdf: String
    let salt: String
    let iterations: Int
    let wrappedKey: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case kdf
        case salt
        case iterations
        case wrappedKey = "wrapped_key"
        case updatedAt = "updated_at"
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
///
/// The name is the specification: this is the calendar day the member would
/// say it was, not the UTC day. A check-in belongs to the day it felt like.
///
/// It previously took local midnight and formatted it through a **UTC**
/// formatter, which is a day early for every positive UTC offset — all of
/// continental Europe year-round, the UK through British Summer Time, and
/// everywhere from Lagos to Auckland. Only the Americas were correct. Worse,
/// the UK flipped twice a year, so one member's January and July rows keyed
/// off different days.
///
/// Reading the components straight out of the member's own calendar removes
/// the class of bug rather than the instance: there is no longer a formatter
/// time zone that can disagree with the calendar it was derived from.
nonisolated enum VidaDateKey {
    static func string(from date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0
        )
    }

    static func date(from key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4,
              parts[1].count == 2,
              parts[2].count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}
