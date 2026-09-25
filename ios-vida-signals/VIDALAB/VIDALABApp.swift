//
//  VIDALABApp.swift
//  VIDA LAB
//
//  Created by Rork on September 17, 2026.
//

import SwiftUI
import UIKit

/// Only here for APNs. The device token arrives through a UIKit delegate
/// callback that SwiftUI has no equivalent for, so this is the smallest
/// possible bridge rather than a general-purpose delegate.
final class VidaAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationService.shared.accept(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationService.shared.registrationFailed(error)
        }
    }
}

@main
struct VIDALABApp: App {
    @UIApplicationDelegateAdaptor(VidaAppDelegate.self) private var appDelegate
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
