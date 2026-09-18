import Foundation
import StoreKit

extension Notification.Name {
    /// Posted when StoreKit reports a transaction outside a purchase flow —
    /// an Ask to Buy approval, a renewal, or a refund landing while the app
    /// is open. The root view re-verifies rather than waiting for a relaunch.
    static let vidaEntitlementDidChange = Notification.Name("vida.entitlement.didChange")
}

/// Billing through StoreKit 2 directly, with no third-party dependency.
///
/// This is the fallback when RevenueCat has no key, and it exists because the
/// alternative — a local stub that fabricates a successful purchase — is both
/// an App Review rejection and a lie to the person tapping the button. Every
/// path here either reaches Apple or fails honestly. There is deliberately no
/// code in this app that can grant paid access without a real transaction.
nonisolated final class StoreKitMembershipService: MembershipPurchasing {
    static let productIDs: Set<String> = [
        MembershipProductID.yearly,
        MembershipProductID.monthly,
        MembershipProductID.family
    ]

    private let cache = StoreProductCache()

    // MARK: - Transaction listener

    /// Watches for transactions that arrive outside a purchase call.
    ///
    /// Required by StoreKit: a transaction that is never finished is replayed
    /// forever. It also covers Ask to Buy, where approval can land minutes
    /// after the sheet closed.
    static func startObservingTransactions() -> Task<Void, Never> {
        Task.detached {
            for await update in Transaction.updates {
                guard case let .verified(transaction) = update else { continue }
                await transaction.finish()
                NotificationCenter.default.post(name: .vidaEntitlementDidChange, object: nil)
            }
        }
    }

    // MARK: - Products

    func availableProducts() async throws -> [MembershipProduct] {
        do {
            let products = try await Product.products(for: Self.productIDs)
            await cache.store(products)
            return products.compactMap { product in
                guard let copy = MembershipCopy.known(product.id) else { return nil }
                return MembershipProduct(
                    id: product.id,
                    priceText: product.displayPrice,
                    copy: copy,
                    periodMonths: Self.months(in: product.subscription?.subscriptionPeriod)
                )
            }
            .sorted { $0.copy.order < $1.copy.order }
        } catch {
            throw Self.mapped(error)
        }
    }

    // MARK: - Purchase

    func purchase(_ product: MembershipProduct) async throws -> PurchaseOutcome {
        // Never purchase from a stale cache entry: if the catalogue hasn't been
        // fetched, say the store is unavailable rather than inventing a sale.
        guard let storeProduct = await cache.product(for: product.id) else {
            throw MembershipError.storeUnavailable
        }

        do {
            let result = try await storeProduct.purchase()
            switch result {
            case .userCancelled:
                return .cancelled
            case .pending:
                // Ask to Buy, or Strong Customer Authentication. Not a failure.
                return .pending
            case let .success(verification):
                guard case let .verified(transaction) = verification else {
                    // An unverified transaction is not proof of anything. It
                    // must never unlock the app.
                    throw MembershipError.unknown
                }
                await transaction.finish()
                return .success(
                    transactionID: "sk-\(transaction.productID)-\(transaction.id)",
                    expiresAt: transaction.expirationDate
                )
            @unknown default:
                throw MembershipError.unknown
            }
        } catch let error as MembershipError {
            throw error
        } catch {
            throw Self.mapped(error)
        }
    }

    // MARK: - Restore

    func restore() async throws -> RestoreOutcome {
        do {
            // Genuinely asks Apple to re-deliver this Apple Account's history.
            try await AppStore.sync()
        } catch {
            // Backing out of the Apple Account prompt is a choice, not an error.
            if let storeKitError = error as? StoreKitError, case .userCancelled = storeKitError {
                return .nothingFound
            }
            throw Self.mapped(error)
        }

        guard let transaction = await Self.activeTransaction() else {
            return .nothingFound
        }
        return .restored(
            transactionID: "sk-\(transaction.productID)-\(transaction.id)",
            productID: transaction.productID,
            expiresAt: transaction.expirationDate
        )
    }

    // MARK: - Reconciliation

    func currentEntitlement() async throws -> MembershipSnapshot? {
        guard let transaction = await Self.activeTransaction() else {
            return MembershipSnapshot(
                status: .free,
                planName: nil,
                expiresAt: nil,
                graceUntil: nil,
                transactionID: nil
            )
        }

        let status = await Self.renewalStatus(for: transaction)
        return MembershipSnapshot(
            status: status,
            planName: MembershipCopy.known(transaction.productID)?.title,
            expiresAt: transaction.expirationDate,
            graceUntil: status == .grace ? transaction.expirationDate : nil,
            transactionID: "sk-\(transaction.productID)-\(transaction.id)"
        )
    }

    /// The newest non-revoked entitlement belonging to one of our products.
    private static func activeTransaction() async -> StoreKit.Transaction? {
        var latest: StoreKit.Transaction?
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else { continue }
            guard productIDs.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let existing = latest, existing.purchaseDate > transaction.purchaseDate { continue }
            latest = transaction
        }
        return latest
    }

    /// Distinguishes a healthy subscription from one in billing trouble or
    /// already switched off, so the app can keep someone in during a grace
    /// period instead of locking them out over a declined card.
    private static func renewalStatus(for transaction: StoreKit.Transaction) async -> EntitlementStatus {
        if transaction.revocationDate != nil { return .revoked }
        if let expiry = transaction.expirationDate, expiry <= .now { return .expired }

        guard let product = (try? await Product.products(for: [transaction.productID]))?.first,
              let subscription = product.subscription,
              let statuses = try? await subscription.status else {
            return .active
        }

        for status in statuses {
            if status.state == .inGracePeriod || status.state == .inBillingRetryPeriod { return .grace }
            if status.state == .revoked { return .revoked }
            if status.state == .expired { return .expired }
            if case let .verified(renewalInfo) = status.renewalInfo, !renewalInfo.willAutoRenew {
                return .cancelled
            }
        }
        return .active
    }

    // MARK: - Helpers

    private static func months(in period: Product.SubscriptionPeriod?) -> Int {
        guard let period else { return 1 }
        switch period.unit {
        case .day: return max(1, period.value / 30)
        case .week: return max(1, period.value / 4)
        case .month: return period.value
        case .year: return period.value * 12
        @unknown default: return 1
        }
    }

    /// Five things worth telling somebody. No raw StoreKit code reaches a screen.
    private static func mapped(_ error: Error) -> MembershipError {
        if let purchaseError = error as? Product.PurchaseError {
            if case .purchaseNotAllowed = purchaseError { return .notAllowed }
            return .storeUnavailable
        }
        if let storeKitError = error as? StoreKitError {
            switch storeKitError {
            case .networkError: return .offline
            case .notAvailableInStorefront, .systemError: return .storeUnavailable
            case .notEntitled: return .notAllowed
            default: return .unknown
            }
        }
        return .unknown
    }
}

/// Holds the fetched `Product` values between the catalogue load and a purchase.
private actor StoreProductCache {
    private var byID: [String: Product] = [:]

    func store(_ products: [Product]) {
        byID = Dictionary(products.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func product(for id: String) -> Product? { byID[id] }
}
