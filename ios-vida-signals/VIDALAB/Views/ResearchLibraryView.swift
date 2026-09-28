import SafariServices
import SwiftUI
import UIKit

struct LibraryShell: View {
    /// Stored so the Vida menu can open either side of the Library.
    @AppStorage(LibrarySection.storageKey) private var section: LibrarySection = .myLibrary

    var body: some View {
        VStack(spacing: 0) {
            LibrarySectionPicker(selection: $section)

            ZStack {
                LibraryView()
                    .opacity(section == .myLibrary ? 1 : 0)
                    .allowsHitTesting(section == .myLibrary)
                    .accessibilityHidden(section != .myLibrary)

                ResearchLibraryView()
                    .opacity(section == .research ? 1 : 0)
                    .allowsHitTesting(section == .research)
                    .accessibilityHidden(section != .research)
            }
        }
        .background(VidaCanvas().ignoresSafeArea())
    }
}

enum LibrarySection: String, CaseIterable, Identifiable {
    case myLibrary
    case research

    static let storageKey = "vida.librarySection"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .myLibrary:
            "My Library"
        case .research:
            "Research Library"
        }
    }
}

/// The same sliding forest pill as the Lab's switch, so the two tabs with
/// sections read as one system.
private struct LibrarySectionPicker: View {
    @Binding var selection: LibrarySection
    @Namespace private var segment

