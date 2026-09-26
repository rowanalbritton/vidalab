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
    /// Set when the server said the email is already registered, so the sign-in
    /// screen can switch itself to the Sign in tab.
    var suggestSignIn = false
    /// True for a signed-in session that has never passed the 16+ age check.
    /// Apple and Google sign-in skip the sign-up form's date-of-birth field, so
    /// those accounts are asked once before the rest of the app opens.
    var needsAgeConfirmation = false

    var isSignedIn: Bool { user != nil && !needsAgeConfirmation }

    static let ageConfirmedKey = "age_confirmed_16_plus"

    private var authStateTask: Task<Void, Never>?

    init() {
        authStateTask = Task { [weak self] in
            guard let self else { return }

            for await (event, session) in vidaSupabase.auth.authStateChanges {
                // The initial value now comes directly from local storage. Do
                // not grant signed-in UI state for an expired token while the
                // SDK refreshes it in the background.
                let live = session.flatMap { $0.isExpired ? nil : $0 }
                self.user = live.map(Self.makeUser(from:))
                self.needsAgeConfirmation = live.map { !Self.hasConfirmedAge($0.user) } ?? false
                self.isLoading = false

                if event == .initialSession, live != nil {
                    Task { await self.dropSessionIfAccountIsGone() }
                }
            }
        }
    }

    /// A saved session outlives its account: the access token stays valid for
    /// up to an hour after the account is deleted (here or on the website), and
    /// iOS keeps the saved session through a reinstall. Asking the server once
    /// at launch catches that. Only answers that mean "this account or session
    /// no longer exists" sign out, so being offline never does.
    private func dropSessionIfAccountIsGone() async {
        do {
            _ = try await vidaSupabase.auth.user()
        } catch let error as AuthError {
            switch error.errorCode {
            case .userNotFound, .sessionNotFound, .badJWT, .refreshTokenNotFound:
                await signOutLocally()
                needsAgeConfirmation = false
            default:
                break
            }
        } catch {
            // Network trouble: keep the session and try again next launch.
        }
    }

    deinit {
        authStateTask?.cancel()
    }

    func signIn(email: String, password: String) async {
        guard validateEmail(email) else { return }
        guard !password.isEmpty else {
            setError("Enter your password.")
            return
        }

        isSigningIn = true
        noticeMessage = nil
        defer { isSigningIn = false }

        do {
            let session = try await vidaSupabase.auth.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            apply(session)
        } catch {
            present(error, fallback: "We couldn't sign you in. Check your email and password, then try again.")
        }
    }

    /// Finishes Sign in with Apple. `rawNonce` is the unhashed value whose
    /// SHA-256 went into the Apple request; Supabase checks the two match.
    func signInWithApple(
        idToken: String,
        rawNonce: String,
        fullName: PersonNameComponents?,
        authorizationCode: String?
    ) async {
        isSigningIn = true
        noticeMessage = nil
        defer { isSigningIn = false }

        do {
            let session = try await vidaSupabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: rawNonce)
            )
            // Apple shares the name only on the very first sign-in, and never
            // inside the token, so it has to be saved now or not at all.
            if let fullName,
               session.user.userMetadata["full_name"]?.stringValue == nil {
                let formatted = PersonNameComponentsFormatter().string(from: fullName)
                if !formatted.isEmpty {
                    _ = try? await vidaSupabase.auth.update(user: UserAttributes(data: ["full_name": .string(formatted)]))
                }
            }
            let current = (try? await vidaSupabase.auth.session) ?? session
            apply(current)
            storeAppleRefreshToken(authorizationCode)
        } catch {
            present(error, fallback: "We couldn't sign you in with Apple. Please try again.")
        }
    }

    /// Google sign-in through Supabase's hosted page in a secure browser sheet,
    /// so no Google SDK is needed. The redirect URL must be allowed in the
    /// Supabase dashboard under Authentication, URL Configuration.
    func signInWithGoogle() async {
        isSigningIn = true
        noticeMessage = nil
        defer { isSigningIn = false }

        do {
            let session = try await vidaSupabase.auth.signInWithOAuth(
                provider: .google,
                redirectTo: Self.oauthRedirect
            )
            apply(session)
        } catch {
            // Closing the sheet is a choice, not a failure.
            if Self.isUserCancellation(error) { return }
            present(error, fallback: "We couldn't sign you in with Google. Please try again.")
        }
    }

    /// Records a passed age check on the account, then opens the app.
    func confirmAge() async {
        isSigningIn = true
        defer { isSigningIn = false }

        do {
            _ = try await vidaSupabase.auth.update(
                user: UserAttributes(data: [Self.ageConfirmedKey: .bool(true)])
            )
            needsAgeConfirmation = false
        } catch {
            present(error, fallback: "We couldn't save that. Please check your connection and try again.")
        }
    }

    /// An Apple or Google sign-in that failed the age check. The account was
    /// created a moment ago by that sign-in, so it is erased rather than kept.
    func removeIneligibleAccount() async {
        _ = try? await vidaSupabase.functions.invoke("delete-account")
        await signOutLocally()
        needsAgeConfirmation = false
    }

    static let oauthRedirect = URL(string: "app.vidalab://login-callback")!

    /// Hands Apple's one-time code to the server, which trades it for a token
    /// it can revoke if this account is ever deleted (Guideline 5.1.1(v)). The
    /// code expires in five minutes, so this runs straight after sign-in. It
    /// never affects the sign-in itself; a failure only means deletion can't
    /// revoke Apple's access, which Apple also ends on its own over time.
    private func storeAppleRefreshToken(_ code: String?) {
        guard let code, !code.isEmpty else { return }
        Task {
            _ = try? await vidaSupabase.functions.invoke(
                "apple-token-exchange",
                options: FunctionInvokeOptions(body: ["code": code])
            )
        }
    }

    private func apply(_ session: Session) {
        user = Self.makeUser(from: session)
        needsAgeConfirmation = !Self.hasConfirmedAge(session.user)
    }

    static func hasConfirmedAge(_ user: Supabase.User) -> Bool {
        user.userMetadata[ageConfirmedKey]?.boolValue == true
    }

    private static func isUserCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == "com.apple.AuthenticationServices.WebAuthenticationSession"
            && nsError.code == 1
    }

    /// `ageConfirmed` records only that the sign-up screen's age check passed
    /// (16 or older). The birth date itself is never sent or stored.
    func signUp(email: String, password: String, name: String, ageConfirmed: Bool = false) async {
        guard validate(email: email, password: password) else { return }

        isSigningIn = true
        noticeMessage = nil
        defer { isSigningIn = false }

        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let response = try await vidaSupabase.auth.signUp(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                data: {
                    var metadata: [String: AnyJSON] = ["age_confirmed_16_plus": .bool(ageConfirmed)]
                    if !trimmedName.isEmpty { metadata["full_name"] = .string(trimmedName) }
                    return metadata
                }()
            )

            if let session = response.session {
                apply(session)
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

    /// Full validation for sign-up, where this app is the one choosing the
    /// password policy.
    private func validate(email: String, password: String) -> Bool {
        guard validateEmail(email) else { return false }
        guard password.count >= 8 else {
            setError("Your password must be at least 8 characters.")
            return false
        }
        return true
    }

    /// Sign-in only checks the email is well-formed. The password itself is
    /// the server's call to make — an account's real password may have been
    /// set before this app's 8-character rule existed, or by another client
    /// entirely, so rejecting it here would lock out a correct password.
    private func validateEmail(_ email: String) -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.contains("@") else {
            setError("Enter a valid email address.")
            return false
        }
        return true
    }

    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }

    private func present(_ error: Error, fallback: String) {
        // Raw provider messages stay out of the UI; they may contain transport
        // details. The known cases get plain explanations instead, because a
        // single generic message made a taken email or a wrong password look
        // like the app itself was broken.
        if let authError = error as? AuthError {
            switch authError.errorCode {
            case .userAlreadyExists, .emailExists:
                suggestSignIn = true
                setError("An account with this email already exists. Sign in instead, or tap \"Forgot your password?\" if you don't remember it.")
                return
            case .invalidCredentials:
                setError("That email and password don't match. If you first joined with Apple or Google, use that button instead.")
                return
            case .emailNotConfirmed:
                setError("Confirm your email first. Open the link we sent you, then sign in.")
                return
            case .weakPassword:
                setError("Choose a stronger password with at least 8 characters, mixing letters and numbers.")
                return
            case .overRequestRateLimit, .overEmailSendRateLimit:
                setError("Too many tries in a row. Wait a minute, then try again.")
                return
            case .validationFailed, ErrorCode("email_address_invalid"):
                setError("Check that your email address is typed correctly, then try again.")
                return
            default:
                break
            }
        }
        if error is URLError {
            setError("You seem to be offline. Check your connection and try again.")
            return
        }
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
