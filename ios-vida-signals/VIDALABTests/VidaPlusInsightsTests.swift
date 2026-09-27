import Foundation
import Testing
@testable import VIDALAB

struct VidaPlusInsightsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func day(_ offset: Int) -> Date {
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 9))!
        return calendar.date(byAdding: .day, value: offset, to: start)!
    }

    private func own(_ category: SignalCategory, _ value: Double, tags: [String] = [], period: CheckInPeriod = .morning, on date: Date) -> SignalReading {
        var reading = SignalReading(category: category, value: value)
        reading.source = .manual
        reading.period = period
        reading.recordedAt = date
        reading.tags = tags
        return reading
    }

    // MARK: What leaves the device

    @Test func onlyTheMembersOwnCheckInsAreSent() {
        let sample = SignalReading(category: .mood, value: 6) // sample data: no timestamp
        var imported = SignalReading(category: .sleep, value: 7)
        imported.source = .appleHealth
        imported.recordedAt = day(0)

        let logs = [
            DayLog(date: day(0), readings: [sample, imported]),
            DayLog(date: day(1), readings: [own(.energy, 6, on: day(1))]),
        ]

        let days = InsightRequest.days(from: logs, calendar: calendar)

        #expect(days.count == 1)
        #expect(days.first?.date == "2026-09-02")
        #expect(days.first?.scores == ["energy": 6])
    }

    @Test func eveningWinsAndScoresAreRoundedToOneDecimal() {
        let logs = [DayLog(date: day(0), readings: [
            own(.energy, 4, period: .morning, on: day(0)),
            own(.energy, 7.26, period: .evening, on: day(0)),
            own(.sleep, 7.449, on: day(0)),
        ])]

        let scores = InsightRequest.days(from: logs, calendar: calendar).first?.scores

        #expect(scores?["energy"] == 7.3)
        #expect(scores?["sleep"] == 7.4)
    }

    @Test func tagsAreDeduplicatedIgnoringCase() {
        let logs = [DayLog(date: day(0), readings: [
            own(.pain, 5, tags: ["Cramps", "late night"], on: day(0)),
            own(.mood, 4, tags: ["cramps"], on: day(0)),
        ])]

        #expect(InsightRequest.days(from: logs, calendar: calendar).first?.tags == ["Cramps", "late night"])
    }

    @Test func historyIsCappedAtNinetyDaysKeepingTheNewest() {
        let logs = (0..<100).map { DayLog(date: day($0), readings: [own(.energy, 5, on: day($0))]) }

        let days = InsightRequest.days(from: logs, calendar: calendar)

        #expect(days.count == 90)
        #expect(days.first?.date == "2026-09-11")
        #expect(days.last?.date == "2026-12-09")
    }

    @Test func notesNeverLeaveTheDevice() throws {
        var reading = own(.pain, 6, on: day(0))
        reading.note = "private note about my appointment"
        let request = InsightRequest(
            feature: .differential,
            today: "2026-09-27",
            checkIns: InsightRequest.days(from: [DayLog(date: day(0), readings: [reading])], calendar: calendar),
            context: InsightContext(focusAreas: [], conditions: [], tracksCycle: false, visitReason: "", conditionName: "")
        )

        let body = String(decoding: try JSONEncoder().encode(request), as: UTF8.self)

        #expect(!body.contains("private note"))
        #expect(body.contains("\"feature\":\"differential\""))
    }

    // MARK: Reading the server's reply

    @Test func aBodyWeatherReplyDecodes() throws {
        let json = """
        {"status":"ok","feature":"body_weather","generatedAt":"2026-09-27T14:03:22.512Z","result":{
          "summary":"A steadier week","patterns":["Short sleep precedes low energy"],
          "forecast":[{"day":"Today","date":"2026-09-27","energy":"moderate","mood":"steady","risk_level":"low",
            "risk_areas":[],"headline":"Even keel","why":"You slept 7 hours.","actions":["Get morning light"]}],
          "top_triggers":["Sleep under 6 hours"],"weekly_actions":["Keep bedtime steady"],"disclaimer":"Educational only."}}
        """

        let outcome = try VidaPlusInsightsService.outcome(from: Data(json.utf8), feature: .bodyWeather)

        guard case .ready(.bodyWeather(let result), let date) = outcome else {
            Issue.record("Expected a Body Weather result, got \(outcome)")
            return
        }
        #expect(result.forecast.first?.riskLevel == "low")
        #expect(result.topTriggers == ["Sleep under 6 hours"])
        #expect(date.timeIntervalSince1970 > 1_790_000_000)
    }

    @Test func aDifferentialReplyWithNoCandidatesStillDecodes() throws {
        let json = """
        {"status":"ok","result":{"summary":"Not enough to point anywhere yet","patterns":[],"differentials":[],
          "advocacy_notes":[],"next_steps":["Track head pain for two more weeks"],"disclaimer":"Not a diagnosis."}}
        """

        let outcome = try VidaPlusInsightsService.outcome(from: Data(json.utf8), feature: .differential)

        guard case .ready(.differential(let result), _) = outcome else {
            Issue.record("Expected a differential, got \(outcome)")
            return
        }
        #expect(result.differentials.isEmpty)
        #expect(result.nextSteps.count == 1)
    }

    @Test func aConciergeReplyDecodes() throws {
        let json = """
        {"status":"ok","result":{"visit_summary":"s","symptom_narrative":"I have had headaches.",
          "key_metrics":[{"label":"Head pain","value":"6 of 10 on average","context":"Most days"}],
          "questions_to_ask":["Could this be hormonal?"],"tests_to_request":[],"advocacy_script":"I'd like this noted.",
          "what_to_bring":["This summary"],"disclaimer":"d"}}
        """

        let outcome = try VidaPlusInsightsService.outcome(from: Data(json.utf8), feature: .concierge)

        guard case .ready(.concierge(let result), _) = outcome else {
            Issue.record("Expected a concierge prep, got \(outcome)")
            return
        }
        #expect(result.keyMetrics.first?.label == "Head pain")
    }

    @Test func notEnoughDataAndDeclinedRepliesAreShownAsNotices() throws {
        let short = #"{"status":"insufficient_data","message":"This needs at least 7 days."}"#
        let declined = #"{"status":"declined","message":"Vida couldn't put this together."}"#

        #expect(try VidaPlusInsightsService.outcome(from: Data(short.utf8), feature: .bodyWeather) == .notice("This needs at least 7 days."))
        #expect(try VidaPlusInsightsService.outcome(from: Data(declined.utf8), feature: .differential) == .notice("Vida couldn't put this together."))
    }

    @Test func anOkReplyWithoutAResultIsAFailureNotABlankScreen() throws {
        let outcome = try VidaPlusInsightsService.outcome(from: Data(#"{"status":"ok"}"#.utf8), feature: .concierge)

        guard case .failed = outcome else {
            Issue.record("Expected a failure, got \(outcome)")
            return
        }
    }

    // MARK: Consent

    @Test func consentNamesTheProviderAndWhatIsSent() {
        #expect(ClaudeInsightsDisclosure.message.contains("Anthropic"))
        #expect(ClaudeInsightsDisclosure.message.contains("notes"))
        #expect(!ClaudeInsightsDisclosure.message.contains("\u{2014}"))
        #expect(!ClaudeInsightsDisclosure.title.contains("\u{2014}"))
    }

    @Test func minimumsMatchTheServer() {
        #expect(InsightFeature.bodyWeather.minimumDays == 7)
        #expect(InsightFeature.differential.minimumDays == 7)
        #expect(InsightFeature.concierge.minimumDays == 3)
    }
}
