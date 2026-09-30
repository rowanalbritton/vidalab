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

/// The questions Ask suggests must never be refused by its own safety filter.
struct AskSuggestionTests {
    @Test func everySuggestedQuestionGetsAnAnswer() {
        for sex in [BiologicalSex?.none] + BiologicalSex.allCases.map(Optional.some) {
            for question in AskVidaLibrary.suggested(for: sex) {
                if case .outOfScope = AskGuardrails.classify(question, sex: sex) {
                    Issue.record("Suggested question was refused: \(question)")
                }
            }
        }
    }

    @Test func realDiagnosisRequestsAreStillRefused() {
        for question in ["Am I sick?", "Is this endometriosis?", "Do I have PCOS?", "Can you diagnose me?"] {
            guard case .outOfScope = AskGuardrails.classify(question, sex: nil) else {
                Issue.record("Should have been refused: \(question)")
                continue
            }
        }
    }
}

/// The diary lives in its own completely protected file, never in UserDefaults.
struct DiaryVaultTests {
    private func tempVault() -> DiaryVault {
        DiaryVault(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("diary-test-\(UUID().uuidString)", isDirectory: true))
    }

    @Test func writesAndReadsBackWithCompleteProtection() throws {
        let vault = tempVault()
        let entry = DiaryEntry(date: .now, text: "A quiet day.", period: nil, prompt: nil)
        #expect(vault.write([entry], accountKey: "vida.snapshot.v2.abc"))
        #expect(vault.read(accountKey: "vida.snapshot.v2.abc") == .entries([entry]))

        let attributes = try FileManager.default.attributesOfItem(atPath: vault.fileURL(for: "vida.snapshot.v2.abc").path)
        // The simulator reports no protection class; on a device it is .complete.
        if let protection = attributes[.protectionKey] as? FileProtectionType {
            #expect(protection == .complete)
        }
        try? FileManager.default.removeItem(at: vault.directory)
    }

    @Test func missingIsNotLocked() {
        #expect(tempVault().read(accountKey: "nobody") == .missing)
    }

    @Test func accountsNeverShareAFile() {
        let vault = tempVault()
        #expect(vault.fileURL(for: "vida.snapshot.v2.a") != vault.fileURL(for: "vida.snapshot.v2.b"))
    }

    @Test func mergeKeepsTheMostRecentEdit() {
        let id = UUID()
        var older = DiaryEntry(date: .now, text: "old", period: nil, prompt: nil)
        older.id = id
        older.updatedAt = Date(timeIntervalSince1970: 100)
        var newer = older
        newer.text = "new"
        newer.updatedAt = Date(timeIntervalSince1970: 200)
        let merged = VidaStore.mergedDiary([older], [newer])
        #expect(merged.count == 1)
        #expect(merged.first?.text == "new")
    }
}

/// The App Review account fills itself with sample data, and nobody else's does.
@MainActor
struct ReviewDemoAccountTests {
    private func freshDefaults() -> UserDefaults {
        let name = "review-demo-\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }

    @Test func seedsOnlyTheReviewEmail() {
        let store = VidaStore(persistent: false)
        store.seedReviewDemoIfNeeded(userID: "u1", email: "someone@example.com", defaults: freshDefaults())
        #expect(store.logs.isEmpty)
    }

    @Test func seedsAtLeastTwoWeeksForTheReviewEmail() {
        let store = VidaStore(persistent: false)
        store.seedReviewDemoIfNeeded(userID: "u1", email: " Rowan+AppleReview@vidalab.co ", defaults: freshDefaults())
        #expect(store.logs.count >= 14)
        #expect(!store.diary.isEmpty)
        #expect(!store.preps.isEmpty)
    }

    @Test func neverReplacesWhatTheReviewerLogged() {
        let defaults = freshDefaults()
        let store = VidaStore(persistent: false)
        store.seedReviewDemoIfNeeded(userID: "u1", email: ReviewDemoAccount.email, defaults: defaults)
        store.logs = Array(store.logs.prefix(1))
        store.seedReviewDemoIfNeeded(userID: "u1", email: ReviewDemoAccount.email, defaults: defaults)
        #expect(store.logs.count == 1)
    }
}

/// A purchase error can't know whether Apple took payment, so it never says so.
struct PurchaseErrorCopyTests {
    @Test func uncertainFailuresNeverPromiseNoCharge() {
        for error in [MembershipError.timedOut, .unknown] {
            let text = error.errorDescription ?? ""
            #expect(!text.contains("Nothing has been charged"))
            #expect(text.contains("Restore purchases"))
        }
    }
}
