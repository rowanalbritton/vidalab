import Foundation
import Testing
@testable import VIDALAB

/// Guards the changes made while matching the approved design (2026-09-29/30).
struct DesignFollowUpTests {

    // MARK: - Appointment Concierge wording

    @Test func quotedPhrasesReadAsSomethingHeard() {
        let line = AppointmentConcierge.ScriptLine(ifYouHear: "\"Let's wait and see.\"", youCanSay: "x")
        #expect(line.lead() == "If you hear \"Let's wait and see.\"")
        #expect(line.lead(hearer: "I") == "If I hear \"Let's wait and see.\"")
    }

    @Test func situationsReadAsConditionsNotQuotes() {
        let line = AppointmentConcierge.ScriptLine(ifYouHear: "A test or referral isn't offered.", youCanSay: "x")
        #expect(line.lead() == "If a test or referral isn't offered.")
        #expect(line.lead(hearer: "I") == "If a test or referral isn't offered.")
        #expect(!line.lead().contains("hear A"))
    }

    // MARK: - Web members' manage link

    @Test func webMembersAreSentToSupportNotTheSalesPage() {
        #expect(VidaLinks.webMembership.host() == "vidalab.co")
        #expect(VidaLinks.webMembership.path() == "/support")
        #expect(!VidaLinks.webMembership.absoluteString.contains("vida-plus"))
    }

    // MARK: - Forest default

    @Test func aNewStoreDefaultsToForest() {
        #expect(VidaStore(persistent: false).appearance == .dark)
    }

    @Test func switchingAccountsResetsToForestNotAutomatic() {
        let store = VidaStore(persistent: false)
        store.appearance = .light
        store.activateAccount("another-account")
        #expect(store.appearance == .dark)
    }

    // MARK: - Today's check-in card

    @Test func cardOffersTheEveningWhenOnlyTheMorningIsDone() {
        let store = VidaStore(persistent: false)
        store.seedDemoData()
        guard let index = store.logs.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) else {
            Issue.record("Demo data should include today")
            return
        }
        store.logs[index].readings.removeAll { $0.period == .evening }
        #expect(store.completedPeriodsToday.count == 1)
        #expect(store.nextPeriod == .evening)
    }

    @Test func cardHasNothingToOfferOnceBothAreDone() {
        let store = VidaStore(persistent: false)
        store.seedDemoData()
        #expect(store.completedPeriodsToday.count == CheckInPeriod.allCases.count)
        #expect(store.nextPeriod == nil)
    }
}
