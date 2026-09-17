import SwiftUI
import AuthenticationServices

/// Account creation, framed honestly.
///
/// VIDA LAB works completely without an account, and this screen says so out
/// loud. The people this app is for have been asked to hand over personal
/// information by a great many services that did not deserve it — so the offer
/// here is specific about what an account does and, more importantly, what it
/// does not touch.
struct SignInView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var auth = auth

        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                benefits
                signInButtons
                privacyNote
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .vidaBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("ACCOUNT")
                    .font(Vida.sans(12, weight: .bold))
                    .tracking(2.4)
                    .foregroundStyle(Vida.forest)
            }
        }
        .toolbarBackground(Vida.cream, for: .navigationBar)
        .alert("Sign-in problem", isPresented: $auth.showError) {
            if auth.canRetry {
                Button("Try again") {
                    Task { await auth.retryLastAttempt() }
                }
            }
            Button("Continue without an account", role: .cancel) { dismiss() }
        } message: {
            Text(auth.errorMessage)
        }
        .onChange(of: auth.user) { _, newUser in
            // Borrow the name from the account only if she never gave one.
            if let newUser, store.name.isEmpty, let name = newUser.name {
                store.name = name.split(separator: " ").first.map(String.init) ?? name
                store.save()
            }
            if newUser != nil { dismiss() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Optional")
            Text("Keep your data\nif you change phones.")
                .font(Vida.serif(30))
                .foregroundStyle(Vida.forest)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
            Text("Vida works perfectly without an account — everything you log is already saved on this device. An account exists so a year of your own records isn't lost with a broken phone.")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefitRow("iphone.and.arrow.forward", "Move to a new phone",
                       "Your membership follows your account.")
            HairlineDivider()
            benefitRow("envelope", "Weekly reports by email",
                       "Sent from your own Mail app, to an address you choose.")
            HairlineDivider()
            benefitRow("lock", "Your symptoms stay here",
                       "Check-ins, notes and photos never leave this device.")
        }
        .paperCard(padding: 20)
    }

    private func benefitRow(_ symbol: String, _ title: String, _ caption: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(Vida.moss)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Vida.sans(15, weight: .medium))
                    .foregroundStyle(Vida.forest)
                Text(caption)
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.inkSoft)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var signInButtons: some View {
        VStack(spacing: 11) {
            Button {
                Task { await auth.signIn(provider: "apple") }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 16))
                    Text("Continue with Apple")
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
                Task { await auth.signIn(provider: "google") }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "globe")
                        .font(.system(size: 15))
                    Text("Continue with Google")
                }
                .font(Vida.sans(16, weight: .medium))
                .foregroundStyle(Vida.forest)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background {
                    Capsule().fill(Vida.paper)
                }
                .overlay {
                    Capsule().strokeBorder(Vida.hairline, lineWidth: 0.9)
                }
            }
            .buttonStyle(PressableStyle())
            .disabled(auth.isSigningIn)

            if auth.isSigningIn {
                HStack(spacing: 8) {
                    ProgressView().tint(Vida.moss)
                    Text("Opening sign-in…")
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                }
                .padding(.top, 4)
            }

            Button {
                dismiss()
            } label: {
                Text("Not now")
                    .font(Vida.sans(14))
                    .foregroundStyle(Vida.taupe)
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 4)
        }
    }

    private var privacyNote: some View {
        Text("Signing in shares only your name and email address with Vida. It never gives us access to your health records, and your check-ins are not uploaded.")
            .font(Vida.sans(12))
            .foregroundStyle(Vida.inkSoft)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Vida.sage.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
