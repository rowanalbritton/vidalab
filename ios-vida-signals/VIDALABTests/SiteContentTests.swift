import Foundation
import Testing
@testable import VIDALAB

struct SiteContentTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    // MARK: Apothecary rows as the Base44 import left them

    @Test func apothecaryAcceptsANumericDurationAndAJSONTagList() throws {
        let item = try decode(ApothecaryItem.self, """
        {"id":"a","title":"3-Minute Breathing Space","category":"meditation","subcategory":"breathing",
         "description":"A quick reset","content":"Breathe","duration_minutes":3,"difficulty":"gentle",
         "tags":["quick","stress"],"citations":null}
        """)

        #expect(item.durationMinutes == 3)
        #expect(item.tags == ["quick", "stress"])
        #expect(item.detailLine == "Breathing · 3 min · Gentle")
    }

    @Test func apothecaryAcceptsAStringDurationAndAPythonStyleTagString() throws {
        let item = try decode(ApothecaryItem.self, """
        {"id":"b","title":"Berry Smoothie","category":"recipe","subcategory":"breakfast",
         "description":"Berries","content":"Blend","duration_minutes":"5","difficulty":"easy",
         "tags":"['anti-inflammatory', 'vegan']","citations":"- [Source](https://example.com)"}
        """)

        #expect(item.durationMinutes == 5)
        #expect(item.tags == ["anti-inflammatory", "vegan"])
    }

    @Test func apothecaryToleratesMissingOptionalColumns() throws {
        let item = try decode(ApothecaryItem.self, #"{"id":"c","title":"Walk","category":"exercise"}"#)

        #expect(item.durationMinutes == nil)
        #expect(item.tags.isEmpty)
        #expect(item.detailLine.isEmpty)
    }

    @Test func apothecaryRoundTripsThroughTheOfflineCache() throws {
        let original = try decode(ApothecaryItem.self, """
        {"id":"d","title":"Tea","category":"recipe","duration_minutes":"10","tags":"['calm']"}
        """)
        let restored = try JSONDecoder().decode(ApothecaryItem.self, from: JSONEncoder().encode(original))

        #expect(restored == original)
    }

    // MARK: Condition guides

    @Test func conditionSectionsSkipEmptyColumnsAndKeepReadingOrder() throws {
        let report = try decode(ConditionReport.self, """
        {"id":"x","name":"POTS","slug":"pots","category":"cardiovascular","summary":"s",
         "overview":"o","symptoms":"  ","diagnosis":null,"treatments":"t","resources":null,
         "doctors_guide":"d","advocacy_guide":null}
        """)

        #expect(report.sections.map(\.title) == ["Overview", "Treatments", "Which specialists to see"])
        #expect(report.categoryTitle == "Cardiovascular")
        #expect(report.webURL.absoluteString == "https://vidalab.co/library/pots")
    }

    // MARK: Research papers

    @Test func paperYearDecodesFromEitherAStringOrANumber() throws {
        let text = try decode(ResearchPaper.self, #"{"id":"1","title":"A","year":"2025"}"#)
        let number = try decode(ResearchPaper.self, #"{"id":"2","title":"B","year":2024}"#)

        #expect(text.year == "2025")
        #expect(number.year == "2024")
    }

    // MARK: Specialists

    @Test func specialistLinksAreBuiltFromPartialListings() throws {
        let practice = try decode(SpecialistPractice.self, """
        {"id":"p","practice_name":"Headache Center","phone":"(407) 960-1067","website":"example.com",
         "city":"Orlando","state":"FL","zip_code":"32801"}
        """)

        #expect(practice.phoneURL?.absoluteString == "tel:4079601067")
        #expect(practice.websiteURL?.absoluteString == "https://example.com")
        #expect(practice.cityLine == "Orlando, FL 32801")
    }

    // MARK: Markdown

    @Test func markdownSplitsHeadingsListsAndParagraphs() {
        let blocks = MarkdownBlocks.blocks(from: """
        ## Common Symptoms

        - Lower back pain
        * Stiffness
        1. See a doctor

        First line
        continues here.
        """)

        #expect(blocks == [
            .heading("Common Symptoms"),
            .bullet(marker: "•", text: "Lower back pain"),
            .bullet(marker: "•", text: "Stiffness"),
            .bullet(marker: "1.", text: "See a doctor"),
            .paragraph("First line continues here."),
        ])
    }
}
