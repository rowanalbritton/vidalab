import Foundation

nonisolated enum ResearchLibraryError: LocalizedError, Sendable {
    case invalidResponse
    case malformedFeed
    case noArticles

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The Research Library returned an unexpected response."
        case .malformedFeed:
            "The Research Library feed could not be read."
        case .noArticles:
            "No research articles are available right now."
        }
    }
}

nonisolated protocol ResearchArticleLoading: Sendable {
    func loadArticles(forceRefresh: Bool) async throws -> [ResearchArticle]
}

/// Loads VIDA LAB's publisher-owned RSS content and keeps an offline cache.
///
/// The feed contains VIDA LAB's own article HTML. External papers and source
/// publications remain links and aren't downloaded or copied into the cache.
nonisolated struct ResearchLibraryService: ResearchArticleLoading, Sendable {
    private let feedURL = URL(string: "https://vidalab.substack.com/feed")!
    private let cacheFileName = "research-library-metadata.json"

    func loadArticles(forceRefresh: Bool = false) async throws -> [ResearchArticle] {
        do {
            var request = URLRequest(
                url: feedURL,
                cachePolicy: forceRefresh ? .reloadRevalidatingCacheData : .useProtocolCachePolicy,
                timeoutInterval: 15
            )
            request.setValue("application/rss+xml, application/xml;q=0.9", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                throw ResearchLibraryError.invalidResponse
            }

            let articles = try Self.parseFeed(data)
            guard !articles.isEmpty else { throw ResearchLibraryError.noArticles }
            try? saveCache(articles)
            return articles
        } catch {
            if let cached = try? loadCache(), !cached.isEmpty {
                return cached
            }
            throw error
        }
    }

    static func parseFeed(_ data: Data) throws -> [ResearchArticle] {
        try ResearchFeedParser.parse(data)
    }

    private func saveCache(_ articles: [ResearchArticle]) throws {
        let data = try JSONEncoder().encode(articles)
        try data.write(to: cacheURL, options: .atomic)
    }

    private func loadCache() throws -> [ResearchArticle] {
        let data = try Data(contentsOf: cacheURL)
        return try JSONDecoder().decode([ResearchArticle].self, from: data)
    }

    private var cacheURL: URL {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent(cacheFileName, isDirectory: false)
    }
}

nonisolated private final class ResearchFeedParser: NSObject, XMLParserDelegate {
    private struct Draft {
        var title = ""
        var summary = ""
        var author = ""
        var publicationDate = ""
        var link = ""
        var thumbnail = ""
        var contentHTML = ""
        var categories: [String] = []
    }

    private var articles: [ResearchArticle] = []
    private var draft: Draft?
    private var currentElement = ""
    private var text = ""
    private var parseError: Error?

    static func parse(_ data: Data) throws -> [ResearchArticle] {
        let delegate = ResearchFeedParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse(), delegate.parseError == nil else {
            throw delegate.parseError ?? parser.parserError ?? ResearchLibraryError.malformedFeed
        }

        return delegate.articles.sorted { $0.publishedAt > $1.publishedAt }
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = Self.localName(elementName)
        text = ""

        if currentElement == "item" {
            draft = Draft()
        } else if currentElement == "enclosure",
                  let url = attributeDict["url"] {
            draft?.thumbnail = url
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let string = String(data: CDATABlock, encoding: .utf8) {
            text += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard draft != nil else { return }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)

        switch Self.localName(elementName) {
        case "title":
            draft?.title = value
        case "description":
            draft?.summary = value.researchPlainText
        case "encoded":
            draft?.contentHTML = value
        case "category":
            if !value.isEmpty {
                draft?.categories.append(value.researchPlainText)
            }
        case "creator":
            draft?.author = value
        case "pubDate":
            draft?.publicationDate = value
        case "link":
            draft?.link = value
        case "item":
            appendDraft()
            draft = nil
        default:
            break
        }

        currentElement = ""
        text = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }

    private func appendDraft() {
        guard let draft,
              !draft.title.isEmpty,
              let canonicalURL = URL(string: draft.link),
              canonicalURL.scheme == "https",
              let publishedAt = Self.dateFormatter.date(from: draft.publicationDate) else {
            return
        }

        let categories = draft.categories.uniqued()
        articles.append(
            ResearchArticle(
                title: draft.title.researchPlainText,
                summary: draft.summary,
                author: draft.author.isEmpty ? nil : draft.author.researchPlainText,
                publishedAt: publishedAt,
                canonicalURL: canonicalURL,
                thumbnailURL: URL(string: draft.thumbnail),
                contentHTML: draft.contentHTML.isEmpty ? nil : draft.contentHTML,
                categories: categories,
                evidenceStatus: Self.evidenceStatus(from: categories)
            )
        )
    }

    private static func evidenceStatus(from categories: [String]) -> ResearchEvidenceStatus? {
        for category in categories {
            let normalized = category
                .lowercased()
                .replacingOccurrences(of: "-", with: "_")
                .replacingOccurrences(of: " ", with: "_")
            if let status = ResearchEvidenceStatus(rawValue: normalized) {
                return status
            }
        }
        return nil
    }

    /// `XMLParser` reports qualified RSS extension names such as
    /// `content:encoded` and `dc:creator` when namespace processing is off.
    private static func localName(_ qualifiedName: String) -> String {
        qualifiedName.split(separator: ":", omittingEmptySubsequences: false).last.map(String.init)
            ?? qualifiedName
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter
    }()
}

nonisolated private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen: Set<String> = []
        return filter { seen.insert($0).inserted }
    }
}

nonisolated private extension String {
    var researchPlainText: String {
        replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#8216;", with: "‘")
            .replacingOccurrences(of: "&#8217;", with: "’")
            .replacingOccurrences(of: "&#8220;", with: "“")
            .replacingOccurrences(of: "&#8221;", with: "”")
            .replacingOccurrences(of: "&#8211;", with: "–")
            .replacingOccurrences(of: "&#8212;", with: "—")
            .replacingOccurrences(of: "&#8230;", with: "…")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
