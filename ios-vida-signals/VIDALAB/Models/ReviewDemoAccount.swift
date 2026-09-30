import Foundation

/// Sample history for the App Review demo account.
///
/// Every check-in is sealed with a key that lives in the member's own iCloud
/// Keychain, so data logged on Rowan's devices can never be opened on the
/// reviewer's iPhone. Instead, the one review account fills itself with the
/// same nine weeks of sample data the screenshots use, on whichever device it
/// signs in on. No other account is ever touched.
nonisolated enum ReviewDemoAccount {
    static let email = "rowan+applereview@vidalab.co"

    static func isDemo(email: String?) -> Bool {
        guard let email else { return false }
        return email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == Self.email
    }

    static func seededFlagKey(for userID: String) -> String {
        "vida.reviewDemo.seeded.\(userID)"
    }
}

extension VidaStore {
    /// Seeds the review account once per device, and only while its journal is
    /// still empty, so anything the reviewer logs themselves is never replaced.
    func seedReviewDemoIfNeeded(userID: String?, email: String?, defaults: UserDefaults = .standard) {
        guard let userID, ReviewDemoAccount.isDemo(email: email) else { return }
        let flag = ReviewDemoAccount.seededFlagKey(for: userID)
        guard !defaults.bool(forKey: flag), logs.isEmpty else { return }

        seedDemoData()

        let calendar = Calendar.current
        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: .now) ?? .now
        }
        if diary.isEmpty {
            diary = [
                DiaryEntry(date: daysAgo(1), text: "Slow start, but the walk at lunch helped. Head felt clearer by three.", period: .evening, prompt: nil),
                DiaryEntry(date: daysAgo(3), text: "Rough night. Noticed the headache came back after the late coffee.", period: .morning, prompt: nil),
                DiaryEntry(date: daysAgo(6), text: "Good day. Slept eight hours and it showed.", period: nil, prompt: nil)
            ]
        }
        if preps.isEmpty {
            preps = [
                DoctorPrep(
                    concern: "Headaches that keep coming back",
                    bodyArea: "Head",
                    onset: "About three months ago",
                    frequency: "Two or three times a week",
                    typicalSeverity: 5,
                    worstSeverity: 8,
                    associatedSymptoms: ["Light sensitivity", "Nausea"],
                    impact: ["Missed work", "Trouble sleeping"],
                    triedAlready: ["Ibuprofen", "More water"],
                    questions: ["Could these be migraines?", "Is my sleep part of this?"]
                )
            ]
        }
        save()
        defaults.set(true, forKey: flag)
    }
}
