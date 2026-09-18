import Foundation
import Supabase

/// Raised when the server reported success but the account is still reachable.
///
/// Silently trusting a 200 here would produce the worst outcome this flow can
/// have: telling someone their account is erased while it still exists.
nonisolated enum AccountDeletionError: LocalizedError {
    case accountStillExists

    var errorDescription: String? {
        "Your account could not be confirmed as deleted, so nothing has been erased. Please try again."
    }
}

/// Supabase Auth session state for VIDA LAB.
@Observable
final class AuthManager {
    struct User: Equatable, Sendable {
        let id: String
        let email: String?
        let name: String?
        let picture: String?
    }

    var user: User?
    var isLoading = true
    var isSigningIn = false
    var showError = false
    var errorMessage = ""
    var noticeMessage: String?

    var isSignedIn: Bool { user != nil }

    private var authStateTask: Task<Void, Never>?

    init() {
        // With no credentials there is no session to restore or observe, and
        // leaving `isLoading` true would hold the app on its loading state
        // forever. Settle immediately into signed-out instead.
        guard VidaBackend.isConfigured else {
            isLoading = false
            return
        }

        authStateTask = Task { [weak self] in
            guard let self else { return }

            for await (_, session) in vidaSupabase.auth.authStateChanges {
                self.user = session.map(Self.makeUser)
                self.isLoading = false
            }
        }

        Task { await restoreSession() }
    }

    deinit {
        authStateTask?.cancel()
    }

    func restoreSession() async {
        defer { isLoading = false }
        guard VidaBackend.isConfigured else {
            user = nil
            return
        }

        do {
            user = Self.makeUser(from: try await vidaSupabase.auth.session)
        } catch {
            // A missing or expired session is the normal signed-out state.
            user = nil
        }
    }

    func signIn(email: String, password: String) async {
        guard requireBackend() else { return }
        guard validate(email: email, password: password) else { return }

        isSigningIn = true
        noticeMessage = nil
        defer { isSigningIn = false }

        do {
            let session = try await vidaSupabase.auth.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            user = Self.makeUser(from: session)
        } catch {
            present(error, fallback: "We couldn't sign you in. Check your email and password, then try again.")
        }
    }

    func signUp(email: String, password: String, name: String) async {
        guard requireBackend() else { return }
        guard validate(email: email, password: password) else { return }

        isSigningIn = true
        noticeMessage = nil
        defer { isSigningIn = false }

        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let response = try await vidaSupabase.auth.signUp(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                data: trimmedName.isEmpty ? [:] : ["full_name": .string(trimmedName)]
            )

            if let session = response.session {
                user = Self.makeUser(from: session)
            } else {
                noticeMessage = "Check your email to confirm your account, then come back and sign in."
            }
        } catch {
            present(error, fallback: "We couldn't create your account. Please check your details and try again.")
        }
    }

    func sendPasswordReset(email: String) async {
        guard requireBackend() else { return }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.contains("@") else {
            setError("Enter the email address you used for VIDA LAB first.")
            return
        }

        isSigningIn = true
        noticeMessage = nil
        defer { isSigningIn = false }

        do {
            try await vidaSupabase.auth.resetPasswordForEmail(trimmedEmail)
            noticeMessage = "If an account exists for that email, a password-reset message is on its way."
        } catch {
            present(error, fallback: "We couldn't send the reset email. Please try again in a moment.")
        }
    }

    func signOut() async {
        do {
            try await vidaSupabase.auth.signOut()
        } catch {
            present(error, fallback: "We couldn't sign you out. Please try again.")
            return
        }
        user = nil
    }

    /// Clears the session on this device without asking the server first.
    ///
    /// Used after account deletion. The normal `signOut` calls the server, and
    /// once the auth user is gone that call fails — which previously left the
    /// app believing someone was still signed in, and showed a sign-out error
    /// on top of a successful deletion. A deleted account must always end up
    /// signed out locally, whatever the server says about a user that no
    /// longer exists.
    func signOutLocally() async {
        try? await vidaSupabase.auth.signOut(scope: .local)
        user = nil
    }

    /// Stops account actions early when the build carries no backend
    /// credentials.
    ///
    /// Without this the request runs to its full timeout and then reports a
    /// generic "couldn't sign you in", which sends a developer hunting through
    /// passwords for what is actually a missing build configuration. VIDA LAB
    /// works signed out, so this is a clear message rather than a dead screen.
    private func requireBackend() -> Bool {
        guard VidaBackend.isConfigured else {
            setError("Accounts aren't available in this build. Everything else works, and your entries stay on this device.")
            return false
        }
        return true
    }

    private func validate(email: String, password: String) -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.contains("@") else {
            setError("Enter a valid email address.")
            return false
        }
        guard password.count >= 8 else {
            setError("Your password must be at least 8 characters.")
            return false
        }
        return true
    }

    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }

    private func present(_ error: Error, fallback: String) {
        // Keep provider diagnostics out of the UI; they may contain transport
        // details and are rarely actionable for a member.
        _ = error
        setError(fallback)
    }

    /// Deletes the account itself, server-side.
    ///
    /// Removing the rows is not the same as removing the account: Apple
    /// requires the account to actually cease to exist, and a surviving auth
    /// record would also let the same email collide on a later sign-up. Only a
    /// service-role key can erase an auth user, so this goes through an edge
    /// function that verifies the caller's own session first.
    func deleteAccount() async throws {
        // A live session is required to authorise this, so it must run before
        // any sign-out. The function verifies the caller's own token and
        // deletes that account only.
        try await vidaSupabase.functions.invoke("delete-account")

        // Confirm rather than assume. If the auth user is really gone, the
        // cached token no longer resolves to anyone and this call fails — that
        // failure is the success signal. A token that still resolves means the
        // account survived a "successful" response, and saying "everything's
        // gone" then would be the worst lie this screen could tell.
        let survived = (try? await vidaSupabase.auth.user()) != nil
        if survived {
            throw AccountDeletionError.accountStillExists
        }
    }

    private static func makeUser(from session: Session) -> User {
        let metadata = session.user.userMetadata
        return User(
            // Lowercased deliberately. Postgres renders `auth.uid()::text` in
            // lowercase, and every RLS policy compares against that, while
            // Foundation's `uuidString` is uppercase — so uploading the
            // uppercase form would fail every row-level security check.
            id: session.user.id.uuidString.lowercased(),
            email: session.user.email,
            name: metadata["full_name"]?.stringValue ?? metadata["name"]?.stringValue,
            picture: metadata["avatar_url"]?.stringValue ?? metadata["picture"]?.stringValue
        )
    }
}
