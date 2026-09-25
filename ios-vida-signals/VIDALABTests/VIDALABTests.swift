//
//  VIDALABTests.swift
//  VIDALABTests
//
//  Created by Rork on September 17, 2026.
//

import CryptoKit
import Foundation
import Testing
@testable import VIDALAB

struct VIDALABTests {
    @Test func syncMigrationStateIsScopedToTheSupabaseAccount() {
        let first = VidaSyncService.migrationFlagKey(for: "account-a")
        let second = VidaSyncService.migrationFlagKey(for: "account-b")

        #expect(first != second)
        #expect(first.hasPrefix("vida.migration.supabase.v2."))
    }

    @Test func checkInEventIDIsStablePerSignalAndPeriod() {
        let day = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 9, day: 22))!
        let first = CheckInSyncEventID.make(
            userID: "MEMBER@example.com",
            localDate: day,
            category: .energy,
            period: .morning
        )
        let repeatID = CheckInSyncEventID.make(
            userID: "member@example.com",
            localDate: day,
            category: .energy,
            period: .morning
        )
        let evening = CheckInSyncEventID.make(
            userID: "member@example.com",
            localDate: day,
            category: .energy,
            period: .evening
        )

        #expect(first == repeatID)
        #expect(first != evening)
    }

    @Test func researchArticleUsesNamespacedBookmarkID() throws {
        let url = try #require(URL(string: "https://vidalab.substack.com/p/example"))
        let article = ResearchArticle(
            title: "Example",
            summary: "A careful research explanation.",
            author: "VIDA LAB",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            canonicalURL: url,
            thumbnailURL: nil
        )

        #expect(article.id == url.absoluteString)
        #expect(article.savedID == "research:\(url.absoluteString)")
    }

    @Test func researchArticleCacheRoundTrips() throws {
        let url = try #require(URL(string: "https://vidalab.substack.com/p/example"))
        let original = ResearchArticle(
            title: "Example",
            summary: "A careful research explanation.",
            author: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            canonicalURL: url,
            thumbnailURL: nil
        )

        let data = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([ResearchArticle].self, from: data)

        #expect(decoded == [original])
    }

    @Test func legacyMetadataCacheStillDecodes() throws {
        let publishedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let legacyJSON: [String: Any] = [
            "title": "Legacy article",
            "summary": "Cached before offline bodies were introduced.",
            "publishedAt": publishedAt.timeIntervalSinceReferenceDate,
            "canonicalURL": "https://vidalab.substack.com/p/legacy"
        ]
        let data = try JSONSerialization.data(withJSONObject: legacyJSON)
        let decoded = try JSONDecoder().decode(ResearchArticle.self, from: data)

        #expect(decoded.contentHTML == nil)
        #expect(decoded.categories.isEmpty)
        #expect(decoded.evidenceStatus == nil)
    }

    @Test func feedPreservesBodySourcesAndPublisherMetadata() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss xmlns:content="http://purl.org/rss/1.0/modules/content/"
             xmlns:dc="http://purl.org/dc/elements/1.1/" version="2.0">
          <channel>
            <item>
              <title><![CDATA[Careful Trial Explanation]]></title>
              <description><![CDATA[Early evidence &amp; important limits.]]></description>
              <link>https://vidalab.substack.com/p/careful-trial</link>
              <dc:creator><![CDATA[VIDA LAB]]></dc:creator>
              <pubDate>Sat, 19 Sep 2026 05:01:41 +0000</pubDate>
              <category><![CDATA[Clinical Trial]]></category>
              <content:encoded><![CDATA[
                <h2>What we know</h2>
                <p>Researchers are studying this question.</p>
                <h2>Sources</h2>
                <p><a href="https://clinicaltrials.gov/study/example">Open source</a></p>
              ]]></content:encoded>
            </item>
          </channel>
        </rss>
        """

        let articles = try ResearchLibraryService.parseFeed(Data(xml.utf8))
        let article = try #require(articles.first)

        #expect(article.contentHTML?.contains("Sources") == true)
        #expect(article.contentHTML?.contains("clinicaltrials.gov") == true)
        #expect(article.author == "VIDA LAB")
        #expect(article.categories == ["Clinical Trial"])
        #expect(article.evidenceStatus == .clinicalTrial)
    }

    @Test func feedSkipsMalformedArticlesWithoutCrashing() throws {
        let xml = """
        <rss version="2.0"><channel>
          <item><title>Missing URL</title><pubDate>Sat, 19 Sep 2026 05:01:41 +0000</pubDate></item>
          <item><title>Missing date</title><link>https://vidalab.substack.com/p/no-date</link></item>
          <item>
            <title>Valid article</title>
            <description>A useful explanation.</description>
            <link>https://vidalab.substack.com/p/valid</link>
            <pubDate>Sat, 19 Sep 2026 05:01:41 +0000</pubDate>
          </item>
        </channel></rss>
        """

        let articles = try ResearchLibraryService.parseFeed(Data(xml.utf8))

        #expect(articles.count == 1)
        #expect(articles.first?.title == "Valid article")
    }

    @Test func feedRejectsNonHTTPSCanonicalURLs() throws {
        let xml = """
        <rss version="2.0"><channel><item>
          <title>Unsafe article</title>
          <link>http://example.com/article</link>
          <pubDate>Sat, 19 Sep 2026 05:01:41 +0000</pubDate>
        </item></channel></rss>
        """

        let articles = try ResearchLibraryService.parseFeed(Data(xml.utf8))

        #expect(articles.isEmpty)
    }

    @Test func unfamiliarCategoryDoesNotFabricateEvidenceStatus() throws {
        let xml = """
        <rss version="2.0"><channel><item>
          <title>Careful article</title>
          <link>https://vidalab.substack.com/p/careful</link>
          <pubDate>Sat, 19 Sep 2026 05:01:41 +0000</pubDate>
          <category>Neuroscience</category>
        </item></channel></rss>
        """

        let article = try #require(ResearchLibraryService.parseFeed(Data(xml.utf8)).first)

        #expect(article.categories == ["Neuroscience"])
        #expect(article.evidenceStatus == nil)
    }

    @MainActor
    @Test func researchLibrarySearchAndCategoryFiltersAreScoped() async throws {
        let migraine = try makeArticle(
            title: "Migraine prevention",
            summary: "An approved pathway.",
            slug: "migraine",
            categories: ["Neurology"]
        )
        let endometriosis = try makeArticle(
            title: "Endometriosis trial",
            summary: "Researchers are studying a diagnostic.",
            slug: "endometriosis",
            categories: ["Women's Health", "Clinical Trial"]
        )
        let model = ResearchLibraryModel(
            service: ResearchArticleLoaderStub(articles: [migraine, endometriosis])
        )

        await model.load()
        #expect(model.visibleArticles.count == 2)
        #expect(model.availableCategories == ["Clinical Trial", "Neurology", "Women's Health"])

        model.query = "diagnostic"
        #expect(model.visibleArticles.map(\.id) == [endometriosis.id])

        model.query = ""
        model.selectedCategory = "Neurology"
        #expect(model.visibleArticles.map(\.id) == [migraine.id])
    }

    @MainActor
    @Test func researchLibraryExposesFriendlyFailureState() async {
        let model = ResearchLibraryModel(
            service: ResearchArticleLoaderStub(articles: [], shouldFail: true)
        )

        await model.load()

        #expect(model.articles.isEmpty)
        #expect(model.errorMessage == "We couldn’t load the Research Library. Check your connection and try again.")
        #expect(model.isLoading == false)
    }

    @MainActor
    @Test func researchLibraryHandlesEmptyResults() async {
        let model = ResearchLibraryModel(service: ResearchArticleLoaderStub(articles: []))

        await model.load()

        #expect(model.articles.isEmpty)
        #expect(model.visibleArticles.isEmpty)
        #expect(model.errorMessage == nil)
    }

    private func makeArticle(
        title: String,
        summary: String,
        slug: String,
        categories: [String]
    ) throws -> ResearchArticle {
        ResearchArticle(
            title: title,
            summary: summary,
            author: "VIDA LAB",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            canonicalURL: try #require(URL(string: "https://vidalab.substack.com/p/\(slug)")),
            thumbnailURL: nil,
            categories: categories
        )
    }
}

/// Guards the passphrase escrow, which the website depends on to derive the
/// same key in a browser. A silent change to any parameter here doesn't fail
/// on this platform — it fails as "the web can no longer read anything".
///
/// Serialised because every case here reads and writes the same global
/// Keychain item; running them in parallel tests the Keychain, not the escrow.
@Suite(.serialized)
struct VidaKeyEscrowTests {
    /// Locks the KDF to a known-answer vector.
    ///
    /// Cross-checked against an independent PBKDF2 implementation, so if this
    /// ever drifts the fault is here and not in the browser.
    @Test func derivationMatchesKnownVector() throws {
        let salt = Data((0..<16).map { UInt8($0) })
        let key = try VidaKeyEscrow.deriveKey(
            passphrase: "correct horse battery",
            salt: salt,
            iterations: 10_000
        )
        let hex = key.withUnsafeBytes { Data($0) }
            .map { String(format: "%02x", $0) }
            .joined()

        #expect(hex == "5fe0c82de56e5fd98d1c202f10378395aaae0985130fbadd92465776c0b297f4")
    }

    @Test func wrappedKeyRoundTripsToTheDeviceKey() throws {
        let wrapped = try VidaKeyEscrow.wrapCurrentKey(
            passphrase: "a good long passphrase",
            iterations: 20_000
        )

        #expect(wrapped.kdf == VidaKeyEscrow.kdfIdentifier)
        #expect(try VidaKeyEscrow.unwrap(wrapped, passphrase: "a good long passphrase")
                == VidaCrypto.exportKeyMaterial())
    }

    @Test func wrongPassphraseIsRejected() throws {
        let wrapped = try VidaKeyEscrow.wrapCurrentKey(
            passphrase: "a good long passphrase",
            iterations: 20_000
        )

        #expect(throws: VidaKeyEscrow.EscrowError.wrongPassphrase) {
            try VidaKeyEscrow.unwrap(wrapped, passphrase: "a good long passphrasE")
        }
    }

    /// A flipped bit in the auth tag has to fail closed. Without this the
    /// scheme would trust whatever the server handed back.
    @Test func tamperedRecordIsRejected() throws {
        var wrapped = try VidaKeyEscrow.wrapCurrentKey(
            passphrase: "a good long passphrase",
            iterations: 20_000
        )
        var raw = try #require(Data(base64Encoded: wrapped.wrappedKey))
        raw[raw.count - 1] ^= 0x01
        wrapped.wrappedKey = raw.base64EncodedString()

        #expect(!VidaKeyEscrow.verifies(wrapped, passphrase: "a good long passphrase"))
    }

    /// The same passphrase typed on two platforms can arrive as different
    /// bytes unless both normalise. Browsers must call `.normalize("NFC")`.
    @Test func normalisationMakesEquivalentTextInterchangeable() throws {
        let composed = "café passphrase"
        let decomposed = "cafe\u{0301} passphrase"
        #expect(Array(composed.utf8) != Array(decomposed.utf8))

        let wrapped = try VidaKeyEscrow.wrapCurrentKey(passphrase: composed, iterations: 20_000)
        #expect(VidaKeyEscrow.verifies(wrapped, passphrase: decomposed))
    }

    @Test func shortPassphraseIsRefused() {
        #expect(throws: VidaKeyEscrow.EscrowError.passphraseTooShort) {
            try VidaKeyEscrow.wrapCurrentKey(passphrase: "short")
        }
    }

    /// The envelope layout the web side slices by hand: 12-byte nonce, then
    /// ciphertext, then a 16-byte tag.
    @Test func wrappedEnvelopeHasTheDocumentedLayout() throws {
        let wrapped = try VidaKeyEscrow.wrapCurrentKey(
            passphrase: "a good long passphrase",
            iterations: 20_000
        )
        let combined = try #require(Data(base64Encoded: wrapped.wrappedKey))
        let salt = try #require(Data(base64Encoded: wrapped.salt))

        #expect(salt.count == VidaKeyEscrow.saltByteCount)
        #expect(combined.count == 12 + 32 + 16)
    }
}

/// Guards who gets asked about a cycle.
///
/// The failure mode here is quiet in both directions: a member who has no
/// cycle being asked about bleeding every day, or an existing member losing a
/// card she has used daily because a new field defaulted the wrong way.
struct CycleGatingTests {
    @Test func unansweredProfileKeepsCycle() {
        // Everyone saw cycle signals before Vida asked the question, so an
        // unanswered profile has to keep them.
        let profile = HealthProfile()

        #expect(profile.cycleTracking == nil)
        #expect(profile.tracksCycle)
        #expect(profile.includes(.cycle))
    }

    @Test func notTrackingRemovesCycleOnly() {
        var profile = HealthProfile()
        profile.cycleTracking = .notTracking

        #expect(!profile.tracksCycle)
        #expect(!profile.includes(.cycle))
        // Nothing else may be caught by the filter.
        for category in SignalCategory.checkInSet where category != .cycle {
            #expect(profile.includes(category))
        }
    }

    @Test func pausedCycleIsTreatedAsNotTracking() {
        var profile = HealthProfile()
        profile.cycleTracking = .notRightNow

        #expect(!profile.tracksCycle)
    }

    /// Sex must never be the thing that decides this — a female member with
    /// no cycle is exactly the case gating on sex gets wrong.
    @Test func sexDoesNotDecideCycleGating() {
        var profile = HealthProfile()
        profile.biologicalSex = .female
        profile.cycleTracking = .notTracking
        #expect(!profile.tracksCycle)

        var other = HealthProfile()
        other.biologicalSex = .male
        other.cycleTracking = .tracking
        #expect(other.tracksCycle)
    }

    /// Conditions and goals both list `.cycle` among their priorities, so the
    /// ordering is a second way it can arrive on a check-in.
    @Test func focusSignalsDropCycleWhenNotTracked() {
        var profile = HealthProfile()
        profile.conditionIDs = ["endometriosis"]
        profile.goals = [.prepareAppointments]

        #expect(profile.focusSignals.contains(.cycle))

        profile.cycleTracking = .notTracking
        #expect(!profile.focusSignals.contains(.cycle))
        #expect(profile.focusSignals.contains(.pain))
    }

    /// Every profile can reach every condition. Sex is not a reliable guide to
    /// what somebody needs to log, and the members most often misdiagnosed are
    /// exactly the ones a filter used to shut out.
    @Test func everyProfileCanReachTheWholeCatalogue() {
        for sex in [BiologicalSex.male, .female, .intersex, .preferNotToSay] {
            let ordered = HealthCondition.catalog(orderedFor: sex)
            #expect(ordered.count == HealthCondition.catalog.count)

            let ids = Set(ordered.map(\.id))
            #expect(ids.contains("endometriosis"))
            #expect(ids.contains("low-testosterone"))
            #expect(ids.contains("undiagnosed"))
        }
    }

    /// Order is the only thing sex is allowed to affect.
    @Test func likelyRelevantConditionsLeadTheOrdering() throws {
        func position(of id: String, for sex: BiologicalSex) throws -> Int {
            let ordered = HealthCondition.catalog(orderedFor: sex)
            return try #require(ordered.firstIndex { $0.id == id })
        }

        let maleTestosterone = try position(of: "low-testosterone", for: .male)
        let maleEndometriosis = try position(of: "endometriosis", for: .male)
        #expect(maleTestosterone < maleEndometriosis)

        let femaleEndometriosis = try position(of: "endometriosis", for: .female)
        let femaleTestosterone = try position(of: "low-testosterone", for: .female)
        #expect(femaleEndometriosis < femaleTestosterone)
    }

    /// Ordering must not break lookup of something already saved, or a
    /// member's recorded condition would vanish from her profile.
    @Test func orderingNeverHidesASavedCondition() {
        #expect(HealthCondition.find("endometriosis") != nil)

        var profile = HealthProfile()
        profile.biologicalSex = .male
        profile.conditionIDs = ["endometriosis"]

        #expect(profile.conditions.map(\.name) == ["Endometriosis"])
    }

    @Test func undisclosedSexSeesTheWholeCatalogue() {
        #expect(HealthCondition.catalog(orderedFor: nil).count == HealthCondition.catalog.count)
        #expect(HealthCondition.catalog(orderedFor: .preferNotToSay).count == HealthCondition.catalog.count)
        #expect(HealthCondition.catalog(orderedFor: .intersex).count == HealthCondition.catalog.count)
    }
}

/// Guards who gets shown which answers.
///
/// Suggestions are the app's opening move, so getting these wrong is the most
/// visible way the expansion past women's health could fail.
struct AskLibraryTargetingTests {
    @Test func maleSuggestionsAreNotAboutPeriods() {
        let questions = AskVidaLibrary.suggested(for: .male)

        #expect(!questions.isEmpty)
        for question in questions {
            #expect(!question.lowercased().contains("period"))
            #expect(!question.lowercased().contains("ovulation"))
        }
    }

    @Test func femaleSuggestionsStillLeadWithCycleAnswers() {
        let questions = AskVidaLibrary.suggested(for: .female)

        #expect(questions.contains { $0.lowercased().contains("period") })
    }

    /// Every suggestion has to resolve to a citable answer, or tapping it
    /// produces the "no researched answer" card from a prompt Vida offered.
    @Test func everySuggestionResolvesToACitedAnswer() throws {
        for sex in [BiologicalSex.male, .female, .intersex, .preferNotToSay] {
            for question in AskVidaLibrary.suggested(for: sex) {
                #expect(
                    AskVidaLibrary.citedMatch(for: question) != nil,
                    "\(sex.rawValue) was offered a question with no cited answer: \(question)"
                )
            }
        }
    }

    /// Suggestions narrow, but search must not — someone reading up on a
    /// partner still deserves the real answer.
    @Test func searchIsNotRestrictedBySex() {
        let match = AskVidaLibrary.bestMatch(for: "why am I so exhausted during my period")

        #expect(match?.id == "period-exhaustion")
    }

    @Test func maleAnswersExistAndAreCited() throws {
        let maleAnswers = AskVidaLibrary.answers.filter { $0.relevance == .male }

        #expect(maleAnswers.count >= 5)
        for answer in maleAnswers {
            let articleID = try #require(answer.articleID)
            let article = try #require(ScienceLibrary.article(id: articleID))
            #expect(!article.citations.isEmpty)
        }
    }

    /// Conditions reference articles by id, and a dangling one silently
    /// produces a condition whose Library recommendations are empty.
    @Test func everyConditionArticleResolves() throws {
        for condition in HealthCondition.catalog {
            for id in condition.articleIDs {
                #expect(
                    ScienceLibrary.article(id: id) != nil,
                    "\(condition.id) references a missing article: \(id)"
                )
            }
        }
    }

    @Test func refusalAlternativesRespectSex() {
        let refusal = AskGuardrails.scopeRefusal(for: "do i have endometriosis", sex: .male)

        let alternatives = refusal?.alternatives ?? []
        #expect(!alternatives.isEmpty)
        for question in alternatives {
            #expect(!question.lowercased().contains("period"))
        }
    }
}

/// Guards the sleep-and-mood timeline.
///
/// The failure that matters is silent: pairing a night's sleep with the wrong
/// day's mood still draws a convincing chart, and the whole point of the view
/// is reading one against the other.
struct SleepMoodChartTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ offset: Int) -> Date {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        return calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: offset, to: base) ?? base
        )
    }

    @Test func mergePairsReadingsByDay() throws {
        let points = SleepMoodPoint.merge(
            sleep: [(day(0), 7.5), (day(1), 6.0)],
            mood: [(day(0), 8), (day(1), 5)],
            calendar: calendar
        )

        #expect(points.count == 2)
        #expect(points[0].sleepHours == 7.5)
        #expect(points[0].mood == 8)
        #expect(points.filter(\.isPaired).count == 2)
    }

    /// A missed evening check-in must not slide every later mood back a day.
    @Test func missingDayDoesNotShiftTheOtherSeries() throws {
        let points = SleepMoodPoint.merge(
            sleep: [(day(0), 7), (day(1), 6), (day(2), 8)],
            mood: [(day(0), 4), (day(2), 9)],
            calendar: calendar
        )

        #expect(points.count == 3)
        #expect(points[1].sleepHours == 6)
        #expect(points[1].mood == nil)
        #expect(!points[1].isPaired)
        // The day-2 mood stays on day 2 rather than sliding onto day 1.
        #expect(points[2].mood == 9)
    }

    @Test func pointsAreSortedOldestFirst() throws {
        let points = SleepMoodPoint.merge(
            sleep: [(day(5), 7), (day(1), 6), (day(3), 8)],
            mood: [],
            calendar: calendar
        )

        #expect(points.map(\.date) == [day(1), day(3), day(5)])
    }

    /// Readings logged at different times of day belong to the same point.
    @Test func differentTimesOnOneDayCollapseTogether() throws {
        let morning = day(0).addingTimeInterval(7 * 3600)
        let evening = day(0).addingTimeInterval(21 * 3600)

        let points = SleepMoodPoint.merge(
            sleep: [(morning, 7)],
            mood: [(evening, 6)],
            calendar: calendar
        )

        #expect(points.count == 1)
        #expect(points[0].isPaired)
    }

    @Test func emptyInputProducesNoPoints() {
        #expect(SleepMoodPoint.merge(sleep: [], mood: [], calendar: calendar).isEmpty)
    }
}

/// Guards the community wire format.
///
/// The server withholds `author_id` by column grant, so the risk here is not
/// leaking it — it is decoding. A category the server knows and this build
/// doesn't must not empty somebody's feed.
struct CommunityTests {
    private func decodePost(_ json: String) throws -> CommunityPost {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CommunityPost.self, from: Data(json.utf8))
    }

    @Test func postDecodesFromTheServerShape() throws {
        let post = try decodePost("""
        {
          "id": "8B1E8E3E-4C0A-4A0E-9C1E-2F6D1B0A7C21",
          "display_name": "Anonymous",
          "title": "How do you manage brain fog?",
          "body": "Foggy mornings, every day this week.",
          "category": "chronic_conditions",
          "status": "active",
          "flagged": false,
          "created_at": "2026-09-20T12:00:00Z"
        }
        """)

        #expect(post.displayName == "Anonymous")
        #expect(post.category == .chronicConditions)
        #expect(post.status == .active)
        #expect(!post.flagged)
    }

    /// Snake case on the wire, camel case in Swift. A mismatch here silently
    /// files every conditions post under Other.
    @Test func categoryWireValuesRoundTrip() {
        for category in CommunityCategory.allCases {
            #expect(CommunityCategory(wireValue: category.wireValue) == category)
        }
        #expect(CommunityCategory.chronicConditions.wireValue == "chronic_conditions")
    }

    @Test func unknownCategoryFallsBackRatherThanFailing() throws {
        let post = try decodePost("""
        {
          "id": "8B1E8E3E-4C0A-4A0E-9C1E-2F6D1B0A7C21",
          "display_name": "Anonymous",
          "title": "A title",
          "body": "A body.",
          "category": "something_added_later",
          "status": "active",
          "flagged": false,
          "created_at": "2026-09-20T12:00:00Z"
        }
        """)

        #expect(post.category == .other)
    }

    @Test func unknownStatusIsTreatedAsActive() throws {
        let post = try decodePost("""
        {
          "id": "8B1E8E3E-4C0A-4A0E-9C1E-2F6D1B0A7C21",
          "display_name": "Anonymous",
          "title": "A title",
          "body": "A body.",
          "category": "sleep",
          "status": "archived",
          "flagged": false,
          "created_at": "2026-09-20T12:00:00Z"
        }
        """)

        #expect(post.status == .active)
    }

    /// The insert payload must carry exactly the columns the insert grant
    /// allows. Sending `status` or `id` fails the grant, not a check.
    @Test func newPostEncodesOnlyGrantedColumns() throws {
        let draft = NewCommunityPost(
            authorID: "user-1",
            displayName: "Anonymous",
            title: "A title",
            body: "A body.",
            category: "sleep"
        )
        let data = try JSONEncoder().encode(draft)
        let object = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(Set(object.keys) == ["author_id", "display_name", "title", "body", "category"])
    }

    /// These names are the `block_community_author` signature. A rename on
    /// either side fails as "function does not exist", which is a confusing
    /// way to discover that blocking is broken.
    @Test func blockRequestUsesTheFunctionParameterNames() throws {
        let data = try JSONEncoder().encode(
            BlockAuthorRequest(postID: UUID(), replyID: nil)
        )
        let object = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(object["p_post_id"] != nil)
        // Encoded rather than omitted: the function distinguishes "block this
        // reply" from "block this post" by which argument is null, and relies
        // on its own defaults only when a key is genuinely absent.
        #expect(Set(object.keys).isSubset(of: ["p_post_id", "p_reply_id"]))
    }

    /// Guideline 1.2 pre-post filtering. The allowed cases matter as much as
    /// the blocked ones: a filter that refuses people describing their own
    /// symptoms would be worse than none.
    @Test func contentFilterBlocksAbuseContactsAndLinks() {
        #expect(CommunityLimits.contentRejection("honestly kys") != nil)
        #expect(CommunityLimits.contentRejection("You absolute Bitch") != nil)
        #expect(CommunityLimits.contentRejection("email me at sam@example.com") != nil)
        #expect(CommunityLimits.contentRejection("call 555-123-4567 for help") != nil)
        #expect(CommunityLimits.contentRejection("try https://cheapsupplements.shop") != nil)
        #expect(CommunityLimits.contentRejection("buy it at bestherbs.com") != nil)
    }

    @Test func contentFilterAllowsOrdinaryHealthTalk() {
        #expect(CommunityLimits.contentRejection("This cramping is killing me every month.") == nil)
        #expect(CommunityLimits.contentRejection("I take 200 mg twice a day, started 03/14.") == nil)
        #expect(CommunityLimits.contentRejection("My doctor said it was just stress. It wasn't.") == nil)
        #expect(CommunityLimits.contentRejection("Brain fog is worst between 2 and 4pm.") == nil)
    }

    @Test func postValidationRunsTheContentFilter() {
        #expect(CommunityLimits.validationMessage(title: "Help please", body: "text me 07700 900123") != nil)
        #expect(CommunityLimits.validationMessage(title: "Help please", body: "Anyone else get flares in winter?") == nil)
    }

    @Test func blankDisplayNameBecomesAnonymous() {
        #expect(CommunityLimits.normalisedDisplayName("   ") == "Anonymous")
        #expect(CommunityLimits.normalisedDisplayName("") == "Anonymous")
        #expect(CommunityLimits.normalisedDisplayName("  Rowan ") == "Rowan")
    }

    @Test func displayNameIsTruncatedToTheColumnLimit() {
        let long = String(repeating: "a", count: 200)
        #expect(CommunityLimits.normalisedDisplayName(long).count == CommunityLimits.displayNameLimit)
    }

    /// The app should refuse what the CHECK constraints would refuse, so a
    /// member gets a sentence rather than a Postgres error.
    @Test func validationMirrorsTheDatabaseConstraints() {
        #expect(CommunityLimits.validationMessage(title: "ab", body: "fine") != nil)
        #expect(CommunityLimits.validationMessage(title: "a good title", body: "  ") != nil)
        #expect(CommunityLimits.validationMessage(
            title: String(repeating: "a", count: 200), body: "fine") != nil)
        #expect(CommunityLimits.validationMessage(
            title: "a good title", body: String(repeating: "a", count: 6000)) != nil)
        #expect(CommunityLimits.validationMessage(title: "a good title", body: "fine") == nil)
    }

    @Test func previewCollapsesNewlinesAndTruncates() {
        let post = CommunityPost(
            id: UUID(),
            displayName: "Anonymous",
            title: "Title",
            body: "First line.\nSecond line.",
            category: .general,
            createdAt: Date()
        )

        #expect(post.preview == "First line. Second line.")

        let long = CommunityPost(
            id: UUID(),
            displayName: "Anonymous",
            title: "Title",
            body: String(repeating: "a", count: 300),
            category: .general,
            createdAt: Date()
        )

        #expect(long.preview.hasSuffix("…"))
        #expect(long.preview.count == 141)
    }
}

/// Guards the `check_ins.local_date` key against the time zone it is written in.
///
/// This is half of a unique key the website is about to share, so a client
/// that disagrees about which day a check-in belongs to duplicates or clobbers
/// rows rather than failing visibly.
struct VidaDateKeyTests {

    private func key(_ zone: String, _ year: Int, _ month: Int, _ day: Int, hour: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        let moment = calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour)
        )!
        return VidaDateKey.string(from: moment, calendar: calendar)
    }

    /// The day she would say it was, in the zone she was standing in.
    ///
    /// The old implementation formatted local midnight through a UTC
    /// formatter, landing a day early everywhere with a positive offset. That
    /// was most of the world: all of continental Europe, and the UK for the
    /// seven months of British Summer Time.
    @Test func keyMatchesTheLocalCalendarDayEverywhere() {
        let zones = [
            "America/Los_Angeles", "America/New_York", "UTC",
            "Europe/London", "Europe/Paris", "Europe/Berlin",
            "Africa/Lagos", "Asia/Dubai", "Asia/Tokyo",
            "Australia/Sydney", "Pacific/Auckland"
        ]

        for zone in zones {
            // Midnight is the boundary the bug fell off.
            #expect(key(zone, 2026, 7, 20, hour: 0) == "2026-07-20", "\(zone) at midnight")
            #expect(key(zone, 2026, 7, 20, hour: 9) == "2026-07-20", "\(zone) in the morning")
            #expect(key(zone, 2026, 7, 20, hour: 23) == "2026-07-20", "\(zone) late at night")
        }
    }

    /// The UK crossed in and out of the bug twice a year, so January and July
    /// keyed differently for the same member. Both must be right now.
    @Test func britishSummerTimeKeysTheSameWayAsWinter() {
        #expect(key("Europe/London", 2026, 1, 20, hour: 0) == "2026-01-20")
        #expect(key("Europe/London", 2026, 7, 20, hour: 0) == "2026-07-20")
    }

    @Test func keyPadsSingleDigitMonthsAndDays() {
        #expect(key("Europe/Paris", 2026, 3, 7, hour: 12) == "2026-03-07")
    }

    /// Sorting `local_date` as text has to order chronologically, because the
    /// restore query relies on it to pick the freshest row for a day.
    @Test func keysSortChronologicallyAsText() {
        let ordered = [
            key("Asia/Tokyo", 2026, 1, 9, hour: 9),
            key("Asia/Tokyo", 2026, 1, 10, hour: 9),
            key("Asia/Tokyo", 2026, 2, 1, hour: 9),
            key("Asia/Tokyo", 2026, 12, 31, hour: 9)
        ]
        #expect(ordered == ordered.sorted())
    }
}

/// Guards that meals ride the same encrypted path as everything else.
///
/// Meals were local-only at first, which meant a lost phone restored every
/// check-in and no food at all. These cover the seal, and the fact that what
/// someone ate is never legible to the server.
@Suite(.serialized)
struct MealSyncTests {
    @Test func mealSurvivesTheEncryptedRoundTrip() throws {
        let meal = MealEntry(
            date: Date(timeIntervalSince1970: 1_758_384_000),
            kind: .breakfast,
            name: "Porridge and berries",
            note: "with the good yoghurt",
            howItSat: 8
        )

        let sealed = try VidaCrypto.encrypt(meal)
        let opened = try VidaCrypto.decrypt(MealEntry.self, from: sealed)

        #expect(opened == meal)
        #expect(opened.howItSat == 8)
    }

    /// The ciphertext must not leak the meal name. If this ever fails, the
    /// payload is going up in something other than sealed form.
    @Test func ciphertextDoesNotContainTheMealName() throws {
        let meal = MealEntry(name: "Porridge and berries", note: "with the good yoghurt")
        let sealed = try VidaCrypto.encrypt(meal)

        #expect(!sealed.lowercased().contains("porridge"))
        #expect(!sealed.lowercased().contains("yoghurt"))
    }

    /// Restore is additive. A meal logged on the new phone before sync lands
    /// must not be replaced or dropped by the cloud copy.
    @Test @MainActor func restoringMealsNeverDropsLocalOnes() {
        let store = VidaStore(persistent: false)
        let local = MealEntry(name: "Toast")
        store.meals = [local]

        let fromCloud = MealEntry(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            name: "Soup"
        )
        store.absorbRestored(
            logs: [],
            meals: [fromCloud],
            experiments: [],
            preps: [],
            savedArticleIDs: []
        )

        #expect(store.meals.count == 2)
        #expect(store.meals.contains { $0.id == local.id })
        #expect(store.meals.contains { $0.id == fromCloud.id })
    }

    /// Deleting has to leave a marker behind, or the deletion is the one edit
    /// that never reaches the member's other device.
    @Test @MainActor func deletingAReadingQueuesATombstone() {
        let store = VidaStore(persistent: false)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        var reading = SignalReading(category: .energy, value: 4)
        reading.period = .morning
        store.logs = [DayLog(date: day, readings: [reading])]

        store.deleteReading(reading, on: day)

        #expect(store.logs.isEmpty)
        #expect(store.pendingDeletions.count == 1)
        #expect(store.pendingDeletions.first?.category == .energy)
        #expect(store.pendingDeletions.first?.period == .morning)
    }

    /// Deleting a whole day has to mark every reading in it, because the event
    /// stream retires one reading at a time.
    @Test @MainActor func deletingADayQueuesOneTombstonePerReading() {
        let store = VidaStore(persistent: false)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        var morning = SignalReading(category: .sleep, value: 7)
        morning.period = .morning
        var evening = SignalReading(category: .mood, value: 5)
        evening.period = .evening
        store.logs = [DayLog(date: day, readings: [morning, evening])]

        store.deleteDay(day)

        #expect(store.pendingDeletions.count == 2)
        #expect(store.pendingDeletions.contains { $0.category == .sleep && $0.period == .morning })
        #expect(store.pendingDeletions.contains { $0.category == .mood && $0.period == .evening })
    }

    /// Restore runs before push. An unpushed deletion must survive the server
    /// still holding the reading, or it comes straight back.
    @Test @MainActor func pendingDeletionSurvivesARestoreThatStillHasTheReading() {
        let store = VidaStore(persistent: false)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        var reading = SignalReading(category: .energy, value: 4)
        reading.period = .morning
        reading.recordedAt = day
        store.logs = [DayLog(date: day, readings: [reading])]

        store.deleteReading(reading, on: day)
        #expect(store.logs.isEmpty)

        // The other device's copy, recorded before the deletion.
        store.mergeSyncedCheckInReadings([
            SyncedCheckInReading(date: day, reading: reading, updatedAt: day, isDeleted: false)
        ])

        #expect(store.logs.isEmpty)
    }

    /// A newer edit from elsewhere still wins — the guard is about ordering,
    /// not about making a local delete permanent.
    @Test @MainActor func editMadeAfterTheDeletionStillArrives() {
        let store = VidaStore(persistent: false)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        var reading = SignalReading(category: .energy, value: 4)
        reading.period = .morning
        reading.recordedAt = day
        store.logs = [DayLog(date: day, readings: [reading])]

        store.deleteReading(reading, on: day)

        var relogged = reading
        relogged.value = 9
        store.mergeSyncedCheckInReadings([
            SyncedCheckInReading(
                date: day,
                reading: relogged,
                updatedAt: Date(),
                isDeleted: false
            )
        ])

        #expect(store.logs.first?.readings.first?.value == 9)
    }

    /// Clearing happens only after a confirmed push, and only for the markers
    /// that went up.
    @Test @MainActor func clearingOnlyDropsTheMarkersThatWerePushed() {
        let store = VidaStore(persistent: false)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        var first = SignalReading(category: .energy, value: 4)
        first.period = .morning
        var second = SignalReading(category: .mood, value: 6)
        second.period = .evening
        store.logs = [DayLog(date: day, readings: [first, second])]

        store.deleteReading(first, on: day)
        store.deleteReading(second, on: day)
        #expect(store.pendingDeletions.count == 2)

        let pushed = store.pendingDeletions.filter { $0.category == .energy }
        store.clearPendingDeletions(pushed)

        #expect(store.pendingDeletions.count == 1)
        #expect(store.pendingDeletions.first?.category == .mood)
    }
}

/// Guards meal counting and the monthly recap.
///
/// Favourites are the one number in Lab Notes a member can check by memory,
/// so getting "you ate porridge 6 times" wrong is immediately visible.
struct LabNotesTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9)) ?? Date()
    }

    private func meal(_ name: String, _ day: Int, comfort: Int? = nil) -> MealEntry {
        MealEntry(date: date(2026, 8, day), name: name, howItSat: comfort)
    }

    // MARK: - Grouping

    @Test func spellingVariantsCountAsOneMeal() {
        let meals = [
            meal("Porridge", 1), meal("porridge", 2), meal("  PORRIDGE  ", 3), meal("Toast", 4)
        ]

        let favourites = MealInsights.favourites(in: meals)

        #expect(favourites.count == 2)
        #expect(favourites[0].count == 3)
        #expect(favourites[1].name == "Toast")
    }

    /// The spelling shown back is the one used most, not the normalised key.
    @Test func favouriteUsesTheMostCommonSpelling() {
        let meals = [
            meal("porridge and berries", 1),
            meal("Porridge and berries", 2),
            meal("Porridge and berries", 3)
        ]

        #expect(MealInsights.favourites(in: meals).first?.name == "Porridge and berries")
    }

    @Test func punctuationDoesNotSplitAMeal() {
        let meals = [meal("Porridge!", 1), meal("porridge", 2)]

        #expect(MealInsights.favourites(in: meals).count == 1)
    }

    /// A recap that reshuffles between openings looks broken.
    @Test func equalCountsOrderAlphabetically() {
        let meals = [meal("Toast", 1), meal("Apple", 2)]

        #expect(MealInsights.favourites(in: meals).map(\.name) == ["Apple", "Toast"])
    }

    @Test func comfortAveragesOnlyOverRatedMeals() throws {
        let meals = [meal("Toast", 1, comfort: 8), meal("Toast", 2), meal("Toast", 3, comfort: 4)]

        let tally = try #require(MealInsights.favourites(in: meals).first)
        #expect(tally.count == 3)
        #expect(tally.averageComfort == 6)
    }

    @Test func unratedMealsHaveNoComfortScore() throws {
        let tally = try #require(MealInsights.favourites(in: [meal("Toast", 1)]).first)
        #expect(tally.averageComfort == nil)
    }

    @Test func emptyNamesAreIgnored() {
        #expect(MealInsights.favourites(in: [meal("   ", 1)]).isEmpty)
    }

    // MARK: - Meal kind

    @Test func mealKindIsGuessedFromTheClock() {
        func at(_ hour: Int) -> MealKind {
            let stamp = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: hour))!
            return MealKind.likely(at: stamp, calendar: calendar)
        }

        #expect(at(8) == .breakfast)
        #expect(at(13) == .lunch)
        #expect(at(19) == .dinner)
        #expect(at(23) == .snack)
    }

    // MARK: - Recap

    private func logs(days: [Int], value: Double = 5) -> [DayLog] {
        days.map { day in
            DayLog(
                date: calendar.startOfDay(for: date(2026, 8, day)),
                readings: [SignalReading(category: .energy, value: value, period: .morning)]
            )
        }
    }

    /// A month with almost nothing in it isn't a recap, and pretending
    /// otherwise makes the app look like it wasn't paying attention.
    @Test func thinMonthProducesNoRecap() {
        let notes = LabNotesEngine.build(
            month: date(2026, 8, 15),
            logs: logs(days: [1, 2]),
            meals: [],
            experiments: [],
            links: [],
            profile: HealthProfile(),
            calendar: calendar
        )

        #expect(notes == nil)
    }

    @Test func recapCountsOnlyThatMonthsDays() throws {
        var august = logs(days: Array(1...10))
        august.append(contentsOf: [
            DayLog(
                date: calendar.startOfDay(for: date(2026, 9, 3)),
                readings: [SignalReading(category: .energy, value: 5, period: .morning)]
            )
        ])

        let notes = try #require(
            LabNotesEngine.build(
                month: date(2026, 8, 15),
                logs: august,
                meals: [],
                experiments: [],
                links: [],
                profile: HealthProfile(),
                calendar: calendar
            )
        )

        #expect(notes.checkInDays == 10)
        #expect(notes.daysInMonth == 31)
    }

    @Test func recapAlwaysOpensAndClosesWithACard() throws {
        let notes = try #require(
            LabNotesEngine.build(
                month: date(2026, 8, 15),
                logs: logs(days: Array(1...10)),
                meals: [],
                experiments: [],
                links: [],
                profile: HealthProfile(),
                calendar: calendar
            )
        )

        #expect(notes.cards.first?.kind == .consistency)
        #expect(notes.cards.last?.kind == .closing)
    }

    /// A meal logged once isn't a favourite, and calling it one is the kind
    /// of thin claim that makes the whole recap feel invented.
    @Test func singleMealDoesNotBecomeAFavouriteCard() throws {
        let notes = try #require(
            LabNotesEngine.build(
                month: date(2026, 8, 15),
                logs: logs(days: Array(1...10)),
                meals: [meal("Toast", 2)],
                experiments: [],
                links: [],
                profile: HealthProfile(),
                calendar: calendar
            )
        )

        #expect(!notes.cards.contains { $0.kind == .meal })
    }

    @Test func repeatedMealBecomesACard() throws {
        let notes = try #require(
            LabNotesEngine.build(
                month: date(2026, 8, 15),
                logs: logs(days: Array(1...10)),
                meals: [meal("Toast", 2), meal("toast", 4), meal("Toast", 6)],
                experiments: [],
                links: [],
                profile: HealthProfile(),
                calendar: calendar
            )
        )

        let card = try #require(notes.cards.first { $0.kind == .meal })
        #expect(card.headline == "Toast")
        #expect(card.detail.contains("3 times"))
    }

    // MARK: - Tone

    /// Signal movement is reported, never graded.
    ///
    /// This is a product principle rather than a mechanism, which is exactly
    /// the kind of thing that regresses quietly: an earlier version called a
    /// rising energy score "Better, on average", and nothing failed. For an
    /// app used by people managing chronic illness, a recap that praises a
    /// good month is also one that blames a bad one.
    @Test func signalCardsNeverGradeTheMonth() throws {
        // Energy climbing hard in the second half — the case most likely to
        // tempt a compliment.
        var rising: [DayLog] = []
        for day in 1...14 {
            rising.append(
                DayLog(
                    date: calendar.startOfDay(for: date(2026, 8, day)),
                    readings: [
                        SignalReading(category: .energy, value: day <= 7 ? 3 : 8, period: .morning)
                    ]
                )
            )
        }

        let notes = try #require(
            LabNotesEngine.build(
                month: date(2026, 8, 15),
                logs: rising,
                meals: [],
                experiments: [],
                links: [],
                profile: HealthProfile(),
                calendar: calendar
            )
        )

        let card = try #require(notes.cards.first { $0.kind == .signal })
        #expect(card.eyebrow == "Energy rose")

        let verdicts = ["better", "worse", "good", "bad", "well done", "great", "improved"]
        let text = (card.eyebrow + " " + card.detail).lowercased()
        for verdict in verdicts {
            #expect(!text.contains(verdict), "signal card graded the month: \(text)")
        }
    }

    /// "Eased" reads as relief. Correct for pain, wrong for energy — so the
    /// falling verb has to be neutral across every signal.
    @Test func fallingSignalsUseANeutralVerb() throws {
        var falling: [DayLog] = []
        for day in 1...14 {
            falling.append(
                DayLog(
                    date: calendar.startOfDay(for: date(2026, 8, day)),
                    readings: [
                        SignalReading(category: .energy, value: day <= 7 ? 8 : 3, period: .morning)
                    ]
                )
            )
        }

        let notes = try #require(
            LabNotesEngine.build(
                month: date(2026, 8, 15),
                logs: falling,
                meals: [],
                experiments: [],
                links: [],
                profile: HealthProfile(),
                calendar: calendar
            )
        )

        let card = try #require(notes.cards.first { $0.kind == .signal })
        #expect(card.eyebrow == "Energy fell")
        #expect(!card.eyebrow.lowercased().contains("eased"))
    }

    /// Cycle must stay out of the recap for someone with no cycle, the same
    /// as everywhere else.
    @Test func recapRespectsCycleGating() throws {
        var profile = HealthProfile()
        profile.cycleTracking = .notTracking

        var cycleLogs: [DayLog] = []
        for day in 1...12 {
            cycleLogs.append(
                DayLog(
                    date: calendar.startOfDay(for: date(2026, 8, day)),
                    readings: [
                        SignalReading(category: .cycle, value: day <= 6 ? 1 : 8, period: .morning)
                    ]
                )
            )
        }

        let notes = LabNotesEngine.build(
            month: date(2026, 8, 15),
            logs: cycleLogs,
            meals: [],
            experiments: [],
            links: [],
            profile: profile,
            calendar: calendar
        )

        let cards = notes?.cards ?? []
        #expect(!cards.contains { $0.symbol == SignalCategory.cycle.symbol })
    }
}

private struct ResearchArticleLoaderStub: ResearchArticleLoading {
    let articles: [ResearchArticle]
    var shouldFail = false

    func loadArticles(forceRefresh: Bool) async throws -> [ResearchArticle] {
        if shouldFail {
            throw ResearchLibraryError.invalidResponse
        }
        return articles
    }
}
