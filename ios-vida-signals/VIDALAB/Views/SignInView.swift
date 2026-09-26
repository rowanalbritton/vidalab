import AuthenticationServices
import CryptoKit
import SwiftUI

/// Public authentication screen. Everything beyond this view is protected by
/// the authenticated Supabase session in `ContentView`.
struct SignInView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    /// Starts at today so nobody passes the age check by leaving it untouched,
    /// and so the screen doesn't hint at which answer gets through.
    @State private var birthDate = Date.now
    @State private var hasSetBirthDate = false
    @State private var ageMessage: String?
    /// The unhashed nonce for the Apple request in flight. Apple receives its
    /// SHA-256; Supabase receives this, and rejects the token if they differ.
    @State private var appleNonce: String?
    @FocusState private var focusedField: Field?
    /// Remembered on this device after an under-16 answer, so the check can't
    /// be passed by immediately going back and picking an older date.
    @AppStorage("vida.signup.ageIneligible") private var ageIneligible = false

    /// Minimum age to create an account. Keep in sync with the App Store
    /// description, Terms, and Privacy Policy.
    static let minimumAge = 16

    private enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign in"
        case createAccount = "Create account"

        var id: String { rawValue }
    }

    /// Return moves through the fields in order, and the focused one is
    /// scrolled into view, so the keyboard never hides the field being typed.
    private enum Field: Hashable {
        case name, email, password
    }

    var body: some View {
        @Bindable var auth = auth

        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if auth.needsAgeConfirmation {
                    ageConfirmation
                } else {
                    modePicker
                    if mode == .createAccount && ageIneligible {
                        ageIneligibleNotice
                    } else {
                        fields
                        primaryAction
                        socialSignIn
                    }
                    accountHelp
                }
                privacyNote
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)
            .padding(.bottom, 40)
        }
        .onChange(of: focusedField) { _, field in
            guard let field else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(field, anchor: .center)
            }
        }
        }
        // Tapping outside a field doesn't close the keyboard, and on Create
        // account it covers the button, so offer an explicit way out.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
                    .font(Vida.sans(15, weight: .semibold))
                    .foregroundStyle(Vida.moss)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .vidaBackground()
        .navigationBarTitleDisplayMode(.inline)
        .alert("Account problem", isPresented: $auth.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(auth.errorMessage)
        }
        .onChange(of: auth.user) { _, newUser in
            if let newUser, store.name.isEmpty, let name = newUser.name {
                store.name = name.split(separator: " ").first.map(String.init) ?? name
                store.save()
            }
        }
        .onChange(of: auth.isSignedIn) { _, signedIn in
            if signedIn { dismiss() }
        }
        .onChange(of: auth.suggestSignIn) { _, suggest in
            guard suggest else { return }
            mode = .signIn
            auth.suggestSignIn = false
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image("Mark")
                .resizable()
                .scaledToFit()
                .frame(width: 62, height: 62)
                .accessibilityHidden(true)
            Eyebrow(text: "VIDA LAB")
            Text("Your patterns,\nkept private.")
                .font(Vida.serif(32))
                .foregroundStyle(Vida.forest)
                .lineSpacing(1)
            Text("Sign in to securely access your check-ins, patterns, and encrypted backup.")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modePicker: some View {
        Picker("Account action", selection: $mode) {
            ForEach(Mode.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: mode) { _, _ in
            auth.noticeMessage = nil
            password = ""
        }
    }

    private var fields: some View {
        VStack(spacing: 14) {
            if mode == .createAccount {
                labeledField("Name", text: $name, contentType: .name, field: .name, next: .email)
                    .textInputAutocapitalization(.words)
            }

            if mode == .createAccount {
                birthDateField
            }

            labeledField("Email", text: $email, contentType: .emailAddress, field: .email, next: .password)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            VStack(alignment: .leading, spacing: 7) {
                Text("Password")
                    .font(Vida.sans(12, weight: .semibold))
                    .foregroundStyle(Vida.forest)
                SecureField("At least 8 characters", text: $password)
                    .textContentType(mode == .signIn ? .password : .newPassword)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { submit() }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Vida.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Vida.hairline, lineWidth: 0.9)
                    }
            }
            .id(Field.password)

            if let notice = auth.noticeMessage {
                Text(notice)
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.forest)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Vida.sage.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var birthDateField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Date of birth")
                .font(Vida.sans(12, weight: .semibold))
                .foregroundStyle(Vida.forest)
            // One row when it fits, stacked when it doesn't. At the largest
            // accessibility sizes in portrait the compact picker needs nearly
            // the whole width, which squeezed the prompt to zero width: it
            // vanished and wrapped into an invisible column that made the
            // field several times taller than the ones around it.
            ViewThatFits(in: .horizontal) {
                HStack {
                    birthDatePrompt
                        .fixedSize()
                    Spacer(minLength: 12)
                    birthDatePicker
                }
                VStack(alignment: .leading, spacing: 10) {
                    birthDatePrompt
                        .fixedSize(horizontal: false, vertical: true)
                    birthDatePicker
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Vida.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Vida.hairline, lineWidth: 0.9)
            }
            .onChange(of: birthDate) { _, _ in
                hasSetBirthDate = true
                ageMessage = nil
            }
            Text("Used once to confirm you can create an account. VIDA LAB doesn't store your birthday.")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(3)
            if let ageMessage {
                Text(ageMessage)
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.forest)
                    .lineSpacing(3)
            }
        }
    }

    private var birthDatePrompt: some View {
        Text(hasSetBirthDate ? birthDate.formatted(date: .long, time: .omitted) : "Choose a date")
            .font(Vida.sans(15))
            .foregroundStyle(hasSetBirthDate ? Vida.forest : Vida.inkSoft)
    }

    private var birthDatePicker: some View {
        DatePicker("Date of birth", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
            .labelsHidden()
            .datePickerStyle(.compact)
    }

    private var ageIneligibleNotice: some View {
        Text("VIDA LAB accounts are for people \(Self.minimumAge) and older, so we can't create one on this device right now. If you have questions about your health, a parent, school nurse, or doctor is a good place to start, and we'd love to see you here when you're \(Self.minimumAge).")
            .font(Vida.sans(14))
            .foregroundStyle(Vida.forest)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Vida.sage.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func labeledField(
        _ label: String,
        text: Binding<String>,
        contentType: UITextContentType,
        field: Field,
        next: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(Vida.sans(12, weight: .semibold))
                .foregroundStyle(Vida.forest)
            TextField(label, text: text)
                .textContentType(contentType)
                .focused($focusedField, equals: field)
                .submitLabel(.next)
                .onSubmit { focusedField = next }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Vida.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Vida.hairline, lineWidth: 0.9)
                }
        }
        .id(field)
    }

    private var primaryAction: some View {
        Button(action: submit) {
            HStack(spacing: 9) {
                if auth.isSigningIn {
                    ProgressView().tint(Vida.onForest)
                }
                Text(mode == .signIn ? "Sign in" : "Create account")
            }
            .font(Vida.sans(16, weight: .semibold))
            .foregroundStyle(Vida.onForest)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Vida.forest, in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(auth.isSigningIn)
    }

    // MARK: - Apple and Google

    private var socialSignIn: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Rectangle().fill(Vida.hairline).frame(height: 0.9)
                Text("or")
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.inkSoft)
                Rectangle().fill(Vida.hairline).frame(height: 0.9)
            }
            .accessibilityHidden(true)

            SignInWithAppleButton(.continue) { request in
                let nonce = Self.randomNonce()
                appleNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = Self.sha256(nonce)
            } onCompletion: { result in
                handleApple(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 52)
            .clipShape(Capsule())
            // Recreated on appearance change so the button style follows it.
            .id(colorScheme)

            Button {
                Task { await auth.signInWithGoogle() }
            } label: {
                HStack(spacing: 10) {
                    Text("G")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(Vida.moss)
                        .accessibilityHidden(true)
                    Text("Continue with Google")
                        .font(Vida.sans(16, weight: .semibold))
                        .foregroundStyle(Vida.forest)
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Vida.paper, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Vida.hairline, lineWidth: 0.9)
                }
            }
            .buttonStyle(PressableStyle())

            if mode == .createAccount {
                Text("With Apple or Google, we'll ask your date of birth once before you start.")
                    .font(Vida.sans(12))
                    .foregroundStyle(Vida.inkSoft)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .disabled(auth.isSigningIn)
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = appleNonce
            else {
                auth.errorMessage = "We couldn't sign you in with Apple. Please try again."
                auth.showError = true
                return
            }
            Task {
                await auth.signInWithApple(
                    idToken: idToken,
                    rawNonce: nonce,
                    fullName: credential.fullName,
                    authorizationCode: credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
                )
            }
        case .failure(let error):
            // Closing Apple's sheet is a choice, not a failure.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            auth.errorMessage = "We couldn't sign you in with Apple. Please try again."
            auth.showError = true
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in characters.randomElement(using: &generator)! })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - One-time age check for Apple and Google accounts

    private var ageConfirmation: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("One last thing before you start. VIDA LAB accounts are for people \(Self.minimumAge) and older.")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.forest)
                .lineSpacing(4)
            birthDateField
            Button(action: confirmAge) {
                HStack(spacing: 9) {
                    if auth.isSigningIn {
                        ProgressView().tint(Vida.onForest)
                    }
                    Text("Continue")
                }
                .font(Vida.sans(16, weight: .semibold))
                .foregroundStyle(Vida.onForest)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Vida.forest, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .disabled(auth.isSigningIn)

            Button {
                Task { await auth.signOutLocally() }
            } label: {
                Text("Use a different account")
                    .font(Vida.sans(14, weight: .medium))
                    .foregroundStyle(Vida.moss)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(auth.isSigningIn)
        }
    }

    private func confirmAge() {
        guard hasSetBirthDate else {
            ageMessage = "Add your date of birth to continue."
            return
        }
        let age = Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 0
        Task {
            if age >= Self.minimumAge {
                await auth.confirmAge()
            } else {
                ageIneligible = true
                mode = .createAccount
                await auth.removeIneligibleAccount()
            }
        }
    }

    private var accountHelp: some View {
        Button {
            Task { await auth.sendPasswordReset(email: email) }
        } label: {
            Text("Forgot your password?")
                .font(Vida.sans(14, weight: .medium))
                .foregroundStyle(Vida.moss)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(auth.isSigningIn)
        .opacity(mode == .signIn ? 1 : 0)
        .accessibilityHidden(mode != .signIn)
    }

    private var privacyNote: some View {
        Text("Your account protects access to VIDA LAB. Health entries are encrypted on your device before backup, and VIDA LAB never stores your password.")
            .font(Vida.sans(12))
            .foregroundStyle(Vida.inkSoft)
            .lineSpacing(4)
            .padding(16)
            .background(Vida.sage.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func submit() {
        Task {
            switch mode {
            case .signIn:
                await auth.signIn(email: email, password: password)
            case .createAccount:
                guard !ageIneligible else { return }
                guard hasSetBirthDate else {
                    ageMessage = "Add your date of birth to create an account."
                    return
                }
                let age = Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 0
                guard age >= Self.minimumAge else {
                    ageIneligible = true
                    return
                }
                await auth.signUp(email: email, password: password, name: name, ageConfirmed: true)
            }
        }
    }
}
