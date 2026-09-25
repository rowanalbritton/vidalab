import SwiftUI

/// A thread: the post, its replies, and a box to add one.
struct PostDetailView: View {
    let post: CommunityPost
    let community: CommunityService

    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var replyText = ""
    @State private var displayName = CommunityLimits.defaultDisplayName
    @State private var isSending = false
    @State private var reportedPost = false
    @State private var reportedReplies: Set<UUID> = []
    @State private var reportError: String?
    @State private var confirmingBlock = false
    @State private var blockingReplyID: UUID?
    @State private var blockError: String?
    @State private var replyError: String?
    @FocusState private var replyFocused: Bool

    private var replies: [CommunityReply] {
        community.replies[post.id] ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                HairlineDivider()
                replyList
                composer
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 40)
            .readableColumn()
        }
        .scrollIndicators(.hidden)
        .vidaBackground()
        .alert(
            "That report didn't send",
            isPresented: Binding(
                get: { reportError != nil },
                set: { if !$0 { reportError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { reportError = nil }
        } message: {
            Text(reportError ?? "")
        }
        .alert(
            "Reply not posted",
            isPresented: Binding(
                get: { replyError != nil },
                set: { if !$0 { replyError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { replyError = nil }
        } message: {
            Text(replyError ?? "")
        }
        .alert(
            "That block didn't save",
            isPresented: Binding(
                get: { blockError != nil },
                set: { if !$0 { blockError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { blockError = nil }
        } message: {
            Text(blockError ?? "")
        }
        .confirmationDialog(
            "Block this person?",
            isPresented: $confirmingBlock,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                Task { await blockAuthor() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You won't see their posts or replies again. They aren't told, and blocking is separate from reporting, so report anything that breaks the guidelines too.")
        }
        .confirmationDialog(
            "Block this person?",
            isPresented: Binding(
                get: { blockingReplyID != nil },
                set: { if !$0 { blockingReplyID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                if let replyID = blockingReplyID {
                    Task { await blockAuthor(ofReply: replyID) }
                }
            }
            Button("Cancel", role: .cancel) { blockingReplyID = nil }
        } message: {
            Text("You won't see their posts or replies again. They aren't told, and blocking is separate from reporting, so report anything that breaks the guidelines too.")
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(reportedPost ? "Reported" : "Report post", systemImage: "flag") {
                        Task { await reportPost() }
                    }
                    .disabled(reportedPost)

                    Button("Block this person", systemImage: "hand.raised") {
                        confirmingBlock = true
                    }

                    if community.isModerator {
                        Section("Moderation") {
                            Button(
                                post.status == .hidden ? "Unhide post" : "Hide post",
                                systemImage: post.status == .hidden ? "eye" : "eye.slash"
                            ) {
                                Task { await toggleHidden() }
                            }
                            Button("Delete post", systemImage: "trash", role: .destructive) {
                                Task { await deletePost() }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(Vida.forest)
                }
                .accessibilityLabel("Post options")
            }
        }
        .toolbarBackground(Vida.cream, for: .navigationBar)
        .task { await community.loadReplies(for: post.id) }
    }

    // MARK: - Post

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: post.category.symbol)
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(Vida.moss)
                Text(post.category.title.uppercased())
                    .font(Vida.sans(10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Vida.moss)
            }

            Text(post.title)
                .font(Vida.serif(26))
                .foregroundStyle(Vida.forest)
                .fixedSize(horizontal: false, vertical: true)

            Text(post.body)
                .font(Vida.sans(16))
                .foregroundStyle(Vida.ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text(post.displayName)
                    .font(Vida.sans(12, weight: .medium))
                Text("·")
                Text(post.createdAt, format: .relative(presentation: .named))
                    .font(Vida.sans(12))
            }
            .foregroundStyle(Vida.taupe)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Replies

    @ViewBuilder
    private var replyList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(replies.isEmpty
                 ? "No replies yet"
                 : "\(replies.count) repl\(replies.count == 1 ? "y" : "ies")")
                .font(Vida.sans(12, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Vida.taupe)

            if replies.isEmpty {
                Text("If you've been through something like this, saying so helps.")
                    .font(Vida.sans(14))
                    .foregroundStyle(Vida.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(replies) { reply in
                replyRow(reply)
            }
        }
    }

    private func replyRow(_ reply: CommunityReply) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(reply.body)
                .font(Vida.sans(15))
                .foregroundStyle(Vida.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text(reply.displayName)
                    .font(Vida.sans(12, weight: .medium))
                Text("·")
                Text(reply.createdAt, format: .relative(presentation: .named))
                    .font(Vida.sans(12))
                if reply.status == .hidden {
                    Text("· hidden")
                        .font(Vida.sans(12, weight: .medium))
                }
                Spacer(minLength: 0)

                Menu {
                    Button(
                        reportedReplies.contains(reply.id) ? "Reported" : "Report reply",
                        systemImage: "flag"
                    ) {
                        Task { await report(reply) }
                    }
                    .disabled(reportedReplies.contains(reply.id))

                    Button("Block this person", systemImage: "hand.raised") {
                        blockingReplyID = reply.id
                    }

                    if community.isModerator {
                        Button(
                            reply.status == .hidden ? "Unhide" : "Hide",
                            systemImage: reply.status == .hidden ? "eye" : "eye.slash"
                        ) {
                            Task { await toggleHidden(reply) }
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            Task { try? await community.delete(replyID: reply.id, in: post.id) }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13))
                        .foregroundStyle(Vida.taupe)
                        .frame(width: 30, height: 24, alignment: .trailing)
                }
                .accessibilityLabel("Reply options")
            }
            .foregroundStyle(Vida.taupe)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 15)
        .opacity(reply.status == .hidden ? 0.5 : 1)
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: 9) {
            Eyebrow(text: "Reply as \(CommunityLimits.normalisedDisplayName(displayName))")

            TextField("Add something helpful…", text: $replyText, axis: .vertical)
                .font(Vida.sans(15))
                .foregroundStyle(Vida.ink)
                .tint(Vida.moss)
                .lineSpacing(4)
                .lineLimit(3...10)
                .focused($replyFocused)
                .padding(14)
                .background(Vida.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Vida.hairline, lineWidth: 0.9)
                }

            Button {
                Task { await sendReply() }
            } label: {
                HStack(spacing: 8) {
                    if isSending { ProgressView().tint(Vida.onForest) }
                    Text(isSending ? "Posting…" : "Reply")
                        .font(Vida.sans(16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Vida.forest, in: Capsule())
                .foregroundStyle(Vida.onForest)
            }
            .buttonStyle(PressableStyle())
            .disabled(isSending || replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.top, 6)
    }

    // MARK: - Actions

    private func sendReply() async {
        guard let userID = auth.user?.id else { return }
        // Replies go through the same pre-post screen as new posts; they
        // used to skip it entirely.
        if let rejection = CommunityLimits.contentRejection(replyText)
            ?? CommunityLimits.displayNameRejection(displayName) {
            replyError = rejection
            return
        }
        isSending = true
        defer { isSending = false }
        do {
            try await community.reply(
                to: post.id,
                body: replyText,
                displayName: displayName,
                userID: userID
            )
            // Cleared only on success. A failed send used to erase what she
            // had written with no sign anything went wrong.
            replyText = ""
            replyFocused = false
        } catch {
            replyError = "That reply didn't send. Check your connection and try again. Your text is still here."
        }
    }

    /// Only claims the report landed when it did. Telling someone their
    /// report of abusive content went through when it didn't is the one
    /// failure here worth being loud about.
    private func reportPost() async {
        guard let userID = auth.user?.id else { return }
        do {
            try await community.report(postID: post.id, userID: userID)
            reportedPost = true
        } catch {
            reportError = CommunityService.reportFailureMessage(for: error)
        }
    }

    private func report(_ reply: CommunityReply) async {
        guard let userID = auth.user?.id else { return }
        do {
            try await community.report(replyID: reply.id, userID: userID)
            reportedReplies.insert(reply.id)
        } catch {
            reportError = CommunityService.reportFailureMessage(for: error)
        }
    }

    /// Blocking hides the thread immediately, so this leaves the screen on
    /// success — staying on a post the member just chose never to see again
    /// would be its own small insult.
    private func blockAuthor() async {
        do {
            try await community.block(postID: post.id)
            await community.loadPosts()
            dismiss()
        } catch {
            blockError = CommunityService.blockFailureMessage(for: error)
        }
    }

    /// Blocking a replier keeps the member in the thread — the post itself is
    /// by somebody else and may be the reason they are here.
    private func blockAuthor(ofReply replyID: UUID) async {
        blockingReplyID = nil
        do {
            try await community.block(replyID: replyID)
            await community.loadReplies(for: post.id)
        } catch {
            blockError = CommunityService.blockFailureMessage(for: error)
        }
    }

    private func toggleHidden() async {
        try? await community.setStatus(post.status == .hidden ? .active : .hidden, postID: post.id)
        dismiss()
    }

    private func toggleHidden(_ reply: CommunityReply) async {
        try? await community.setStatus(
            reply.status == .hidden ? .active : .hidden,
            replyID: reply.id,
            in: post.id
        )
    }

    private func deletePost() async {
        try? await community.delete(postID: post.id)
        dismiss()
    }
}
