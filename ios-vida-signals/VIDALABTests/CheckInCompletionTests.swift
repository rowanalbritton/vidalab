import Foundation
import Testing
@testable import VIDALAB

struct CheckInCompletionTests {
    @Test func healthImportsDoNotCompleteACheckIn() {
        let log = DayLog(date: .now, readings: [
            SignalReading(category: .sleep, value: 7, source: .appleHealth, period: .morning),
            SignalReading(category: .movement, value: 5, source: .appleHealth, period: .evening),
        ])
        #expect(log.completedPeriods.isEmpty)
    }

    @Test func herOwnEveningCheckInCompletesOnlyTheEvening() {
        let log = DayLog(date: .now, readings: [
            SignalReading(category: .sleep, value: 7, source: .appleHealth, period: .morning),
            SignalReading(category: .mood, value: 6, source: .manual, period: .evening),
        ])
        #expect(log.completedPeriods == [.evening])
    }

    @Test func olderReadingsWithoutASourceStillCount() {
        let log = DayLog(date: .now, readings: [SignalReading(category: .mood, value: 6)])
        #expect(log.completedPeriods == [.morning])
    }
}
