import Foundation

/// Marketing copy for a plan.
///
/// Deliberately kept in the app rather than the billing dashboard: the price
/// must come from the store (so it's right in every currency), but the words
/// around it are product voice and shouldn't be editable by a webhook.
nonisolated struct MembershipCopy: Hashable, Sendable {
    let title: String
    let cadence: String
    let detail: String
    let badge: String?
    /// Display order on the paywall, lowest first.
    let order: Int

    static let table: [String: MembershipCopy] = [
        MembershipProductID.yearly: MembershipCopy(
            title: "Yearly",
            cadence: "per year",
            detail: "The whole year, one payment",
            badge: "BEST VALUE",
            order: 0
        ),
        MembershipProductID.monthly: MembershipCopy(
            title: "Monthly",
            cadence: "per month",
            detail: "Cancel any time",
            badge: nil,
            order: 1
        ),
        MembershipProductID.family: MembershipCopy(
            title: "Family",
            cadence: "per year",
            detail: "Up to four people, private data for each",
            badge: "PRIVATE PER PERSON",
            order: 2
        )
    ]

    static func known(_ identifier: String) -> MembershipCopy? { table[identifier] }
}

/// Store identifiers. These must match the products configured in billing.
nonisolated enum MembershipProductID {
    static let monthly = "vida_plus_monthly"
    static let yearly = "vida_plus_yearly"
    static let family = "vida_plus_family"
}

/// A purchasable plan, priced by the store.
nonisolated struct MembershipProduct: Identifiable, Hashable, Sendable {
    let id: String
    /// Already localised by the store — never formatted by hand.
    let priceText: String
    let copy: MembershipCopy
    /// Length of one billing period, used to project a renewal date.
    let periodMonths: Int
}

/// What came back from a purchase attempt.
///
/// Cancellation and pending approval are first-class outcomes, not errors:
/// backing out of a sheet isn't a failure, and a child waiting on a parent's
/// approval must not be told something went wrong.
nonisolated enum PurchaseOutcome: Sendable {
    case success(transactionID: String, expiresAt: Date?)
    case cancelled
    case pending
}

nonisolated enum RestoreOutcome: Sendable {
    case restored(transactionID: String, productID: String, expiresAt: Date?)
    case nothingFound
}

/// Failures worth surfacing, already phrased for a person.
nonisolated enum MembershipError: LocalizedError, Sendable {
    case offline
    case storeUnavailable
    case notAllowed
    case timedOut
    case unknown

    var errorDescription: String? {
        switch self {
        case .offline:
            "You appear to be offline. Reconnect and try again — you won't be charged twice."
        case .storeUnavailable:
            "The App Store isn't responding right now. This is on Apple's side, not yours. Try again in a moment."
        case .notAllowed:
            "Purchases are restricted on this device. That's usually a Screen Time or parental control setting."
        case .timedOut:
            "That took too long to answer. Nothing has been charged. Try again."
        case .unknown:
            "Something went wrong and we're not sure what. Nothing has been charged."
        }
    }
}

/// What the store currently believes about this person's membership.
///
/// Separate from `Entitlement` (the app's own record) so a reconciliation can
/// compare the two and decide what, if anything, changed.
nonisolated struct MembershipSnapshot: Sendable, Equatable {
    let status: EntitlementStatus
    let planName: String?
    let expiresAt: Date?
    let graceUntil: Date?
    /// Stable across replays so applying the same state twice is a no-op.
    let transactionID: String?

    /// Plain-language line for the audit log.
    var changeDescription: String {
        switch status {
        case .active: "Confirmed active with the App Store."
        case .grace: "The App Store reports a payment problem. Access continues."
        case .cancelled: "Renewal is off at the App Store. Access continues until the period ends."
        case .expired: "The App Store reports the period has ended."
        case .revoked: "The App Store reports the purchase was refunded."
        case .free: "The App Store has no membership on this Apple Account."
        }
    }
}

/// The seam between the paywall and whatever actually takes money.
///
/// The UI knows nothing about the billing provider, which means the provider
/// can be swapped, or stubbed for tests, without touching a single view.
protocol MembershipPurchasing: Sendable {
    nonisolated func availableProducts() async throws -> [MembershipProduct]
    nonisolated func purchase(_ product: MembershipProduct) async throws -> PurchaseOutcome
    nonisolated func restore() async throws -> RestoreOutcome
    /// Current store truth, or `nil` when this provider has no authority to
    /// speak — which must never be read as "not a member".
    nonisolated func currentEntitlement() async throws -> MembershipSnapshot?
}

/// Local stand-in used until store credentials are live.
///
/// It returns the real product identifiers and realistic latency so the paywall
/// exercises every state it will face in production.
nonisolated final class LocalMembershipService: MembershipPurchasing {
    private let placeholderPrices: [String: String] = [
        MembershipProductID.yearly: "$49.99",
        MembershipProductID.monthly: "$6.99",
        MembershipProductID.family: "$79.00"
    ]

    func availableProducts() async throws -> [MembershipProduct] {
        try await Task.sleep(for: .milliseconds(320))
        return placeholderPrices.compactMap { identifier, price in
            guard let copy = MembershipCopy.known(identifier) else { return nil }
            return MembershipProduct(
                id: identifier,
                priceText: price,
                copy: copy,
                periodMonths: identifier == MembershipProductID.monthly ? 1 : 12
            )
        }
        .sorted { $0.copy.order < $1.copy.order }
    }

    func purchase(_ product: MembershipProduct) async throws -> PurchaseOutcome {
        try await Task.sleep(for: .milliseconds(700))
        let renewal = Calendar.current.date(
            byAdding: .month,
            value: product.periodMonths,
            to: .now
        )
        return .success(transactionID: "local-\(UUID().uuidString)", expiresAt: renewal)
    }

    func restore() async throws -> RestoreOutcome {
        try await Task.sleep(for: .milliseconds(600))
        return .nothingFound
    }

    /// The stub has no idea what anyone has bought, and says so rather than
    /// reporting a confident "free" that would strip a real membership.
    func currentEntitlement() async throws -> MembershipSnapshot? { nil }
}

nonisolated enum MembershipServiceFactory {
    /// One instance for the whole app: the paywall and the launch
    /// reconciliation must not disagree about who's asking.
    static let shared: MembershipPurchasing = {
        let service = live()
        #if DEBUG
        print("[Membership] billing provider: \(RevenueCatMembershipService.providerLabel)")
        #endif
        return service
    }()

    /// The single place that decides who takes the money.
    ///
    /// Falls back to the local stub when no key is present — in the sandbox
    /// `Config` literals are empty, and configuring RevenueCat with an empty
    /// key would fail every call instead of degrading quietly.
    static func live() -> MembershipPurchasing {
        RevenueCatMembershipService.isConfigured
            ? RevenueCatMembershipService()
            : LocalMembershipService()
    }
}

/// Races an operation against a deadline so no purchase can hang forever.
nonisolated func withMembershipTimeout<T: Sendable>(
    seconds: Double = 15,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw MembershipError.timedOut
        }
        guard let first = try await group.next() else { throw MembershipError.timedOut }
        group.cancelAll()
        return first
    }
}
