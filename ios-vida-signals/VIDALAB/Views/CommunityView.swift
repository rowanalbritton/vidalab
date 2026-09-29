import SwiftUI

/// The community board.
///
/// Every other screen in Vida shows a member her own data, encrypted and
/// private. This one is the exception, and the disclaimer at the top is not
/// boilerplate: it is the only place in the app where what someone writes
/// becomes readable by other people and by us.
struct CommunityView: View {
    @Environment(AuthManager.self) private var auth
    @State private var community = CommunityService()
    @State private var category: CommunityCategory?
    @State private var showComposer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    disclaimer
                    categoryBar
                    content
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .readableColumn()
            }
            .scrollIndicators(.hidden)
            .refreshable { await community.loadPosts(category: category) }
            .vidaScrollChrome("Community")
            .vidaMenu()
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showComposer = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Vida.forest)
                    }
                    .accessibilityLabel("New post")
                }
            }
        }
        .sheet(isPresented: $showComposer) {
            NewPostView(community: community)
        }
        .task {
            await community.refreshModeratorStatus()
            await community.loadPosts()
        }
    }

    // MARK: - Chrome

    private var header: some View {
        Text("Compare notes\nwith people who get it.")
            .font(Vida.display(34))
            .tracking(Vida.displayTracking)
            .foregroundStyle(Vida.forest)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
            .vidaParallaxHeader()
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "person.2")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Vida.skyDeep)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text("A space to compare notes, not medical advice")
                    .font(Vida.sans(14, weight: .medium))
                    .foregroundStyle(Vida.forest)
                Text("Anything you post here is visible to other members and isn't encrypted, unlike your check-ins. Always speak to a clinician about your own care.")
                    .font(Vida.sans(12))
                    .foregroundStyle(Vida.inkSoft)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Vida.sage.opacity(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var categoryBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                categoryChip(nil, label: "All")
                ForEach(CommunityCategory.allCases) { option in
                    categoryChip(option, label: option.title)
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func categoryChip(_ option: CommunityCategory?, label: String) -> some View {
        let isSelected = category == option
        return Button {
            category = option
            Task { await community.loadPosts(category: option) }
        } label: {
            Text(label)
                .font(Vida.sans(13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Vida.onForest : Vida.inkSoft)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Vida.forest : Vida.paper, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(isSelected ? .clear : Vida.hairline, lineWidth: 0.8)
                }
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Feed

    @ViewBuilder
    private var content: some View {
        switch community.phase {
        case .idle, .loading:
            ProgressView()
                .tint(Vida.moss)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)

        case .failed(let message):
            emptyCard(symbol: "wifi.exclamationmark", title: "Couldn't load", body: message)

        case .loaded where community.posts.isEmpty:
            emptyCard(
                symbol: "bubble.left.and.bubble.right",
                title: category == nil ? "Nothing here yet" : "Nothing in \(category?.title ?? "")",
                body: "Be the first to start a conversation. Whatever you're dealing with, somebody else here probably is too."
            )

        case .loaded:
            LazyVStack(spacing: 12) {
                ForEach(community.posts) { post in
                    NavigationLink {
                        PostDetailView(post: post, community: community)
                    } label: {
                        PostCard(post: post)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private func emptyCard(symbol: String, title: String, body: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Vida.sage)
            Text(title)
                .font(Vida.serif(20))
                .foregroundStyle(Vida.forest)
            Text(body)
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
    }
}

// MARK: - Feed card

struct PostCard: View {
    let post: CommunityPost

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: post.category.symbol)
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(Vida.moss)
                Text(post.category.title.uppercased())
                    .font(Vida.sans(10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Vida.moss)
                Spacer(minLength: 0)
                if post.status == .hidden {
                    Label("Hidden", systemImage: "eye.slash")
                        .font(Vida.sans(10, weight: .medium))
                        .foregroundStyle(Vida.taupe)
                } else if post.flagged {
                    Label("Reported", systemImage: "flag")
                        .font(Vida.sans(10, weight: .medium))
                        .foregroundStyle(Vida.taupe)
                }
            }

            Text(post.title)
                .font(Vida.serif(19))
                .foregroundStyle(Vida.forest)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(post.preview)
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text(post.displayName)
                    .font(Vida.sans(12, weight: .medium))
                    .foregroundStyle(Vida.taupe)
                Text("·")
                    .foregroundStyle(Vida.taupe)
                Text(post.createdAt, format: .relative(presentation: .named))
                    .font(Vida.sans(12))
                    .foregroundStyle(Vida.taupe)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 18)
    }
}
