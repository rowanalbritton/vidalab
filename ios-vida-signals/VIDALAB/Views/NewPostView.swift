import SwiftUI

/// Composing a post.
///
/// The display name defaults to Anonymous and is editable, per the spec. It
/// is not tied to the account in any way the server will hand out — two posts
/// by the same person under the same name are linkable to each other, and
/// that is the whole of what anyone learns.
struct NewPostView: View {
    let community: CommunityService

    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = CommunityLimits.defaultDisplayName
    @State private var title = ""
    @State private var body_ = ""
    @State private var category: CommunityCategory = .general
    @State private var isPosting = false
    @State private var errorMessage: String?
    /// Guideline 1.2 asks for the rules on a member's first post. Resolved
    /// once on appear rather than read live, so accepting them doesn't yank
    /// the sheet away mid-animation.
    @State private var showingGuidelines = false
    @FocusState private var bodyFocused: Bool

    /// Covers the name as well as the post, so a reserved one disables the
    /// button rather than failing against a database constraint after she has
    /// already written the whole thing.
    private var validationMessage: String? {
        CommunityLimits.displayNameRejection(displayName)
            ?? CommunityLimits.validationMessage(title: title, body: body_)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    field(label: "Posting as") {
                        TextField(CommunityLimits.defaultDisplayName, text: $displayName)
                            .font(Vida.sans(16))
                            .textInputAutocapitalization(.words)
                            .onChange(of: displayName) { _, new in
                                if new.count > CommunityLimits.displayNameLimit {
                                    displayName = String(new.prefix(CommunityLimits.displayNameLimit))
                                }
                            }
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Eyebrow(text: "Topic")
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(CommunityCategory.allCases) { option in
                                    Button {
                                        category = option
                                    } label: {
                                        Text(option.title)
                                            .font(Vida.sans(13, weight: category == option ? .semibold : .regular))
                                            .foregroundStyle(category == option ? Vida.onForest : Vida.inkSoft)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(category == option ? Vida.forest : Vida.paper, in: Capsule())
                                            .overlay {
                                                Capsule().strokeBorder(
                                                    category == option ? .clear : Vida.hairline,
                                                    lineWidth: 0.8
                                                )
                                            }
                                    }
                                    .buttonStyle(PressableStyle())
                                    .accessibilityAddTraits(category == option ? [.isSelected] : [])
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                        .scrollIndicators(.hidden)
                    }

                    field(label: "Title") {
                        TextField("What's on your mind?", text: $title, axis: .vertical)
                            .font(Vida.sans(16))
                            .lineLimit(1...3)
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Eyebrow(text: "Your post")
                        TextField(
                            "Share what you're dealing with, or what's worked for you.",
                            text: $body_,
                            axis: .vertical
                        )
                        .font(Vida.sans(16))
                        .lineSpacing(4)
                        .lineLimit(8...20)
                        .focused($bodyFocused)
                        .padding(14)
                        .background(Vida.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Vida.hairline, lineWidth: 0.9)
                        }

                        Text("\(body_.count) / \(CommunityLimits.bodyRange.upperBound)")
                            .font(Vida.sans(11))
                            .foregroundStyle(body_.count > CommunityLimits.bodyRange.upperBound ? Vida.clay : Vida.taupe)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    reminder

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Vida.sans(13))
                            .foregroundStyle(Vida.clay)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .vidaBackground()
            .navigationTitle("New post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(Vida.sans(15))
                        .foregroundStyle(Vida.inkSoft)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isPosting {
                            ProgressView().tint(Vida.forest)
                        } else {
                            Text("Post").font(Vida.sans(15, weight: .semibold))
                        }
                    }
                    .disabled(isPosting || validationMessage != nil)
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
        .task {
            if CommunityGuidelinesView.needsAcceptance { showingGuidelines = true }
        }
        .sheet(isPresented: $showingGuidelines) {
            CommunityGuidelinesView(isGate: true)
        }
    }

    private var reminder: some View {
        Text("Other members will see this, and it isn't encrypted the way your check-ins are. Please don't include anything that identifies you or someone else.")
            .font(Vida.sans(12))
            .foregroundStyle(Vida.taupe)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func field<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Eyebrow(text: label)
            content()
                .foregroundStyle(Vida.ink)
                .tint(Vida.moss)
                .padding(14)
                .background(Vida.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Vida.hairline, lineWidth: 0.9)
                }
        }
    }

    private func submit() async {
        guard let userID = auth.user?.id else {
            errorMessage = "You need to be signed in to post."
            return
        }
        if let validationMessage {
            errorMessage = validationMessage
            return
        }

        isPosting = true
        errorMessage = nil
        do {
            try await community.post(
                title: title,
                body: body_,
                category: category,
                displayName: displayName,
                userID: userID
            )
            dismiss()
        } catch {
            errorMessage = "Vida couldn't post that just now. Try again in a moment."
        }
        isPosting = false
    }
}
