import Foundation
import Supabase
import UIKit
import UserNotifications

/// Registers this device for remote notifications and hands the APNs token to
/// Supabase.
///
/// Two deliberate constraints:
///
/// 1. **Nothing here ever carries health detail.** A push tells someone Vida is
///    waiting, never what it noticed. "Your evening check-in is open" is fine;
///    naming a symptom on a lock screen other people can see is not, and
///    guideline 5.1.3 treats that as health data leaving the app.
/// 2. **Permission is asked for in context, never at launch.** A cold prompt on
///    first run is the one most people decline, and iOS only offers it once.
@Observable
@MainActor
final class PushNotificationService: NSObject {
    enum Status: Equatable {
        case unknown
        case notAsked
        case denied
        case registered
        /// Permission was granted but APNs has not returned a token yet, or
        /// registration failed. Worth distinguishing: the member said yes, so
        /// the fix is retrying rather than asking again.
        case pending(String?)
    }

    private(set) var status: Status = .unknown

    /// Set by the app delegate the moment APNs answers, which can be before
    /// anything is signed in. Held so sign-in can upload it retroactively.
    private var pendingToken: String?
    private var isSignedIn = false

    static let shared = PushNotificationService()

    /// `aps-environment` decides which APNs host issued this token, and sending
    /// to the wrong one fails with BadDeviceToken. Debug builds always talk to
    /// sandbox; TestFlight and App Store builds talk to production.
    private static var environment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }

    // MARK: - Permission

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            status = .notAsked
        case .denied:
            status = .denied
        case .authorized, .provisional, .ephemeral:
            status = pendingToken == nil ? .pending(nil) : .registered
        @unknown default:
            status = .unknown
        }
    }

    /// Asks, then registers. Returns whether the member said yes, so a caller
    /// can leave its toggle where it was if they didn't.
    @discardableResult
    func requestAuthorization() async -> Bool {
        UNUserNotificationCenter.current().delegate = self
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                status = .pending(nil)
                UIApplication.shared.registerForRemoteNotifications()
            } else {
                status = .denied
            }
            return granted
        } catch {
            status = .pending(error.localizedDescription)
            return false
        }
    }

    /// Re-registers a device that has already agreed. Cheap, and APNs can
    /// rotate a token at any time, so this runs on every foreground.
    func registerIfAlreadyAuthorized() async {
        await refreshStatus()
        guard status != .denied, status != .notAsked else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    func turnOff() async {
        guard let token = pendingToken else { return }
        // The row is disabled rather than deleted so the environment survives.
        // Deleting and re-registering later would be equivalent, but this keeps
        // "she turned it off" distinguishable from "we never had a token".
        try? await vidaSupabase
            .from("push_tokens")
            .update(["enabled": false])
            .eq("device_token", value: token)
            .execute()
        status = .pending(nil)
    }

    // MARK: - Token handoff

    func accept(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        pendingToken = token
        status = .registered
        Task { await uploadPendingToken() }
    }

    func registrationFailed(_ error: Error) {
        status = .pending(error.localizedDescription)
    }

    /// Called after sign-in, and after the token arrives. Whichever happens
    /// last is the one that performs the upload — a token cannot be stored
    /// before there is an account to attach it to.
    func accountDidChange(isSignedIn: Bool) async {
        self.isSignedIn = isSignedIn
        guard isSignedIn else { return }
        await uploadPendingToken()
    }

    private func uploadPendingToken() async {
        guard isSignedIn, let token = pendingToken else { return }
        do {
            try await vidaSupabase
                .rpc("claim_push_token", params: PushTokenClaim(
                    deviceToken: token,
                    environment: Self.environment,
                    locale: Locale.current.identifier
                ))
                .execute()
        } catch {
            #if DEBUG
            #if DEBUG
            print("[VidaPush] token upload failed: \(error)")
            #endif
            #endif
        }
    }
}

extension PushNotificationService: UNUserNotificationCenterDelegate {
    /// Showing the banner even while Vida is open. A reminder that silently
    /// does nothing because the app happened to be foregrounded reads as a
    /// notification that never arrived.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

/// Parameters for `claim_push_token`.
nonisolated struct PushTokenClaim: Encodable, Sendable {
    let deviceToken: String
    let environment: String
    let locale: String?

    enum CodingKeys: String, CodingKey {
        case deviceToken = "p_device_token"
        case environment = "p_environment"
        case locale = "p_locale"
    }
}
