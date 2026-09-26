import Foundation
import Testing
@testable import VIDALAB

struct FirstWeekGuideTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func day(_ offset: Int) -> Date {
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 9))!
        return calendar.date(byAdding: .day, value: offset, to: start)!
    }

    /// A reading the member entered themselves: manual and timestamped.
    private func own(_ period: CheckInPeriod = .morning, on date: Date) -> SignalReading {
        var reading = SignalReading(category: .energy, value: 5)
        reading.source = .manual
        reading.period = period
        reading.recordedAt = date
        return reading
    }

    private func inputs(_ logs: [DayLog]) -> FirstWeekGuide.Inputs {
        FirstWeekGuide.Inputs(
            logs: logs,
            healthSyncEnabled: false,
            hasAskedQuestion: false,
            experimentCount: 0,
            prepCount: 0
        )
    }

    @Test func nothingIsDoneForANewMember() {
        #expect(FirstWeekGuide.completed(inputs([]), calendar: calendar).isEmpty)
    }

    @Test func sampleDataAndHealthImportsDoNotTickSteps() {
        // Sample data has no entry timestamp.
        let sample = SignalReading(category: .mood, value: 6)
        // Apple Health imports have a timestamp but nobody checked in.
        var imported = SignalReading(category: .sleep, value: 7)
        imported.source = .appleHealth
        imported.recordedAt = day(0)

        let logs = [DayLog(date: day(0), readings: [sample, imported])]

        #expect(FirstWeekGuide.memberLogs(logs).isEmpty)
        #expect(FirstWeekGuide.completed(inputs(logs), calendar: calendar).isEmpty)
    }

    @Test func memberLogsKeepOnlyTheMembersOwnReadings() {
        let sample = SignalReading(category: .mood, value: 6)
        let logs = [DayLog(date: day(0), readings: [sample, own(on: day(0))])]

        let filtered = FirstWeekGuide.memberLogs(logs)

        #expect(filtered.count == 1)
        #expect(filtered.first?.readings.count == 1)
    }

    @Test func oneCheckInTicksOnlyTheFirstStep() {
        let logs = [DayLog(date: day(0), readings: [own(on: day(0))])]

        #expect(FirstWeekGuide.completed(inputs(logs), calendar: calendar) == [.firstCheckIn])
    }

    @Test func morningAndEveningOnTheSameDayTicksBothHalves() {
        let logs = [DayLog(date: day(0), readings: [own(.morning, on: day(0)), own(.evening, on: day(0))])]

        let done = FirstWeekGuide.completed(inputs(logs), calendar: calendar)

        #expect(done.contains(.bothHalves))
    }

    @Test func morningAndEveningOnDifferentDaysDoesNotTickBothHalves() {
        let logs = [
            DayLog(date: day(0), readings: [own(.morning, on: day(0))]),
            DayLog(date: day(1), readings: [own(.evening, on: day(1))]),
        ]

        #expect(!FirstWeekGuide.completed(inputs(logs), calendar: calendar).contains(.bothHalves))
    }

    @Test func longestRunCountsConsecutiveDaysOnly() {
        let logs = [0, 1, 2, 4, 5].map { DayLog(date: day($0), readings: [own(on: day($0))]) }

        #expect(FirstWeekGuide.longestRun(in: logs, calendar: calendar) == 3)
    }

    @Test func twoLogsOnTheSameDayCountAsOneDay() {
        let logs = [
            DayLog(date: day(0), readings: [own(on: day(0))]),
            DayLog(date: day(0).addingTimeInterval(3600), readings: [own(on: day(0))]),
        ]

        #expect(FirstWeekGuide.longestRun(in: logs, calendar: calendar) == 1)
    }

    @Test func threeDaysInARowTicksTheStreakStep() {
        let logs = [0, 1, 2].map { DayLog(date: day($0), readings: [own(on: day($0))]) }

        #expect(FirstWeekGuide.completed(inputs(logs), calendar: calendar).contains(.threeDays))
    }

    @Test func threeDaysWithAGapDoesNotTickTheStreakStep() {
        let logs = [0, 1, 3].map { DayLog(date: day($0), readings: [own(on: day($0))]) }

        #expect(!FirstWeekGuide.completed(inputs(logs), calendar: calendar).contains(.threeDays))
    }

    @Test func nonCheckInStepsFollowTheirInputs() {
        let all = FirstWeekGuide.Inputs(
            logs: [],
            healthSyncEnabled: true,
            hasAskedQuestion: true,
            experimentCount: 1,
            prepCount: 2
        )

        #expect(FirstWeekGuide.completed(all, calendar: calendar) == [.appleHealth, .askVida, .experiment, .doctorPrep])
    }

    @Test func everyStepHasCopyAndASymbol() {
        for step in FirstWeekGuide.Step.allCases {
            #expect(!step.title.isEmpty)
            #expect(!step.detail.isEmpty)
            #expect(!step.symbol.isEmpty)
            // House style: no em dashes in user-facing copy.
            #expect(!step.title.contains("\u{2014}"))
            #expect(!step.detail.contains("\u{2014}"))
        }
    }
}