    var body: some View {
        HStack(spacing: 4) {
            ForEach(LibrarySection.allCases) { item in
                Button {
                    withAnimation(Vida.Motion.page) { selection = item }
                } label: {
                    Text(item.title)
                        .font(Vida.sans(14, weight: selection == item ? .semibold : .regular))
                        .foregroundStyle(selection == item ? Vida.onForest : Vida.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background {
                            if selection == item {
                                Capsule()
                                    .fill(Vida.forest)
                                    .matchedGeometryEffect(id: "segment", in: segment)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(selection == item ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay { Capsule().strokeBorder(Vida.hairline.opacity(0.7), lineWidth: 0.7) }
        .sensoryFeedback(.selection, trigger: selection)
        .padding(.horizontal, Vida.Space.gutter)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

struct ResearchLibraryView: View {
    @Environment(VidaStore.self) private var store
    @State private var model = ResearchLibraryModel()
    @State private var selectedArticle: ResearchArticle?

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ResearchLibraryHeader()
                    ResearchExplorerCard(onOpen: SafariPresenter.present)

                    if !model.availableCategories.isEmpty {
                        ResearchCategoryFilter(
                            categories: model.availableCategories,
                            selection: $model.selectedCategory
                        )
                    }

                    if model.isLoading && model.articles.isEmpty {
                        ResearchLibraryLoadingView()
                    } else if let errorMessage = model.errorMessage, model.articles.isEmpty {
                        ResearchLibraryErrorView(message: errorMessage) {
                            Task { await model.load(forceRefresh: true) }
                        }
                    } else if model.visibleArticles.isEmpty {
                        ResearchLibraryEmptyView(isSearching: !model.query.isEmpty)
                    } else {
                        let saved = model.visibleArticles.filter {
                            store.savedArticleIDs.contains($0.savedID)
                        }

                        if !saved.isEmpty && model.query.isEmpty {
                            ResearchArticleSection(
                                eyebrow: "Yours",
                                title: "Saved research",
                                articles: saved,
                                savedArticleIDs: store.savedArticleIDs,
                                onOpen: { selectedArticle = $0 },
                                onToggleSave: store.toggleSave
                            )
                        }

                        ResearchArticleSection(
                            eyebrow: model.query.isEmpty ? "Latest publishing" : "Search results",
                            title: model.query.isEmpty
                                ? "Latest VIDA LAB articles"
                                : "\(model.visibleArticles.count) match\(model.visibleArticles.count == 1 ? "" : "es")",
                            articles: model.visibleArticles,
                            savedArticleIDs: store.savedArticleIDs,
                            onOpen: { selectedArticle = $0 },
                            onToggleSave: store.toggleSave
                        )
                    }

                    ResearchLibraryDisclaimer()
                    ResearchLibraryWebsiteLink(onOpen: SafariPresenter.present)
                }
                .padding(.bottom, 40)
                .readableColumn()
            }
            .scrollIndicators(.hidden)
            .vidaScrollChrome("Research Library")
            .vidaMenu()
            .vidaBackground()
            .searchable(text: $model.query, prompt: "Search published research")
            .refreshable {
                await model.load(forceRefresh: true)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await model.loadIfNeeded()
        }
        .sheet(item: $selectedArticle) { article in
            ResearchArticleReaderView(article: article)
        }
    }
}

@Observable
final class ResearchLibraryModel {
    var query = "" {
        didSet { updateVisibleArticles() }
    }
    var selectedCategory: String? {
        didSet { updateVisibleArticles() }
    }
    private(set) var articles: [ResearchArticle] = []
    private(set) var visibleArticles: [ResearchArticle] = []
    private(set) var availableCategories: [String] = []
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    private let service: any ResearchArticleLoading
    private var hasLoaded = false

    init(service: any ResearchArticleLoading = ResearchLibraryService()) {
        self.service = service
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load(forceRefresh: Bool = false) async {
        guard !isLoading || !hasLoaded else { return }
        isLoading = true
        errorMessage = nil

        do {
            articles = try await service.loadArticles(forceRefresh: forceRefresh)
            availableCategories = Set(articles.flatMap(\.categories)).sorted()
            hasLoaded = true
            updateVisibleArticles()
        } catch {
            #if DEBUG
            print("Research Library load failed: \(type(of: error))")
            #endif
            errorMessage = "We couldn’t load the Research Library. Check your connection and try again."
        }

        isLoading = false
    }

    private func updateVisibleArticles() {
        var results = articles
        if let selectedCategory {
            results = results.filter { $0.categories.contains(selectedCategory) }
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            results = results.filter { article in
                article.title.localizedStandardContains(trimmedQuery)
                    || article.summary.localizedStandardContains(trimmedQuery)
                    || article.author?.localizedStandardContains(trimmedQuery) == true
                    || article.categories.contains {
                        $0.localizedStandardContains(trimmedQuery)
                    }
            }
        }
        visibleArticles = results
    }
}

private struct ResearchCategoryFilter: View {
    let categories: [String]
    @Binding var selection: String?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                SelectChip(label: "All", isSelected: selection == nil) {
                    selection = nil
                }
                ForEach(categories, id: \.self) { category in
                    SelectChip(label: category, isSelected: selection == category) {
                        selection = selection == category ? nil : category
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 22)
    }
}

private struct ResearchLibraryHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Published research,\nkept current.")
                .font(Vida.display(34))
                .tracking(Vida.displayTracking)
                .foregroundStyle(Vida.forest)
            Text("Explore VIDA LAB’s complete research map on vidalab.co, then browse the latest publisher-owned articles available in the native library.")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .vidaParallaxHeader()
    }
}

private struct ResearchExplorerCard: View {
    let onOpen: (URL) -> Void
    private let researchURL = URL(string: "https://vidalab.co/research")!

    var body: some View {
        Button {
            onOpen(researchURL)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Vida.moss)
                    .frame(width: 44, height: 44)
                    .background(Vida.sage.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text("VIDA LAB Research Explorer")
                        .font(Vida.serif(21))
                        .foregroundStyle(Vida.forest)
                    Text("Open the canonical research map, including condition explainers, evidence stages, and emerging technologies.")
                        .font(Vida.sans(14))
                        .foregroundStyle(Vida.inkSoft)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Label("Explore on vidalab.co", systemImage: "arrow.up.right")
                        .font(Vida.sans(13, weight: .semibold))
                        .foregroundStyle(Vida.moss)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .paperCard(padding: 18)
        .padding(.horizontal, 22)
        .accessibilityHint("Opens the complete VIDA LAB Research Explorer in an in-app browser")
    }
}

private struct ResearchLibraryLoadingView: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(Vida.moss)
            Text("Loading published research…")
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 54)
        .accessibilityElement(children: .combine)
    }
}

private struct ResearchLibraryErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            QuietEmptyState(
                symbol: "wifi.exclamationmark",
                title: "Research unavailable",
                message: message
            )
            Button("Try again", action: onRetry)
                .font(Vida.sans(14, weight: .semibold))
                .foregroundStyle(Vida.onForest)
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .background(Vida.forest, in: Capsule())
                .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 22)
    }
}

