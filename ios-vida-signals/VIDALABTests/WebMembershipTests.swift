import Foundation
import Testing
@testable import VIDALAB

/// How a Vida+ membership bought on vidalab.co combines with the App Store.
struct WebMembershipTests {
    @Test @MainActor func aPaidWebMembershipUnlocksAFreeAccount() {
        let store = VidaStore(persistent: false)

        store.reconcileWebMembership(true)

        #expect(store.isPlus)
        #expect(store.entitlement.source == .web)
    }

    @Test @MainActor func anAppStoreMembershipKeepsPrecedence() {
        let store = VidaStore(persistent: false)
        store.applyEntitlement(
            status: .active,
            source: .appStore,
            expiresAt: Date.now.addingTimeInterval(86_400 * 30),
            detail: "Bought in the app."
        )

        store.reconcileWebMembership(true)

        #expect(store.isPlus)
        #expect(store.entitlement.source == .appStore)
    }

    @Test @MainActor func anEndedWebMembershipReturnsToFree() {
        let store = VidaStore(persistent: false)
        store.reconcileWebMembership(true)

        store.reconcileWebMembership(false)

        #expect(!store.isPlus)
        #expect(store.entitlement.status == .expired)
    }

    @Test @MainActor func noWebRecordNeverEndsAnAppStoreMembership() {
        let store = VidaStore(persistent: false)
        store.applyEntitlement(
            status: .active,
            source: .appStore,
            expiresAt: Date.now.addingTimeInterval(86_400 * 30),
            detail: "Bought in the app."
        )

        store.reconcileWebMembership(false)

        #expect(store.isPlus)
        #expect(store.entitlement.status == .active)
    }

    @Test @MainActor func aFailedLookupChangesNothing() {
        let store = VidaStore(persistent: false)
        store.reconcileWebMembership(true)

        store.reconcileWebMembership(nil)

        #expect(store.isPlus)
        #expect(store.entitlement.source == .web)
    }

    @Test func webMembershipsAreManagedOnTheWebsite() {
        #expect(EntitlementSource.web.label == "vidalab.co")
        #expect(EntitlementSource.web.manageInstruction.contains("vidalab.co"))
        #expect(!EntitlementSource.web.manageInstruction.contains("\u{2014}"))
    }
}
