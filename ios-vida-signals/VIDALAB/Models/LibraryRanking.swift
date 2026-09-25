import Foundation

/// Orders the existing Library without deciding what a person's body or
/// interests must be. Only preferences they explicitly selected in their
/// health profile affect relevance; every article remains available through
/// browse, filters, and search.
nonisolated enum LibraryRanking {
    static func ordered(
        _ articles: [ScienceArticle],
        profile: HealthProfile
    ) -> [ScienceArticle] {
        let preferredArticleIDs = Set(profile.recommendedArticleIDs)
        let preferredSignals = Set(
            profile.worstSymptoms
                + profile.conditions.flatMap(\.priorities)
                + profile.goals.flatMap(\.priorities)
        )

        guard !preferredArticleIDs.isEmpty || !preferredSignals.isEmpty else {
            return balanced(articles)
        }

        return articles.enumerated()
            .sorted { lhs, rhs in
                let leftScore = score(
                    lhs.element,
                    preferredArticleIDs: preferredArticleIDs,
                    preferredSignals: preferredSignals
                )
                let rightScore = score(
                    rhs.element,
                    preferredArticleIDs: preferredArticleIDs,
                    preferredSignals: preferredSignals
                )

                if leftScore != rightScore { return leftScore > rightScore }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func score(
        _ article: ScienceArticle,
        preferredArticleIDs: Set<String>,
        preferredSignals: Set<SignalCategory>
    ) -> Int {
        var result = preferredArticleIDs.contains(article.id) ? 100 : 0
        result += article.relatedCategories.reduce(into: 0) { partialResult, category in
            if preferredSignals.contains(category) { partialResult += 10 }
        }
        return result
    }

    /// When no preferences are available, interleave the existing editorial
    /// order by pillar so one topic cannot dominate the opening feed.
    private static func balanced(_ articles: [ScienceArticle]) -> [ScienceArticle] {
        var queues = Dictionary(grouping: articles, by: \.pillar)
        var result: [ScienceArticle] = []

        while !queues.isEmpty {
            for pillar in ScienceArticle.Pillar.allCases {
                guard var queue = queues[pillar], !queue.isEmpty else { continue }
                result.append(queue.removeFirst())
                queues[pillar] = queue.isEmpty ? nil : queue
            }
        }

        return result
    }
}
