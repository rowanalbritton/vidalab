import Foundation

/// Published VIDA LAB editorial content discovered through the canonical RSS feed.
///
/// The optional body is VIDA LAB-owned HTML supplied by the canonical feed.
/// Source publications remain links; they are never copied into this model.
nonisolated struct ResearchArticle: Codable, Identifiable, Hashable, Sendable {
    let title: String
    let summary: String
    let author: String?
    let publishedAt: Date
    let canonicalURL: URL
    let thumbnailURL: URL?
    let contentHTML: String?
    let categories: [String]
    let evidenceStatus: ResearchEvidenceStatus?

    init(
        title: String,
        summary: String,
        author: String?,
        publishedAt: Date,
        canonicalURL: URL,
        thumbnailURL: URL?,
        contentHTML: String? = nil,
        categories: [String] = [],
        evidenceStatus: ResearchEvidenceStatus? = nil
    ) {
        self.title = title
        self.summary = summary
        self.author = author
        self.publishedAt = publishedAt
        self.canonicalURL = canonicalURL
        self.thumbnailURL = thumbnailURL
        self.contentHTML = contentHTML
        self.categories = categories
        self.evidenceStatus = evidenceStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decode(String.self, forKey: .summary)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        publishedAt = try container.decode(Date.self, forKey: .publishedAt)
        canonicalURL = try container.decode(URL.self, forKey: .canonicalURL)
        thumbnailURL = try container.decodeIfPresent(URL.self, forKey: .thumbnailURL)
        contentHTML = try container.decodeIfPresent(String.self, forKey: .contentHTML)
        categories = try container.decodeIfPresent([String].self, forKey: .categories) ?? []
        evidenceStatus = try container.decodeIfPresent(ResearchEvidenceStatus.self, forKey: .evidenceStatus)
    }

    var id: String { canonicalURL.absoluteString }

    /// Namespaces remote articles away from the existing bundled Library IDs.
    var savedID: String { "research:\(id)" }
}

/// Evidence labels are created only from matching publisher-supplied feed tags.
/// A missing or unfamiliar tag remains `nil`; the app never infers a status
/// from article prose.
nonisolated enum ResearchEvidenceStatus: String, Codable, Hashable, Sendable {
    case availableNow = "available_now"
    case approved
    case clinicalTrial = "clinical_trial"
    case experimental
    case preclinical
    case emergingEvidence = "emerging_evidence"
    case unknown

    var title: String {
        switch self {
        case .availableNow: "Available Now"
        case .approved: "Approved"
        case .clinicalTrial: "Clinical Trial"
        case .experimental: "Experimental"
        case .preclinical: "Preclinical"
        case .emergingEvidence: "Emerging Evidence"
        case .unknown: "Evidence Status Unknown"
        }
    }
}
