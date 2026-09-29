import SwiftUI

/// The app's outbound links, in one place.
///
/// Apple requires functional Terms of Use and Privacy Policy links on any
/// screen that sells a subscription, and a privacy policy for any app that
/// reads HealthKit. Both pages must exist and stay reachable at these exact
/// paths before submission — a 404 here is a review rejection.
nonisolated enum VidaLinks {
    static let site = URL(string: "https://vidalab.co")!
    static let privacy = URL(string: "https://vidalab.co/privacy")!
    static let terms = URL(string: "https://vidalab.co/terms")!

    /// Published contact for moderation and support.
    ///
    /// Guideline 1.2 wants a way to reach someone about user-generated content,
    /// so this has to be reachable inside the app and not only on the site.
    static let supportAddress = "rowan@vidalab.co"
    static let support = URL(string: "mailto:rowan@vidalab.co")!

    /// Where an App Store subscription is actually managed.
    ///
    /// An app cannot cancel an Apple subscription itself, so this opens the
    /// real place rather than offering a button that quietly does nothing.
    static let manageSubscription = URL(string: "https://apps.apple.com/account/subscriptions")!
    /// Help for a membership bought on the website. The support page explains
    /// how to cancel one; it is deliberately not the sales page, so the app
    /// never points anyone toward buying outside Apple.
    static let webMembership = URL(string: "https://vidalab.co/support")!
}

/// The Terms / Privacy pair, styled to sit quietly under a paywall or in
/// Settings without competing with the content above it.
struct LegalLinksRow: View {
    var tint: Color = Vida.taupe

    var body: some View {
        HStack(spacing: 8) {
            Link("Terms of Use", destination: VidaLinks.terms)
            Text("·")
            Link("Privacy Policy", destination: VidaLinks.privacy)
        }
        .font(Vida.sans(12, weight: .medium))
        .foregroundStyle(tint)
        .frame(minHeight: 44)
    }
}
