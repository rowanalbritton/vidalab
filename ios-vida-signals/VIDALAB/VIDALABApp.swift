//
//  VIDALABApp.swift
//  VIDA LAB
//
//  Created by Rork on September 17, 2026.
//

import SwiftUI

@main
struct VIDALABApp: App {
    /// Kept for the process lifetime so StoreKit's update stream is never torn
    /// down. Unfinished transactions are replayed forever, so something must
    /// always be listening.
    @State private var transactionListener: Task<Void, Never>?

    init() {
        // Once, at launch, before any view can ask about membership.
        // No-ops when no key is present, so the app still runs.
        RevenueCatMembershipService.configureIfPossible()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Only when RevenueCat isn't in charge: its SDK finishes
                    // transactions itself, and two listeners racing to finish
                    // the same transaction would lose purchases.
                    guard !RevenueCatMembershipService.isConfigured,
                          transactionListener == nil else { return }
                    transactionListener = StoreKitMembershipService.startObservingTransactions()
                }
        }
    }
}
