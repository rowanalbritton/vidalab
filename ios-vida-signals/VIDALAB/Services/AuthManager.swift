import Foundation
import Supabase

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

        do {
            user = Self.makeUser(from: try await vidaSupabase.auth.session)
        } catch {
            // A missing or expired session is the normal signed-out state.
            user = nil
        }
    }

    func signIn(email: String, password: String) async {
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
        try await vidaSupabase.functions.invoke("delete-account")
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
