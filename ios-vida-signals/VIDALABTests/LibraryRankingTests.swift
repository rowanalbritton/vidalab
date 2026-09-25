import Testing
@testable import VIDALAB

struct LibraryRankingTests {
    @Test func selectedConditionsRankTheirExistingArticlesFirst() {
        var profile = HealthProfile()
        profile.conditionIDs = ["endometriosis"]

        let ranked = LibraryRanking.ordered(ScienceLibrary.articles, profile: profile)
        let firstMatched = ranked.first { profile.recommendedArticleIDs.contains($0.id) }

        #expect(firstMatched == ranked.first)
        #expect(Set(ranked.map(\.id)) == Set(ScienceLibrary.articles.map(\.id)))
    }

    @Test func missingPreferencesPreserveEveryArticle() {
        let ranked = LibraryRanking.ordered(ScienceLibrary.articles, profile: HealthProfile())

        #expect(ranked.count == ScienceLibrary.articles.count)
        #expect(Set(ranked.map(\.id)) == Set(ScienceLibrary.articles.map(\.id)))
    }
}
