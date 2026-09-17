import SwiftUI
import AuthenticationServices
import CryptoKit

/// Account layer for VIDA LAB.
///
/// An account here exists for one reason: so that a year of her own data
/// survives a lost phone, and so a weekly report has somewhere to be sent.
/// It is deliberately optional — the entire app works signed out, because
/// requiring an account before someone can log a symptom is a good way to
/// lose the person who needed it most.
@Observable
final class AuthManager {
    var user: User?
    var isLoading: Bool = true
    var isSigningIn: Bool = false
    var showError: Bool = false
    var errorMessage: String = ""

    private let authURL = Config.EXPO_PUBLIC_RORK_AUTH_URL
    private let appKey = Config.EXPO_PUBLIC_RORK_APP_KEY
    private let projectID = Config.EXPO_PUBLIC_PROJECT_ID
    private var codeVerifier: String?
    private var webAuthSession: ASWebAuthenticationSession?

    /// The action to re-run once the member resolves an error.
    ///
    /// Every failure path stores what was being attempted, so the alert can
    /// offer a real "Try again" instead of just apologising.
    private var lastAttempt: (() async -> Void)?
    var canRetry: Bool = false

    /// Every network call in this app fails within 15 seconds.
    ///
    /// URLSession's default is 60s per request and seven days for a resource,
    /// which on a bad connection looks identical to the app having frozen.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// Injected by Rork into UserDefaults at install time on the iOS Simulator
    /// only. Computed rather than cached: the write can land after launch.
    private var developerHint: String? {
        UserDefaults.standard.string(forKey: "RORK_DEVELOPER_HINT")
    }

    nonisolated struct User: Codable, Equatable {
        let id: String
        let email: String
        let name: String?
        let picture: String?
    }

    var isSignedIn: Bool { user != nil }

    init() {
        Task { await checkAuth() }
    }

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private var authEnv: String {
        #if targetEnvironment(simulator)
        return "simulator"
        #else
        return "native"
        #endif
    }

