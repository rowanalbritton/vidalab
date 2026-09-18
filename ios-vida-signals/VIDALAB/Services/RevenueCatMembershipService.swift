import Foundation
import RevenueCat

/// Real billing, behind the same seam the paywall already talks to.
///
/// Nothing above this file knows RevenueCat exists: it speaks only in
/// `MembershipProduct`, `PurchaseOutcome` and `MembershipSnapshot`.
nonisolated final class RevenueCatMembershipService: MembershipPurchasing {
    /// The entitlement configured in RevenueCat. All three plans grant it, so
    /// the app never has to ask which one somebody bought.
    static let entitlementID = "plus"

    /// Which key configures the SDK.
    ///
    /// Debug builds run against the Test Store — its purchases work without an
    /// App Store Connect account, which is the only way to exercise the whole
    /// paywall before Apple credentials exist. A Test Store purchase only works
    /// when the SDK is configured with the `test_` key, so it is preferred here
    /// whenever present.
    ///
    /// Release builds read only the App Store key: a test key must never ship,
    /// and Test Store entitlements would not survive review anyway.
    private static var injectedKey: String {
        #if DEBUG
        if !Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY.isEmpty {
            return Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY
        }
        #endif
        return Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY
    }

    /// The key this binary will actually use — with one refusal built in.
    ///
    /// Keys are injected at build time, so the source cannot prove which key a
    /// submitted build received; the wrong one only reveals itself at runtime.
    /// A Test Store key in a Release build is the expensive version of that
    /// mistake: Test Store purchases complete without money and without the
    /// App Store, so shipping one would hand Vida+ to everyone who tapped Buy
    /// and would take Apple's cut of nothing.
    ///
    /// Rather than trust it, a Release build discards a `test_` key entirely.
    /// Treating it as "unconfigured" routes billing to StoreKit 2 directly,
    /// which can only transact through Apple — so the worst case is real
    /// billing without RevenueCat's analytics, never free memberships.
    private static var apiKey: String {
        let key = injectedKey
        #if !DEBUG
        if key.hasPrefix("test_") { return "" }
        #endif
        return key
    }

    /// Whether real billing can run at all.
    ///
    /// In the sandbox `Config` literals are empty. Configuring the SDK with an
    /// empty key doesn't fail loudly — it fails on every later call, which
    /// would turn a missing key into a broken paywall.
    static var isConfigured: Bool { !apiKey.isEmpty }

    /// Whether the key in *this* binary is a RevenueCat Test Store key.
    ///
    /// Test Store keys start with `test_`. They complete purchases that look
    /// entirely real but involve no money and no App Store, so one reaching
    /// production would mean a paywall that grants Vida+ to everybody.
    static var isUsingTestStoreKey: Bool { apiKey.hasPrefix("test_") }

    /// Human-readable name of whoever is actually holding the billing.
    ///
    /// Reported for the running binary rather than inferred from a source
    /// snapshot: the key is injected at build time, so the source alone cannot
    /// tell you which provider a submitted build ended up with.
    static var providerLabel: String {
        guard isConfigured else { return "not configured (no API key)" }
        return isUsingTestStoreKey ? "RevenueCat · Test Store" : "RevenueCat · App Store"
    }

    /// Connects RevenueCat's install identity to the signed-in account.
    ///
    /// Without this every install is an anonymous RevenueCat user, which means
    /// server-side events (webhooks, cross-device entitlements) have no way to
    /// name the person they belong to. Signing in links them; signing out
    /// releases the anonymous identity again. Silent by design — a failed link
    /// costs nothing locally, because purchases still work and reconcile
    /// on-device.
    static func linkAccount(to userID: String?) {
        guard isConfigured, Purchases.isConfigured else { return }
        Task {
            if let userID {
                _ = try? await Purchases.shared.logIn(userID)
            } else {
                try? await Purchases.shared.logOut()
            }
        }
    }

    /// Configures the SDK exactly once, at launch, before anything reads it.
    static func configureIfPossible() {
        guard isConfigured, !Purchases.isConfigured else { return }
        #if DEBUG
        Purchases.logLevel = .error
        #else
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: apiKey)
    }

    /// Packages from the last offerings fetch, so a purchase can find the
    /// `Package` that belongs to a chosen product id.
    private let packages = PackageCache()

    // MARK: - Products

    func availableProducts() async throws -> [MembershipProduct] {
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let current = offerings.current else { return [] }

            await packages.store(current.availablePackages)

            return current.availablePackages.compactMap { package in
                let product = package.storeProduct
                // Only surface plans the app has voice for. An unknown product
                // appearing in the dashboard shouldn't render an untitled row.
                guard let copy = MembershipCopy.known(product.productIdentifier) else { return nil }
                return MembershipProduct(
                    id: product.productIdentifier,
                    priceText: product.localizedPriceString,
                    copy: copy,
                    periodMonths: Self.months(in: product.subscriptionPeriod)
                )
            }
            .sorted { $0.copy.order < $1.copy.order }
        } catch {
            throw Self.mapped(error)
        }
    }

    // MARK: - Purchase

    func purchase(_ product: MembershipProduct) async throws -> PurchaseOutcome {
        guard let package = await packages.package(for: product.id) else {
            throw MembershipError.storeUnavailable
        }

        do {
            let result = try await Purchases.shared.purchase(package: package)

            // Cancellation arrives two different ways depending on where in
            // StoreKit the person backed out. Both mean the same thing.
            if result.userCancelled { return .cancelled }

            let entitlement = result.customerInfo.entitlements[Self.entitlementID]
            guard entitlement?.isActive == true else {
                // Paid but not yet entitled means Apple is still deciding —
                // Ask to Buy, or a slow receipt. Not a failure.
                return .pending
            }

            return .success(
                transactionID: result.transaction?.transactionIdentifier
                    ?? entitlement?.productIdentifier
                    ?? product.id,
                expiresAt: entitlement?.expirationDate
            )
        } catch ErrorCode.purchaseCancelledError {
            return .cancelled
        } catch ErrorCode.paymentPendingError {
            return .pending
        } catch {
            throw Self.mapped(error)
        }
    }

    // MARK: - Restore

    func restore() async throws -> RestoreOutcome {
        do {
            let info = try await Purchases.shared.restorePurchases()
            guard let entitlement = info.entitlements[Self.entitlementID],
                  entitlement.isActive else {
                return .nothingFound
            }
            return .restored(
                transactionID: entitlement.originalPurchaseDate.map {
                    "restore-\(entitlement.productIdentifier)-\(Int($0.timeIntervalSince1970))"
                } ?? "restore-\(entitlement.productIdentifier)",
                productID: entitlement.productIdentifier,
                expiresAt: entitlement.expirationDate
            )
        } catch {
            throw Self.mapped(error)
        }
    }

    // MARK: - Reconciliation

    func currentEntitlement() async throws -> MembershipSnapshot? {
        do {
            return Self.snapshot(from: try await Purchases.shared.customerInfo())
        } catch {
            throw Self.mapped(error)
        }
    }

    /// Translates the store's view into the app's vocabulary.
    ///
    /// The ordering matters: a billing problem outranks a cancellation,
    /// because an expired card needs acting on and a scheduled end doesn't.
    static func snapshot(from info: CustomerInfo) -> MembershipSnapshot {
        guard let entitlement = info.entitlements[entitlementID] else {
            return MembershipSnapshot(
                status: .free,
                planName: nil,
                expiresAt: nil,
                graceUntil: nil,
                transactionID: nil
            )
        }

        let name = MembershipCopy.known(entitlement.productIdentifier)?.title
        // Stable per billing period, so re-applying the same state is a no-op.
        let stamp = entitlement.latestPurchaseDate.map { Int($0.timeIntervalSince1970) } ?? 0
        let identifier = "rc-\(entitlement.productIdentifier)-\(stamp)"

        let status: EntitlementStatus
        if entitlement.isActive {
            if entitlement.billingIssueDetectedAt != nil {
                status = .grace
            } else if entitlement.willRenew == false {
                status = .cancelled
            } else {
                status = .active
            }
        } else {
            // Apple reports refunds and chargebacks by ending ownership early.
            status = entitlement.expirationDate.map { $0 > .now } == true ? .revoked : .expired
        }

        return MembershipSnapshot(
            status: status,
            planName: name,
            expiresAt: entitlement.expirationDate,
            graceUntil: status == .grace ? entitlement.expirationDate : nil,
            transactionID: identifier
        )
    }

    // MARK: - Helpers

    private static func months(in period: SubscriptionPeriod?) -> Int {
        guard let period else { return 1 }
        switch period.unit {
        case .day: return max(1, period.value / 30)
        case .week: return max(1, period.value / 4)
        case .month: return period.value
        case .year: return period.value * 12
        @unknown default: return 1
        }
    }

    /// Turns SDK errors into the five things worth telling somebody, so no
    /// raw error code or provider name ever reaches the screen.
    private static func mapped(_ error: Error) -> MembershipError {
        guard let code = error as? ErrorCode else { return .unknown }
        switch code {
        case .networkError, .offlineConnectionError:
            return .offline
        case .storeProblemError, .productNotAvailableForPurchaseError,
             .invalidAppleSubscriptionKeyError, .configurationError:
            return .storeUnavailable
        case .purchaseNotAllowedError, .paymentPendingError:
            return .notAllowed
        default:
            return .unknown
        }
    }
}

/// Holds the packages from the latest offerings fetch.
///
/// An actor because the paywall fetches on one task and purchases on another.
private actor PackageCache {
    private var byProductID: [String: Package] = [:]

    func store(_ packages: [Package]) {
        byProductID = Dictionary(
            packages.map { ($0.storeProduct.productIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func package(for productID: String) -> Package? { byProductID[productID] }
}
