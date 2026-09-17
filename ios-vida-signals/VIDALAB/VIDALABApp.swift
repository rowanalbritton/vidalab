//
//  VIDALABApp.swift
//  VIDA LAB
//
//  Created by Rork on September 17, 2026.
//

import SwiftUI

@main
struct VIDALABApp: App {
    init() {
        // Once, at launch, before any view can ask about membership.
        // No-ops when no key is present, so the app still runs.
        RevenueCatMembershipService.configureIfPossible()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
