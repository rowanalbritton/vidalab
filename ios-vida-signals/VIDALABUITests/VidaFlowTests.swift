import XCTest

/// Walks the main flows with the debug-only preview (sample data, no account,
/// nothing saved). Nothing here purchases, posts, or deletes anything.
final class VidaFlowTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchPreview(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-VidaPreview", "YES", "-VidaSkipWelcome", "YES", "-VidaDebugPlus"] + extra
        app.launch()
        return app
    }

    @MainActor
    private func exists(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 20) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Expected to see: \(label)")
    }

    @MainActor
    func testEveryTabOpens() {
        let app = launchPreview()
        exists(app.staticTexts["1 of 2"], "Today check-in card")
        let tabs: [(String, String)] = [
            ("Patterns", "What connects\nin your body"),
            ("Ask", "Ask anything\nabout your body."),
            ("Community", "Compare notes,\nkindly."),
            ("Lab", "Run a study\non yourself."),
            ("Library", "Real stories meet\nreal science.")
        ]
        for (tab, headline) in tabs {
            app.buttons[tab].firstMatch.tap()
            exists(app.staticTexts[headline], "\(tab) headline")
        }
    }

    @MainActor
    func testCheckInOpensAndCloses() {
        let app = launchPreview()
        let checkIn = app.buttons["Start the evening check-in"]
        exists(checkIn, "Check in button")
        checkIn.tap()
        exists(app.staticTexts["How did the\nday go?"], "evening check-in")
        app.buttons["Close"].firstMatch.tap()
    }

    @MainActor
    func testVidaMenuOpensTheDiary() {
        let app = launchPreview()
        let menu = app.buttons["Everything in Vida"].firstMatch
        exists(menu, "Vida menu button")
        menu.tap()
        exists(app.staticTexts["Everything in Vida"], "Vida menu")
        app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Diary'")).firstMatch.tap()
        exists(app.staticTexts["Write today"], "Diary")
    }

    @MainActor
    func testShareCardOpens() {
        let app = launchPreview()
        let share = app.buttons["Share today"].firstMatch
        exists(share, "share button")
        share.tap()
        exists(app.staticTexts["SHARE"], "share sheet")
        exists(app.buttons["My week"], "card choices")
    }

    @MainActor
    func testAskAnswersFromTheLibrary() {
        let app = launchPreview(["-VidaTab", "ask"])
        let starter = app.buttons.containing(NSPredicate(format: "label CONTAINS 'exhausted during'")).firstMatch
        exists(starter, "a starter question")
        starter.tap()
        // A library answer shows its sources; no network or AI is needed.
        exists(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Three things overlap'")).firstMatch, "library answer", timeout: 30)
    }

    @MainActor
    func testHealthSnapshotShowsTheConcierge() {
        let app = launchPreview(["-VidaTab", "lab", "-VidaLabSection", "prep", "-VidaOpenSnapshot", "YES", "-VidaScrollY", "1.0"])
        exists(app.staticTexts["Say it in one breath"], "Concierge summary", timeout: 30)
        exists(app.staticTexts["If a test or referral isn't offered."], "brushed-off reply")
    }

    @MainActor
    func testPaywallHasRestoreAndLegalLinks() {
        let app = launchPreview(["-VidaOpenPaywall", "YES"])
        // Checked but never tapped: no purchases or restores from tests.
        exists(app.buttons["Restore purchases"], "Restore purchases")
        exists(app.links["Terms of Use"].firstMatch, "Terms of Use link")
        exists(app.links["Privacy Policy"].firstMatch, "Privacy Policy link")
    }

    @MainActor
    func testSettingsReachesDeleteAccountWithoutDeleting() {
        let app = launchPreview()
        let settings = app.buttons["Settings"].firstMatch
        exists(settings, "Settings button")
        settings.tap()
        let delete = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Delete account and data'")).firstMatch
        for _ in 0..<8 where !delete.isHittable { app.swipeUp() }
        exists(delete, "Delete account row")
    }

    @MainActor
    func testSignInOffersAppleGoogleAndAgeCheck() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-VidaSkipWelcome", "YES"]
        app.launch()
        // Only meaningful when the simulator is signed out.
        guard app.staticTexts["Your patterns,\nkept private."].waitForExistence(timeout: 20) else {
            throw XCTSkip("Simulator is signed in; sign-in screen not shown.")
        }
        exists(app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Apple'")).firstMatch, "Sign in with Apple")
        exists(app.buttons["Continue with Google"], "Google sign-in")
        app.buttons["Create account"].firstMatch.tap()
        exists(app.staticTexts["Date of birth"], "16+ date of birth check")
    }
}