private struct ResearchLibraryEmptyView: View {
    let isSearching: Bool

    var body: some View {
        QuietEmptyState(
            symbol: isSearching ? "magnifyingglass" : "books.vertical",
            title: isSearching ? "No matches" : "Nothing published yet",
            message: isSearching
                ? "No published research matches that search."
                : "No research articles are available right now."
        )
        .padding(.horizontal, 22)
    }
}

private struct ResearchArticleSection: View {
    let eyebrow: String
    let title: String
    let articles: [ResearchArticle]
    let savedArticleIDs: Set<String>
    let onOpen: (ResearchArticle) -> Void
    let onToggleSave: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(eyebrow: eyebrow, title: title)
                .padding(.horizontal, 24)

            LazyVStack(spacing: 12) {
                ForEach(articles) { article in
                    ResearchArticleCard(
                        article: article,
                        isSaved: savedArticleIDs.contains(article.savedID),
                        onOpen: { onOpen(article) },
                        onToggleSave: { onToggleSave(article.savedID) }
                    )
                }
            }
            .padding(.horizontal, 22)
        }
    }
}

private struct ResearchArticleCard: View {
    let article: ResearchArticle
    let isSaved: Bool
    let onOpen: () -> Void
    let onToggleSave: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(article.publishedAt, format: .dateTime.month(.abbreviated).day().year())
                        .font(Vida.sans(11, weight: .semibold))
                        .foregroundStyle(Vida.moss)

                    Text(article.title)
                        .font(Vida.serif(20))
                        .foregroundStyle(Vida.forest)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(article.summary)
                        .font(Vida.sans(14))
                        .foregroundStyle(Vida.inkSoft)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)

                    if let author = article.author {
                        Text(author)
                            .font(Vida.sans(12))
                            .foregroundStyle(Vida.taupe)
                    }

                    Label("Read article", systemImage: "doc.richtext")
                        .font(Vida.sans(13, weight: .medium))
                        .foregroundStyle(Vida.moss)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the complete cached article and its sources")

            VStack(spacing: 8) {
                Button(action: onToggleSave) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Vida.moss)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSaved ? "Remove bookmark" : "Save article")

                ShareLink(
                    item: article.canonicalURL,
                    subject: Text(article.title),
                    message: Text(article.summary)
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Vida.moss)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Share article")
            }
        }
        .paperCard(padding: 18)
    }
}

private struct ResearchLibraryDisclaimer: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Medical Information", systemImage: "cross.case")
                .font(Vida.sans(13, weight: .semibold))
                .foregroundStyle(Vida.forest)
            Text("VIDA LAB provides educational information about health and biomedical research and is not a substitute for professional medical advice, diagnosis, or treatment. Always discuss medical decisions with a qualified healthcare professional.")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Vida.sage.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 22)
    }
}

private struct ResearchLibraryWebsiteLink: View {
    let onOpen: (URL) -> Void
    private let websiteURL = URL(string: "https://vidalab.co")!

    var body: some View {
        Button {
            onOpen(websiteURL)
        } label: {
            HStack(spacing: 8) {
                Text("Open the VIDA LAB website")
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .font(Vida.sans(14, weight: .semibold))
            .foregroundStyle(Vida.moss)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 22)
    }
}

@MainActor
enum SafariPresenter {
    static func present(_ url: URL) {
        guard url.scheme == "https",
              let presenter = UIApplication.shared.activeKeyWindow?.rootViewController?.topPresenter else {
            return
        }

        let safari = SFSafariViewController(url: url)
        safari.dismissButtonStyle = .close
        safari.preferredBarTintColor = UIColor(Vida.cream)
        safari.preferredControlTintColor = UIColor(Vida.moss)
        presenter.present(safari, animated: true)
    }
}

@MainActor
private extension UIApplication {
    var activeKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows
            .first { $0.isKeyWindow }
    }
}

@MainActor
private extension UIViewController {
    var topPresenter: UIViewController {
        if let presentedViewController {
            return presentedViewController.topPresenter
        }
        if let navigationController = self as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return visibleViewController.topPresenter
        }
        if let tabBarController = self as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return selectedViewController.topPresenter
        }
        return self
    }
}
