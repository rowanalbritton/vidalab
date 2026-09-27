import Foundation

/// Where a membership was bought. Determines where it can be cancelled, and
/// blocks buying the same thing twice on a second surface.
///
/// `web` is a Vida+ membership bought at vidalab.co/vida-plus. The site sells
/// it with its own checkout, and the app honors it for the same account
/// (Guideline 3.1.3(b)); it never sells or links to that checkout itself.
nonisolated enum EntitlementSource: String, Codable, Hashable {
    case appStore
    case promo
    case web

    var label: String {
        switch self {
        case .appStore: "the App Store"
        case .promo: "a promotional code"
        case .web: "vidalab.co"
        }
    }

    /// Where she has to go to change it. Apple doesn't let an app cancel an
    /// App Store subscription, and pretending otherwise produces a button that
    /// silently does nothing.
    var manageInstruction: String {
        switch self {
        case .appStore: "Manage or cancel it in Settings › Apple Account › Subscriptions."
        case .promo: "It was granted directly, so there's nothing to cancel."
        case .web: "It was bought on vidalab.co, so manage or cancel it there, under Vida+."
        }
    }
}

/// The lifecycle of a Vida+ membership.
///
/// Access and billing are deliberately separate ideas. Someone whose card just
/// expired is still a paying member having a bad week, and locking her out of
/// her own health history over a failed charge would be indefensible.
nonisolated enum EntitlementStatus: String, Codable, Hashable {
    case free
    /// Paid and healthy.
    case active
    /// Payment failed. Access continues while it's sorted out.
    case grace
    /// Cancelled but still inside the paid period.
    case cancelled
    /// Refunded or charged back. Access ends, data is untouched.
    case revoked
    /// Period ended naturally.
    case expired
}

/// One immutable line in the entitlement history.
nonisolated struct EntitlementEvent: Codable, Hashable, Identifiable {
    var id = UUID()
    let date: Date
    let status: EntitlementStatus
    let source: EntitlementSource
    /// The external transaction this came from, if any.
    let transactionID: String?
    /// Plain-language description of what happened.
    let detail: String
}

/// Everything known about the member's Vida+ standing.
nonisolated struct Entitlement: Codable, Hashable {
    var status: EntitlementStatus = .free
    var source: EntitlementSource?
    var planName: String = ""
    /// When the paid period runs out. Shown verbatim after a cancellation.
    var expiresAt: Date?
    /// When the grace window closes.
    var graceUntil: Date?
    /// Transaction ids already applied, so a webhook replayed twice is a no-op.
    var appliedTransactionIDs: [String] = []
    /// Append-only history: who, what, when, from where.
    var auditLog: [EntitlementEvent] = []
    /// Last time a live entitlement check succeeded.
    var lastVerified: Date?

    /// Whether paid features are open right now.
    ///
    /// Grace and cancelled both keep access: one is a billing problem, the
    /// other is a period she already paid for.
    var hasAccess: Bool {
        switch status {
        case .active, .grace, .cancelled:
            if let expiresAt, expiresAt < .now, status != .grace { return false }
            return true
        case .free, .revoked, .expired:
            return false
        }
    }

    /// Non-blocking banner text. Nil when there's nothing to say.
    var noticeTitle: String? {
        switch status {
        case .grace: "There's a problem with your payment"
        case .cancelled: "Vida+ ends soon"
        case .revoked: "Vida+ has ended"
        case .expired: "Vida+ has expired"
        default: nil
        }
    }

    var noticeMessage: String? {
        switch status {
        case .grace:
            let until = graceUntil.map(Entitlement.dayFormatter.string(from:))
            return "We couldn't take the last payment — usually an expired card. You still have everything\(until.map { " until \($0)" } ?? "") while you update it."
        case .cancelled:
            guard let expiresAt else { return "You keep full access until your period ends." }
            return "You've cancelled, so it won't renew. You keep everything until \(Entitlement.dayFormatter.string(from: expiresAt))."
        case .revoked:
            return "Your purchase was refunded, so Vida+ features are locked. Every check-in, experiment and report you've made is untouched and still here."
        case .expired:
            return "Your membership has ended. Nothing you logged has been deleted — you're simply back on Vida Free."
        default:
            return nil
        }
    }

    /// Severity flag: a payment problem should look different from a countdown.
    var noticeIsUrgent: Bool { status == .grace || status == .revoked }

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
}
