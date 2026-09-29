import Foundation

/// A topic in the community board.
///
/// Categories mirror the signals Vida already tracks, so a post about sleep
/// sits under the same word the check-in uses. `chronicConditions` and
/// `treatments` have no signal equivalent — they're what people actually want
/// to talk to each other about, and neither is a thing Vida measures.
nonisolated enum CommunityCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case general, sleep, mood, nutrition, movement
    case stress, chronicConditions, treatments, other

    var id: String { rawValue }

    /// Snake case on the wire, matching the CHECK constraint on the table.
    var wireValue: String {
        switch self {
        case .chronicConditions: "chronic_conditions"
        default: rawValue
        }
    }

    init?(wireValue: String) {
        if wireValue == "chronic_conditions" {
            self = .chronicConditions
        } else if let match = CommunityCategory(rawValue: wireValue) {
            self = match
        } else {
            return nil
        }
    }

    var title: String {
        switch self {
        case .general: "General"
        case .sleep: "Sleep"
        case .mood: "Mood"
        case .nutrition: "Nutrition"
        case .movement: "Movement"
        case .stress: "Stress"
        case .chronicConditions: "Conditions"
        case .treatments: "Treatments"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .general: "bubble.left.and.bubble.right"
        case .sleep: "bed.double"
        case .mood: "cloud.sun"
        case .nutrition: "leaf"
        case .movement: "figure.walk"
        case .stress: "wind"
        case .chronicConditions: "heart.text.square"
        case .treatments: "cross.case"
        case .other: "ellipsis.circle"
        }
    }
}

/// A post as other members see it.
///
/// There is deliberately no author identifier on this type. The server
/// withholds `user_id` from the display models, so the app cannot display it
/// by mistake — `displayName` is the whole of what anyone else learns.
nonisolated struct CommunityPost: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let displayName: String
    let title: String
    let body: String
    let category: CommunityCategory
    let status: CommunityStatus
    let flagged: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case title
        case body
        case category
        case status
        case flagged
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        flagged = try container.decodeIfPresent(Bool.self, forKey: .flagged) ?? false

        // An unrecognised category or status means the server knows about a
        // value this build doesn't. Falling back keeps one new category from
        // emptying somebody's whole feed after a server-side addition.
        let rawCategory = try container.decode(String.self, forKey: .category)
        category = CommunityCategory(wireValue: rawCategory) ?? .other

        let rawStatus = try container.decode(String.self, forKey: .status)
        status = CommunityStatus(rawValue: rawStatus) ?? .active
    }

    init(
        id: UUID,
        displayName: String,
        title: String,
        body: String,
        category: CommunityCategory,
        status: CommunityStatus = .active,
        flagged: Bool = false,
        createdAt: Date
    ) {
        self.id = id
        self.displayName = displayName
        self.title = title
        self.body = body
        self.category = category
        self.status = status
        self.flagged = flagged
        self.createdAt = createdAt
    }

    /// First line or so, for the feed.
    var preview: String {
        let collapsed = body
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.count <= 140 ? collapsed : String(collapsed.prefix(140)) + "…"
    }
}

nonisolated enum CommunityStatus: String, Codable, Sendable {
    case active, hidden
}

nonisolated struct CommunityReply: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let postID: UUID
    let displayName: String
    let body: String
    let status: CommunityStatus
    let flagged: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case postID = "post_id"
        case displayName = "display_name"
        case body
        case status
        case flagged
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        postID = try container.decode(UUID.self, forKey: .postID)
        displayName = try container.decode(String.self, forKey: .displayName)
        body = try container.decode(String.self, forKey: .body)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        flagged = try container.decodeIfPresent(Bool.self, forKey: .flagged) ?? false

        let rawStatus = try container.decode(String.self, forKey: .status)
        status = CommunityStatus(rawValue: rawStatus) ?? .active
    }

    init(
        id: UUID,
        postID: UUID,
        displayName: String,
        body: String,
        status: CommunityStatus = .active,
        flagged: Bool = false,
        createdAt: Date
    ) {
        self.id = id
        self.postID = postID
        self.displayName = displayName
        self.body = body
        self.status = status
        self.flagged = flagged
        self.createdAt = createdAt
    }
}

/// What the app sends when composing. Separate from ``CommunityPost`` because
/// the insert grant covers a different set of columns than the display model —
/// the server assigns `id`, `created_at` and `status` itself.
nonisolated struct NewCommunityPost: Encodable, Sendable {
    let authorID: String
    let displayName: String
    let title: String
    let body: String
    let category: String

    enum CodingKeys: String, CodingKey {
        case authorID = "author_id"
        case displayName = "display_name"
        case title
        case body
        case category
    }
}

nonisolated struct NewCommunityReply: Encodable, Sendable {
    let postID: UUID
    let authorID: String
    let displayName: String
    let body: String

    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case authorID = "author_id"
        case displayName = "display_name"
        case body
    }
}

/// Parameters for `block_community_author`. Exactly one of the two is set —
/// the function rejects both and neither.
nonisolated struct BlockAuthorRequest: Encodable, Sendable {
    let postID: UUID?
    let replyID: UUID?

    enum CodingKeys: String, CodingKey {
        case postID = "p_post_id"
        case replyID = "p_reply_id"
    }
}

