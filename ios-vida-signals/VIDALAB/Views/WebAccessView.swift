import SwiftUI

/// Turning on the website's ability to read her data, without giving Vida the
/// same ability.
///
/// The sync key lives in the iCloud Keychain, which a browser has no route to
/// — so by default the website can fetch her rows and see nothing but
/// ciphertext. This screen closes that gap the only way that doesn't also open
/// it for us: a passphrase she chooses, which wraps a copy of the key
/// (`VidaKeyEscrow`). Vida stores the wrapped bytes and cannot unwrap them.
///
/// The passphrase is therefore genuinely unrecoverable, and the copy here says
/// so in those words rather than "keep it safe".
struct WebAccessView: View {
    @Environment(VidaStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @Environment(VidaSyncService.self) private var sync
    @Environment(\.dismiss) private var dismiss

    /// What the account currently has stored, or `nil` for "web access is off".
    @State private var record: VidaKeyEscrow.WrappedKey?
    @State private var isLoading: Bool = true

    @State private var passphrase: String = ""
    @State private var confirmation: String = ""
    @State private var unlockPassphrase: String = ""

    @State private var isWorking: Bool = false
    @State private var errorMessage: String?
    @State private var confirmTurnOff: Bool = false
    @State private var outcome: Outcome?

    /// What just happened, so the screen can say something specific instead of
    /// silently reverting to its resting state.
    private enum Outcome: Equatable {
        case enabled
        case passphraseChanged
        case unlocked
        case alreadyUnlocked
        case turnedOff

        var symbol: String {
            switch self {
            case .turnedOff: "lock"
            default: "checkmark.circle"
            }
        }

        var title: String {
            switch self {
            case .enabled: "Web access is on."
            case .passphraseChanged: "Passphrase updated."
            case .unlocked: "This phone is unlocked."
            case .alreadyUnlocked: "Already unlocked."
            case .turnedOff: "Web access is off."
            }
        }

        var message: String {
            switch self {
            case .enabled:
                "Sign in at vidalab.co and enter the same passphrase. It's the only thing that can open your entries there. Vida can't, and neither can anyone holding a copy of the database."
            case .passphraseChanged:
                "Your new passphrase is what the website will ask for from now on. The old one no longer opens anything."
            case .unlocked:
                "Vida is pulling your history back down now. Entries saved on your other devices should appear shortly."
            case .alreadyUnlocked:
                "That passphrase matches the key this phone already has, so there was nothing to change. Everything here is readable."
            case .turnedOff:
                "The wrapped copy of your key has been deleted, so the website can no longer open anything. Your entries are untouched and this phone works exactly as before."
            }
        }
    }

    private var userID: String? { auth.user?.id }

    private var trimmedPassphrase: String {
        passphrase.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isLongEnough: Bool {
        trimmedPassphrase.count >= VidaKeyEscrow.minimumPassphraseLength
    }

    private var matches: Bool {
        trimmedPassphrase == confirmation.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        isLongEnough && matches && !isWorking && userID != nil
    }

    private var canUnlock: Bool {
        !unlockPassphrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isWorking
            && record != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if let outcome {
                        doneState(outcome)
                    } else if isLoading {
                        loadingState
                    } else if record == nil {
                        VStack(alignment: .leading, spacing: 24) {
                            offHeader
                            howItWorks
                            passphraseFields
                            enableButton
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 24) {
                            onHeader
                            unlockSection
                            changeSection
                            turnOffButton
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .readableColumn()
            }
            .scrollIndicators(.hidden)
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(outcome == nil ? "Cancel" : "Done") { dismiss() }
                        .font(Vida.sans(15))
                        .foregroundStyle(Vida.inkSoft)
                }
                ToolbarItem(placement: .principal) {
                    Text("WEB ACCESS")
                        .font(Vida.sans(12, weight: .bold))
                        .tracking(2.0)
                        .foregroundStyle(Vida.forest)
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
        .task { await loadStatus() }
        .alert(
            "That didn't work",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Turn off web access?", isPresented: $confirmTurnOff) {
            Button("Turn it off", role: .destructive) { turnOff() }
            Button("Keep it on", role: .cancel) { }
        } message: {
            Text("The website will stop being able to read your entries. This also deletes the wrapped copy of your key, so your iCloud Keychain becomes the only thing holding it again. If you lose that, your backup can't be recovered.")
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 100)
            ProgressView().tint(Vida.moss)
            Text("Checking your account…")
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }

    private var offHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Read your data\non the web.")
                .font(Vida.serif(32))
                .foregroundStyle(Vida.forest)
                .fixedSize(horizontal: false, vertical: true)
            Text("Your entries are encrypted with a key that only your iPhone holds, which is why vidalab.co can't show them to you today. Choose a passphrase and Vida will store a locked copy of that key, one the website can open with your passphrase, and nobody else can open at all.")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var onHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Vida.moss)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Web access is on")
                        .font(Vida.sans(15, weight: .medium))
                        .foregroundStyle(Vida.forest)
                    Text("Sign in at vidalab.co and enter your passphrase.")
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 18)
    }

