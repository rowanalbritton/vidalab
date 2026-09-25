import Foundation
import Supabase

/// Reads and writes the community board.
///
/// Unlike ``VidaSyncService``, nothing here is encrypted — other members have
/// to read it. The privacy that *is* available comes from the schema: the
/// select grant omits `author_id`, so this service could not deanonymise a
/// post even if it tried to.
@MainActor
@Observable
final class CommunityService {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var posts: [CommunityPost] = []
    private(set) var phase: Phase = .idle
    private(set) var isModerator: Bool = false

    /// Replies keyed by post, so reopening a thread shows what was already
    /// fetched rather than a spinner over content the member just read.
    private(set) var replies: [UUID: [CommunityReply]] = [:]

    private let pageSize = 100

    // MARK: - Feed

    func loadPosts(category: CommunityCategory? = nil) async {
        phase = .loading
        do {
            var query = vidaSupabase
                .from("community_posts")
                // Explicit public fields keep the member identifier out of the
                // app's feed model.
                .select("id,display_name,title,body,category,status,flagged,created_at")

            if let category {
                query = query.eq("category", value: category.wireValue)
            }

            posts = try await query
                .order("created_at", ascending: false)
                .limit(pageSize)
                .execute()
                .value
            phase = .loaded
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    func refreshModeratorStatus() async {
        struct ModeratorRow: Decodable { let role: String? }
        do {
            let rows: [ModeratorRow] = try await vidaSupabase
                .from("profiles")
                .select("role")
                .limit(1)
                .execute()
                .value
            isModerator = rows.first?.role == "admin"
        } catch {
            // Never fail open. A read error here means "assume no moderation
            // powers", not "show the hide and delete buttons anyway".
            isModerator = false
        }
    }

    // MARK: - Threads

    func loadReplies(for postID: UUID) async {
        do {
            let rows: [CommunityReply] = try await vidaSupabase
                .from("community_replies")
                .select("id,post_id,display_name,body,status,flagged,created_at")
                .eq("post_id", value: postID)
                .order("created_at", ascending: true)
                .limit(200)
                .execute()
                .value
            replies[postID] = rows
        } catch {
            // Leaves whatever was already loaded in place rather than blanking
            // a thread someone is part way through reading.
            if replies[postID] == nil { replies[postID] = [] }
        }
    }

    // MARK: - Writing

    func post(
        title: String,
        body: String,
        category: CommunityCategory,
        displayName: String,
        userID: String
    ) async throws {
        let draft = NewCommunityPost(
            authorID: userID,
            displayName: CommunityLimits.normalisedDisplayName(displayName),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: body.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category.wireValue
        )
        try await vidaSupabase.from("community_posts").insert(draft).execute()
        await loadPosts()
    }

    func reply(
        to postID: UUID,
        body: String,
        displayName: String,
        userID: String
    ) async throws {
        let draft = NewCommunityReply(
            postID: postID,
            authorID: userID,
            displayName: CommunityLimits.normalisedDisplayName(displayName),
            body: body.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        try await vidaSupabase.from("community_replies").insert(draft).execute()
        await loadReplies(for: postID)
    }

    // MARK: - Reporting

    /// Reports content for review. Flagged content stays visible until a
    /// moderator acts, so one person cannot silence a post by reporting it.
    ///
    /// A second report from the same member hits a unique index. That is a
    /// success from the member's point of view — they already reported it —
    /// so it is swallowed.
    ///
    /// Nothing else is. This used to discard every error, which meant someone
    /// reporting abuse while offline saw the same confirmation as someone
    /// whose report landed, and had no reason to try again.
    func report(postID: UUID? = nil, replyID: UUID? = nil, userID: String) async throws {
        let flag = NewCommunityFlag(reporterID: userID, postID: postID, replyID: replyID)
        do {
            try await vidaSupabase.from("community_flags").insert(flag).execute()
        } catch {
            guard Self.isDuplicateReport(error) else { throw error }
        }
    }

    /// Postgres unique violation, SQLSTATE 23505.
    ///
    /// Matched on the text because the concrete error type varies with how
    /// the request failed, and being wrong here is cheap in one direction
    /// only: a missed duplicate shows a spurious failure on something already
    /// reported, which is far better than swallowing a real one.
    private static func isDuplicateReport(_ error: Error) -> Bool {
        let text = String(describing: error).lowercased()
        return text.contains("23505") || text.contains("duplicate key")
    }

    static func reportFailureMessage(for error: Error) -> String {
        if let urlError = error as? URLError,
           urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
            return "You're offline, so that report didn't send. Try again once you're back on."
        }
        return "Vida couldn't send that report. Please try again."
    }

    // MARK: - Blocking

    /// Hides everything by the author of this post or reply, for this member
    /// only.
    ///
    /// The author is identified server-side. `author_id` is withheld from
    /// clients by column grant, so the app genuinely cannot name who it is
    /// blocking — it points at the content and the database resolves the rest.
    /// That is deliberate: returning the identifier would undo the anonymity
    /// the board is built on.
    func block(postID: UUID? = nil, replyID: UUID? = nil) async throws {
        try await vidaSupabase
            .rpc("block_community_author", params: BlockAuthorRequest(postID: postID, replyID: replyID))
            .execute()
    }

    /// How many people this member has blocked. The list itself is not
    /// readable — only the count, which carries no identifiers.
    func blockedCount() async -> Int {
        do {
            return try await vidaSupabase
                .rpc("community_block_count")
                .execute()
                .value
        } catch {
            return 0
        }
    }

    func unblockEveryone() async throws {
        try await vidaSupabase.rpc("unblock_all_community_authors").execute()
    }

    static func blockFailureMessage(for error: Error) -> String {
        if let urlError = error as? URLError,
           urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
            return "You're offline, so that block didn't save. Try again once you're back on."
        }
        return "Vida couldn't block that person. Please try again."
    }

    // MARK: - Moderation

    func setStatus(_ status: CommunityStatus, postID: UUID) async throws {
        try await vidaSupabase
            .from("community_posts")
            .update(["status": status.rawValue])
            .eq("id", value: postID)
            .execute()
        await loadPosts()
    }

    func setStatus(_ status: CommunityStatus, replyID: UUID, in postID: UUID) async throws {
        try await vidaSupabase
            .from("community_replies")
            .update(["status": status.rawValue])
            .eq("id", value: replyID)
            .execute()
        await loadReplies(for: postID)
    }

    /// Removes a post.
    ///
    /// `community_replies` cascades on delete, so removing a post with a
    /// thread under it also removed other members' replies. On a board where
    /// someone answers a stranger's question about their illness at length,
    /// those words are not the person who asked's to withdraw.
    ///
    /// So an author deleting a post that has replies empties it in place
    /// instead: their own words go, the thread stays. A post nobody answered
    /// is deleted outright, because there is nothing to preserve.
    ///
    /// Moderators always delete for real — they are usually removing the
    /// thread precisely because of what is in it.
    func delete(postID: UUID) async throws {
        // Hidden posts fall through to a real delete: the author-edit policy
        // only permits updates while a post is active, so tombstoning one a
        // moderator has hidden would be rejected by the database.
        let isActive = posts.first { $0.id == postID }?.status ?? .active == .active

        if !isModerator, isActive, try await hasReplies(postID: postID) {
            try await vidaSupabase
                .from("community_posts")
                .update([
                    "title": CommunityLimits.removedTitle,
                    "body": CommunityLimits.removedBody
                ])
                .eq("id", value: postID)
                .execute()
        } else {
            try await vidaSupabase
                .from("community_posts")
                .delete()
                .eq("id", value: postID)
                .execute()
        }
        await loadPosts()
    }

    private func hasReplies(postID: UUID) async throws -> Bool {
        let rows: [CommunityReply] = try await vidaSupabase
            .from("community_replies")
            .select("id,post_id,display_name,body,status,flagged,created_at")
            .eq("post_id", value: postID)
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }

    func delete(replyID: UUID, in postID: UUID) async throws {
        try await vidaSupabase
            .from("community_replies")
            .delete()
            .eq("id", value: replyID)
            .execute()
        await loadReplies(for: postID)
    }

    // MARK: - Errors

    /// Postgres constraint violations are unreadable. Anything Vida can't
    /// phrase usefully becomes a plain sentence rather than raw SQL.
    private static func message(for error: Error) -> String {
        if let urlError = error as? URLError,
           urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
            return "You're offline. The community needs a connection."
        }
        return "Vida couldn't load the community just now. Pull to try again."
    }
}