nonisolated struct NewCommunityFlag: Encodable, Sendable {
    let reporterID: String
    let postID: UUID?
    let replyID: UUID?

    enum CodingKeys: String, CodingKey {
        case reporterID = "reporter_id"
        case postID = "post_id"
        case replyID = "reply_id"
    }
}

/// Composition rules, kept next to the model so the app refuses what the
/// database would refuse anyway — a CHECK violation surfaces as an opaque
/// Postgres error, which is no use to someone mid-sentence.
nonisolated enum CommunityLimits {
    static let titleRange = 3...140
    static let bodyRange = 1...5000
    static let displayNameLimit = 50
    static let defaultDisplayName = "Anonymous"

    static func validationMessage(title: String, body: String) -> String? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedTitle.count < titleRange.lowerBound {
            return "Give it a title of at least \(titleRange.lowerBound) characters."
        }
        if trimmedTitle.count > titleRange.upperBound {
            return "That title is too long. Use \(titleRange.upperBound) characters at most."
        }
        if trimmedBody.isEmpty {
            return "Write something before posting."
        }
        if trimmedBody.count > bodyRange.upperBound {
            return "That's longer than \(bodyRange.upperBound) characters. Trim it a little."
        }
        return contentRejection(trimmedTitle) ?? contentRejection(trimmedBody)
    }

    /// Screens text before it is posted, per App Review guideline 1.2.
    ///
    /// Three things, each tied to a rule in `CommunityGuidelinesView`:
    ///   - Abuse and encouragement of self-harm ("Kind first").
    ///   - Contact details — emails and phone numbers ("Nobody's details"):
    ///     posts are plain text anyone signed in can read.
    ///   - Links ("No selling"): nearly every link on a health board is a
    ///     product, a referral, or a clinic advertising itself.
    ///
    /// Deliberately a first line, not the whole system. Reporting, blocking
    /// and moderator hiding catch what a word list can't, and a filter tuned
    /// aggressively would refuse people describing their own pain — "this is
    /// killing me" has to post fine.
    static func contentRejection(_ raw: String) -> String? {
        let text = raw.lowercased()

        let harmPhrases = [
            "kill yourself", "kill urself", "kys", "go die", "you should die",
            "hope you die", "end your life", "nobody would miss you"
        ]
        if harmPhrases.contains(where: { containsPhrase($0, in: text) }) {
            return "That message goes against the community guidelines. If you're struggling yourself, please reach out to someone. In the US you can call or text 988."
        }

        let abusiveWords: Set<String> = [
            "fuck", "fucking", "fucker", "motherfucker", "cunt", "bitch",
            "whore", "slut", "retard", "retarded", "faggot", "fag", "nigger", "nigga"
        ]
        let words = text.split { !$0.isLetter }.map(String.init)
        if words.contains(where: abusiveWords.contains) {
            return "Please rephrase that without the abusive language. Everyone here is dealing with something."
        }

        if text.range(of: #"[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}"#, options: .regularExpression) != nil {
            return "Take out the email address before posting. Posts are visible to every member."
        }
        // Seven or more digits once spaces, dots, dashes and brackets are
        // ignored. Doses ("200 mg twice a day") and dates stay well short.
        if text.range(of: #"\+?\d[\d\s().-]{7,}\d"#, options: .regularExpression) != nil {
            return "Take out the phone number before posting. Posts are visible to every member."
        }

        if text.range(of: #"(https?://|www\.)\S+|\b[a-z0-9-]+\.(com|net|org|io|co|shop|store|link|ly)\b"#,
                      options: .regularExpression) != nil {
            return "Links can't be posted in the community. Describe what you found instead."
        }

        return nil
    }

    private static func containsPhrase(_ phrase: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        return text.range(of: "\\b\(escaped)\\b", options: .regularExpression) != nil
    }

    /// Falls back rather than rejecting: an empty name field should post as
    /// Anonymous, which is what someone who left it blank almost certainly meant.
    static func normalisedDisplayName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return defaultDisplayName }
        return String(trimmed.prefix(displayNameLimit))
    }

    /// Refuses names that pass the writer off as Vida or as a moderator.
    ///
    /// The board only had a length check, so "VIDA LAB Team" was a valid
    /// display name. On a board where people discuss their medication, a
    /// post that appears to come from the app saying "stop taking that" is
    /// the worst thing this feature could produce.
    ///
    /// The database enforces the same rule; this exists so the answer is a
    /// sentence rather than a Postgres constraint violation. Deliberately
    /// narrow — it blocks claims of authority, not names that merely contain
    /// an awkward word, so "Supportive Sam" still posts fine.
    static func displayNameRejection(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }

        let collapsed = trimmed.replacingOccurrences(of: " ", with: "")
        let vidaClaims = ["vidalab", "vidateam", "vidasupport", "vidastaff", "vidaofficial"]
        if vidaClaims.contains(where: { collapsed.contains($0) }) {
            return "Pick a name that doesn't look like it comes from Vida."
        }

        let roleClaims: Set<String> = [
            "vida", "moderator", "mod", "admin", "administrator",
            "official", "support", "staff"
        ]
        if roleClaims.contains(trimmed) {
            return "That name is reserved. Try another one."
        }

        return nil
    }

    /// Left behind when an author deletes a post other people have replied to.
    static let removedTitle = "Post removed by its author"
    static let removedBody = "The author removed this post. The replies below are other members' own words, so Vida kept them."
}