    /// The three facts that decide whether this is a good idea for her, stated
    /// before she picks a passphrase rather than after.
    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Before you choose one")

            row("eye.slash", "Vida still can't read your entries",
                "The passphrase never leaves this phone. What gets stored is the locked copy, which is useless without it.")
            HairlineDivider()
            row("exclamationmark.triangle", "There is no reset link",
                "Nobody at Vida can recover this or look it up. If you forget it, turn web access off and set a new one from this phone, which only works while you still have a phone that can read your data.")
            HairlineDivider()
            row("textformat.abc", "Longer beats complicated",
                "At least \(VidaKeyEscrow.minimumPassphraseLength) characters. Three or four unrelated words you'll actually remember is stronger than one short word with symbols in it.")
        }
        .paperCard(padding: 20)
    }

    private func row(_ symbol: String, _ title: String, _ caption: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Vida.moss)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Vida.sans(15, weight: .medium))
                    .foregroundStyle(Vida.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(caption)
                    .font(Vida.sans(12))
                    .foregroundStyle(Vida.inkSoft)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Enable

    private var passphraseFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your passphrase")
                    .font(Vida.sans(15, weight: .semibold))
                    .foregroundStyle(Vida.ink)

                // Not a password field: it can't be autofilled, it can't be
                // recovered, and she has to be able to see what she typed.
                TextField("At least \(VidaKeyEscrow.minimumPassphraseLength) characters", text: $passphrase)
                    .textContentType(.newPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .passphraseField(isValid: isLongEnough)

                Text(isLongEnough || trimmedPassphrase.isEmpty
                     ? "Spaces count, and capital letters matter."
                     : "\(VidaKeyEscrow.minimumPassphraseLength - trimmedPassphrase.count) more to go.")
                    .font(Vida.sans(12))
                    .foregroundStyle(Vida.taupe)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Type it again")
                    .font(Vida.sans(15, weight: .semibold))
                    .foregroundStyle(Vida.ink)

                TextField("Confirm your passphrase", text: $confirmation)
                    .textContentType(.newPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .passphraseField(isValid: !confirmation.isEmpty && matches)

                if !confirmation.isEmpty && !matches {
                    Text("These two don't match yet.")
                        .font(Vida.sans(12))
                        .foregroundStyle(Vida.clay)
                }
            }
        }
    }

    private var enableButton: some View {
        Button {
            enable(isChange: false)
        } label: {
            primaryLabel("Turn on web access")
        }
        .buttonStyle(PressableStyle())
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.4)
    }

    // MARK: - Unlock

    /// The path a new phone takes when the iCloud Keychain didn't bring the key
    /// along — without this, restored rows come down as ciphertext the device
    /// can't open and are silently skipped.
    private var unlockSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Unlock this phone")

            Text("If entries you know you logged aren't showing up here, this phone is probably holding a different key. Enter your passphrase to adopt the one your account already uses.")
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Your passphrase", text: $unlockPassphrase)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .passphraseField(isValid: false)

            Button {
                unlock()
            } label: {
                Text("Unlock with passphrase")
                    .font(Vida.sans(14, weight: .semibold))
                    .foregroundStyle(Vida.onForest)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Vida.forest, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .disabled(!canUnlock)
            .opacity(canUnlock ? 1 : 0.4)
        }
        .paperCard(padding: 20)
    }

    // MARK: - Change

    private var changeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow(text: "Change your passphrase")

            Text("Replaces the locked copy with one sealed under a new passphrase. Your entries aren't re-encrypted and nothing needs to re-upload.")
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            passphraseFields

            Button {
                enable(isChange: true)
            } label: {
                primaryLabel("Save new passphrase")
            }
            .buttonStyle(PressableStyle())
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.4)
        }
        .paperCard(padding: 20)
    }

    private var turnOffButton: some View {
        Button {
            confirmTurnOff = true
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "lock.slash")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Vida.clay)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Turn off web access")
                        .font(Vida.sans(15, weight: .medium))
                        .foregroundStyle(Vida.ink)
                    Text("Deletes the locked copy of your key. This phone keeps working.")
                        .font(Vida.sans(12))
                        .foregroundStyle(Vida.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .paperCard(padding: 18)
        }
        .buttonStyle(PressableStyle())
        .disabled(isWorking)
    }

    private func primaryLabel(_ title: String) -> some View {
        ZStack {
            Text(title)
                .font(Vida.sans(16, weight: .semibold))
                .opacity(isWorking ? 0 : 1)
            if isWorking {
                ProgressView().tint(Vida.onForest)
            }
        }
        .foregroundStyle(Vida.onForest)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 17)
        .background(Vida.forest, in: Capsule())
    }

    private func doneState(_ outcome: Outcome) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 80)

            Image(systemName: outcome.symbol)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(outcome == .turnedOff ? Vida.taupe : Vida.moss)

            Text(outcome.title)
                .font(Vida.serif(28))
                .foregroundStyle(Vida.forest)
                .multilineTextAlignment(.center)

            Text(outcome.message)
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 26)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(Vida.sans(16, weight: .semibold))
                    .foregroundStyle(Vida.onForest)
                    .padding(.horizontal, 34)
                    .padding(.vertical, 15)
                    .frame(minHeight: 44)
                    .background(Vida.forest, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 8)

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func loadStatus() async {
        guard let userID else {
            isLoading = false
            return
        }
        record = await sync.wrappedKey(userID: userID)
        isLoading = false
    }

    private func enable(isChange: Bool) {
        guard canSubmit, let userID else { return }
        isWorking = true

        Task {
            do {
                try await sync.enableWebAccess(passphrase: trimmedPassphrase, userID: userID)
                passphrase = ""
                confirmation = ""
                isWorking = false
                withAnimation(.smooth(duration: 0.4)) {
                    outcome = isChange ? .passphraseChanged : .enabled
                }
            } catch {
                isWorking = false
                errorMessage = friendlyMessage(for: error)
            }
        }
    }

    /// Adopting a key is only half the job: rows downloaded under the old key
    /// were skipped as unreadable, so this account's restore marker is cleared
    /// and a sync forced to pull them down again.
    private func unlock() {
        guard canUnlock, let userID, let record else { return }
        let entered = unlockPassphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        isWorking = true

        Task {
            do {
                let recovered = try VidaKeyEscrow.unwrap(record, passphrase: entered)

                // Comparing first keeps the common case honest: re-entering the
                // passphrase on a phone that already has the right key should
                // say "nothing to do", not stage a pointless resync.
                if let current = try? VidaCrypto.exportKeyMaterial(), current == recovered {
                    unlockPassphrase = ""
                    isWorking = false
                    withAnimation(.smooth(duration: 0.4)) { outcome = .alreadyUnlocked }
                    return
                }

                try VidaCrypto.installKeyMaterial(recovered)
                sync.reset(requiresFullRestoreFor: userID)
                unlockPassphrase = ""
                isWorking = false
                withAnimation(.smooth(duration: 0.4)) { outcome = .unlocked }

                await sync.syncIfNeeded(
                    store: store,
                    userID: userID,
                    email: auth.user?.email,
                    name: store.name,
                    force: true
                )
            } catch {
                isWorking = false
                errorMessage = friendlyMessage(for: error)
            }
        }
    }

    private func turnOff() {
        guard let userID else { return }
        isWorking = true

        Task {
            do {
                try await sync.disableWebAccess(userID: userID)
                record = nil
                isWorking = false
                withAnimation(.smooth(duration: 0.4)) { outcome = .turnedOff }
            } catch {
                isWorking = false
                errorMessage = friendlyMessage(for: error)
            }
        }
    }

    /// Escrow errors already speak plainly; anything else is a network or
    /// server problem and gets the sync service's wording.
    private func friendlyMessage(for error: Error) -> String {
        if let escrowError = error as? VidaKeyEscrow.EscrowError {
            return escrowError.errorDescription ?? "Vida couldn't use that passphrase."
        }
        return VidaSyncService.plainMessage(for: error)
    }
}

private extension View {
    /// Shared chrome for the passphrase inputs on this screen.
    func passphraseField(isValid: Bool) -> some View {
        font(Vida.sans(16))
            .foregroundStyle(Vida.ink)
            .tint(Vida.moss)
            .padding(16)
            .frame(minHeight: 44)
            .background(Vida.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isValid ? Vida.moss : Vida.hairline, lineWidth: 0.9)
            }
    }
}
