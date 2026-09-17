import SwiftUI

/// Public authentication screen. Everything beyond this view is protected by
/// the authenticated Supabase session in `ContentView`.
struct SignInView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""

    private enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign in"
        case createAccount = "Create account"

        var id: String { rawValue }
    }

    var body: some View {
        @Bindable var auth = auth

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                modePicker
                fields
                primaryAction
                accountHelp
                privacyNote
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)
            .padding(.bottom, 40)
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
            if newUser != nil { dismiss() }
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
                labeledField("Name", text: $name, contentType: .name)
                    .textInputAutocapitalization(.words)
            }

            labeledField("Email", text: $email, contentType: .emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            VStack(alignment: .leading, spacing: 7) {
                Text("Password")
                    .font(Vida.sans(12, weight: .semibold))
                    .foregroundStyle(Vida.forest)
                SecureField("At least 8 characters", text: $password)
                    .textContentType(mode == .signIn ? .password : .newPassword)
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

    private func labeledField(
        _ label: String,
        text: Binding<String>,
        contentType: UITextContentType
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(Vida.sans(12, weight: .semibold))
                .foregroundStyle(Vida.forest)
            TextField(label, text: text)
                .textContentType(contentType)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Vida.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Vida.hairline, lineWidth: 0.9)
                }
        }
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
                await auth.signUp(email: email, password: password, name: name)
            }
        }
    }
}