    /// Decode the JWT payload locally. The signature was verified by Rork when
    /// the token was issued; we only need the claims and the expiry.
    private func userFromToken(_ token: String) -> User? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }

        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }

        guard let data = Data(base64Encoded: base64) else { return nil }

        struct JWTPayload: Codable {
            let sub: String
            let email: String?
            let name: String?
            let picture: String?
            let exp: TimeInterval?
        }

        guard let payload = try? JSONDecoder().decode(JWTPayload.self, from: data) else { return nil }

        if let exp = payload.exp, Date(timeIntervalSince1970: exp) < Date() {
            return nil
        }

        return User(id: payload.sub, email: payload.email ?? "", name: payload.name, picture: payload.picture)
    }

    private func getRefreshToken() -> String? {
        #if targetEnvironment(simulator)
        if let injected = UserDefaults.standard.string(forKey: "RORK_AUTH_REFRESH_TOKEN") {
            return injected
        }
        #endif
        return KeychainHelper.get("refresh_token")
    }

    @MainActor
    func checkAuth() async {
        defer { isLoading = false }

        if let accessToken = KeychainHelper.get("access_token"),
           let user = userFromToken(accessToken) {
            self.user = user
            return
        }

        if getRefreshToken() != nil {
            await refreshToken()
        }
    }

    @MainActor
    func signIn(provider: String) async {
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            let verifier = generateCodeVerifier()
            let challenge = generateCodeChallenge(from: verifier)
            codeVerifier = verifier

            guard let url = URL(string: "\(authURL)/oauth/initiate") else {
                setError("Something went wrong starting sign-in.")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            var initiateBody: [String: String] = [
                "app_key": appKey,
                "provider": provider,
                "code_challenge": challenge,
                "target": "swift",
                "env": authEnv
            ]
            if authEnv == "simulator", let hint = developerHint {
                initiateBody["developer_hint"] = hint
            }
            request.httpBody = try JSONEncoder().encode(initiateBody)

            let (data, response) = try await Self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    setError(errorResponse.error) { [weak self] in
                        await self?.signIn(provider: provider)
                    }
                } else {
                    setError("Sign-in isn't available right now. Your data is safe on this device either way.") { [weak self] in
                        await self?.signIn(provider: provider)
                    }
                }
                return
            }
            let initiateResponse = try JSONDecoder().decode(InitiateResponse.self, from: data)

            let code: String
            if initiateResponse.flow == "popup" {
                do {
                    code = try await pollForCode(state: initiateResponse.state)
                } catch AuthError.cancelledByUser {
                    code = try await runWebAuthSession(authURL: initiateResponse.auth_url)
                }
            } else {
                code = try await runWebAuthSession(authURL: initiateResponse.auth_url)
            }

            await exchangeCode(code)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return
        } catch {
            setError(Self.plainMessage(for: error)) { [weak self] in
                await self?.signIn(provider: provider)
            }
        }
    }

    private func pollForCode(state: String) async throws -> String {
        guard let url = URL(string: "\(authURL)/oauth/poll-code") else {
            throw AuthError.invalidURL
        }

        let deadline = Date().addingTimeInterval(5 * 60)
        while Date() < deadline {
            try await Task.sleep(for: .milliseconds(1500))

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["app_key": appKey, "state": state])

            let (data, response) = try await Self.session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
            guard let pollResponse = try? JSONDecoder().decode(PollCodeResponse.self, from: data) else { continue }

            if pollResponse.status == "cancelled" {
                throw AuthError.cancelledByUser
            }
            if pollResponse.status == "ready", let code = pollResponse.code {
                return code
            }
        }

        throw AuthError.popupTimeout
    }

    private func runWebAuthSession(authURL authURLString: String) async throws -> String {
        let callbackScheme = "rork-\(projectID)"
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            guard let url = URL(string: authURLString) else {
                continuation.resume(throwing: AuthError.invalidURL)
                return
            }

            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                self?.webAuthSession = nil

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let url = callbackURL,
                      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthError.noCode)
                    return
                }

                continuation.resume(returning: code)
            }

            self.webAuthSession = session
            session.presentationContextProvider = WebAuthPresentationContext.shared
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    @MainActor
    private func exchangeCode(_ code: String) async {
        guard let verifier = codeVerifier else { return }
        codeVerifier = nil

        guard let url = URL(string: "\(authURL)/oauth/token") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode([
            "app_key": appKey,
            "code": code,
            "code_verifier": verifier
        ])

        do {
            let (data, response) = try await Self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    setError(errorResponse.error)
                } else {
                    setError("Sign-in didn't complete. Please try again.")
                }
                return
            }
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

            KeychainHelper.set("access_token", value: tokenResponse.access_token)
            KeychainHelper.set("refresh_token", value: tokenResponse.refresh_token)

            user = tokenResponse.user
        } catch {
            setError(Self.plainMessage(for: error))
        }
    }

    @MainActor
    private func refreshToken() async {
        guard let storedRefreshToken = getRefreshToken() else {
            user = nil
            return
        }

        guard let url = URL(string: "\(authURL)/oauth/refresh") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode([
            "app_key": appKey,
            "refresh_token": storedRefreshToken
        ])

        do {
            let (data, response) = try await Self.session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                // A rejected refresh token means the session is genuinely over.
                await signOut()
                return
            }

            let refreshResponse = try JSONDecoder().decode(RefreshResponse.self, from: data)
            KeychainHelper.set("access_token", value: refreshResponse.access_token)
            user = userFromToken(refreshResponse.access_token)
        } catch {
            // Being offline is not the same as being signed out. Dropping the
            // session here would log someone out of a plane, and on landing
            // they'd look like a brand-new free user.
            if let urlError = error as? URLError,
               [.notConnectedToInternet, .networkConnectionLost, .timedOut,
                .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed].contains(urlError.code) {
                return
            }
            await signOut()
        }
    }

    @MainActor
    func signOut() async {
        KeychainHelper.delete("access_token")
        KeychainHelper.delete("refresh_token")
        UserDefaults.standard.removeObject(forKey: "RORK_AUTH_REFRESH_TOKEN")
        user = nil
    }

    private func setError(_ message: String, retry: (() async -> Void)? = nil) {
        errorMessage = message
        lastAttempt = retry
        canRetry = retry != nil
        showError = true
    }

    /// Re-runs whatever failed. Called by the "Try again" button in the alert.
    @MainActor
    func retryLastAttempt() async {
        guard let attempt = lastAttempt else { return }
        lastAttempt = nil
        canRetry = false
        await attempt()
    }

    /// Turns a transport failure into something a person can act on.
    ///
    /// Never surfaces a URLError code or a decoding message: "The operation
    /// couldn't be completed (NSURLErrorDomain error -1009)" tells someone
    /// nothing about what to do next.
    nonisolated static func plainMessage(for error: Error) -> String {
        guard let urlError = error as? URLError else {
            return "Sign-in didn't complete. You can try again, or keep using Vida without an account — everything works either way."
        }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "You're offline, so sign-in can't finish. Your check-ins are saved on this device regardless — reconnect and try again whenever."
        case .timedOut:
            return "The connection took too long and Vida stopped waiting. Try again in a moment."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "Vida couldn't reach the sign-in service. It's likely a temporary outage — your data is safe on this device."
        default:
            return "Sign-in didn't complete. You can try again, or keep using Vida without an account."
        }
    }
}

// MARK: - Response types

private nonisolated struct InitiateResponse: Codable {
    let auth_url: String
    let state: String
    let flow: String?
}

private nonisolated struct PollCodeResponse: Codable {
    let status: String
    let code: String?
}

private nonisolated struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let user: AuthManager.User
}

private nonisolated struct RefreshResponse: Codable {
    let access_token: String
    let expires_in: Int
}

private nonisolated struct ErrorResponse: Codable {
    let error: String
}

nonisolated enum AuthError: LocalizedError {
    case noCode
    case invalidURL
    case serverError(statusCode: Int)
    case popupTimeout
    case cancelledByUser

    var errorDescription: String? {
        switch self {
        case .noCode: "No authorization code received"
        case .invalidURL: "Invalid URL"
        case .serverError(let code): "Server error (\(code))"
        case .popupTimeout: "Sign-in timed out — please try again"
        case .cancelledByUser: "Sign-in cancelled"
        }
    }
}

// MARK: - Presentation anchor

final class WebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthPresentationContext()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
