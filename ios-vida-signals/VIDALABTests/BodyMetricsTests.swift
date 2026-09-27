import Foundation
import Testing
@testable import VIDALAB

struct BodyMetricsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private let now = Date(timeIntervalSince1970: 1_790_500_000)

    /// Thirty days where the last seven read `recent` and the rest `usual`.
    private func series(_ kind: BodyMetricKind, usual: Double, recent: Double, days: Int = 30) -> BodyMetricSeries {
        let today = calendar.startOfDay(for: now)
        let values: [BodyMetricDay] = (0..<days).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            return BodyMetricDay(date: date, value: offset < 7 ? recent : usual)
        }
        return BodyMetricSeries(kind: kind, days: values)
    }

    @Test func thisWeekIsComparedWithTheUsualMonth() throws {
        let comparison = try #require(series(.restingHeartRate, usual: 58, recent: 62).comparison(now: now, calendar: calendar))

        #expect(comparison.usual == 58)
        #expect(comparison.recent == 62)
        #expect(!comparison.isSteady)
        #expect(comparison.summary.hasPrefix("4 bpm higher than your usual"))
    }

    @Test func smallChangesReadAsUsual() throws {
        let comparison = try #require(series(.heartRateVariability, usual: 42, recent: 44).comparison(now: now, calendar: calendar))

        #expect(comparison.isSteady)
        #expect(comparison.summary == "About your usual this week.")
    }

    @Test func lowerHRVIsDescribedWithoutAlarm() throws {
        let comparison = try #require(series(.heartRateVariability, usual: 50, recent: 38).comparison(now: now, calendar: calendar))

        #expect(comparison.summary.contains("lower than your usual"))
        #expect(!comparison.summary.lowercased().contains("diagnos"))
    }

    @Test func tooLittleHistoryGivesNoComparison() {
        #expect(series(.steps, usual: 6000, recent: 9000, days: 8).comparison(now: now, calendar: calendar) == nil)
    }

    @Test func valuesFormatWithTheRightPrecision() {
        #expect(BodyMetricKind.wristTemperature.format(0.349) == "0.3")
        #expect(BodyMetricKind.restingHeartRate.format(58.6) == "59")
        #expect(BodyMetricKind.respiratoryRate.format(14.26) == "14.3")
    }

    @Test func metricCopyAvoidsEmDashes() {
        for kind in BodyMetricKind.allCases {
            #expect(!kind.title.contains("\u{2014}"))
            #expect(!kind.source.contains("\u{2014}"))
        }
    }

    // MARK: Google Maps

    @Test func googleMapsLinksUseTheirPublicURLFormat() throws {
        let directions = try #require(GoogleMapsLink.directions(to: "Brigham and Women's, 75 Francis St, Boston, MA"))
        #expect(directions.absoluteString.hasPrefix("https://www.google.com/maps/dir/?api=1&destination="))

        let near = try #require(GoogleMapsLink.search(specialty: "rheumatologist", near: "Orlando, FL", latitude: nil, longitude: nil))
        #expect(near.absoluteString.contains("query=rheumatologist%20near%20Orlando,%20FL"))

        let located = try #require(GoogleMapsLink.search(specialty: "neurologist", near: nil, latitude: 28.53834, longitude: -81.37924))
        #expect(located.absoluteString.contains("28.5383,-81.3792"))
    }
}
