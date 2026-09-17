import SwiftUI

/// Permanent account and data deletion, reachable in-app.
///
/// Deletion is a right, not a retention battle, so there are no guilt-trip
/// screens between here and gone. What there *is*: an exact inventory of what
/// disappears, an honest note about the subscription, and a typed confirmation
/// — because this is the one action in Vida that nothing can undo.
struct DeleteAccountView: View {
    @Environment(VidaStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var typed: String = ""
    @State private var isDeleting: Bool = false
    @State private var finished: Bool = false
    @State private var errorMessage: String?

    private let phrase = "DELETE"

    private var canDelete: Bool {
        typed.trimmingCharacters(in: .whitespaces).uppercased() == phrase && !isDeleting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if finished {
                    doneState
                } else {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        removedList
                        subscriptionNote
                        confirmField
                        deleteButton
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .scrollIndicators(.hidden)
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !finished {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                            .font(Vida.sans(15))
                            .foregroundStyle(Vida.inkSoft)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("DELETE ACCOUNT")
                        .font(Vida.sans(12, weight: .bold))
                        .tracking(2.0)
                        .foregroundStyle(Vida.forest)
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
        .alert(
            "Couldn't finish deleting",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("Try again") { performDeletion() }
            Button("Not now", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This erases\neverything.")
                .font(Vida.serif(32))
                .foregroundStyle(Vida.forest)
                .fixedSize(horizontal: false, vertical: true)
            Text("There's no export step hidden behind this and no thirty-day recovery window. Once it's done, it's done.")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    /// The exact inventory. Vague reassurance is how people end up surprised.
    private var removedList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "What gets deleted")

            row("calendar", "\(store.loggedDayCount) logged day\(store.loggedDayCount == 1 ? "" : "s")",
                "Every check-in, note, tag and symptom you've recorded.")
            HairlineDivider()
            row("flask", "\(store.experiments.count) experiment\(store.experiments.count == 1 ? "" : "s")",
                "Including any results you haven't read yet.")
            HairlineDivider()
            row("text.document", "\(store.preps.count) Doctor Prep\(store.preps.count == 1 ? "" : "s")",
                "Saved snapshots and everything in them.")
            HairlineDivider()
            row("person.crop.circle", "Your profile",
                "Name, photo, conditions, goals and priority signals.")
            HairlineDivider()
            row("heart.text.square", "Apple Health connection",
                "Vida's copy is removed. Apple Health's own records are untouched — Vida only ever read them.")
        }
        .paperCard(padding: 20)
    }

    private func row(_ symbol: String, _ title: String, _ caption: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Vida.clay)
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

    /// Cancelling the subscription first is the part people get burned by.
    @ViewBuilder
    private var subscriptionNote: some View {
        if store.alreadySubscribed {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 13))
                    Text("Cancel your subscription first")
                        .font(Vida.sans(14, weight: .semibold))
                }
                .foregroundStyle(Vida.clay)

                Text("You have an active Vida+ membership billed through \(store.entitlement.source?.label ?? "the App Store"). Deleting your account here does not stop that billing — Apple doesn't allow an app to cancel it for you. \(store.entitlement.source?.manageInstruction ?? "")")
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.inkSoft)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text("Open subscription settings")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(Vida.sans(13, weight: .semibold))
                    .foregroundStyle(Vida.clay)
                    .frame(minHeight: 44)
                }
                .buttonStyle(PressableStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Vida.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Vida.clay.opacity(0.35), lineWidth: 0.9)
            }
        }
    }

    private var confirmField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Type \(phrase) to confirm")
                .font(Vida.sans(15, weight: .semibold))
                .foregroundStyle(Vida.ink)

            TextField(phrase, text: $typed)
                .font(Vida.number(17, weight: .semibold))
                .foregroundStyle(Vida.ink)
                .tint(Vida.clay)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .accessibilityLabel("Type \(phrase) to confirm deletion")
                .padding(16)
                .frame(minHeight: 44)
                .background(Vida.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(canDelete ? Vida.clay : Vida.hairline, lineWidth: 0.9)
                }
        }
    }

    private var deleteButton: some View {
        Button {
            performDeletion()
        } label: {
            ZStack {
                Text("Delete everything permanently")
                    .font(Vida.sans(16, weight: .semibold))
                    .opacity(isDeleting ? 0 : 1)
                if isDeleting {
                    ProgressView().tint(Vida.onClay)
                }
            }
            .foregroundStyle(Vida.onClay)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Vida.clay, in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(!canDelete)
        .opacity(canDelete ? 1 : 0.4)
    }

    private var doneState: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 80)

            Image(systemName: "checkmark.circle")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Vida.moss)

            Text("Everything's gone.")
                .font(Vida.serif(28))
                .foregroundStyle(Vida.forest)

            Text("Your check-ins, experiments, snapshots and profile have been erased from this device, and you've been signed out. Thank you for trying Vida.")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 26)

            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(Vida.sans(16, weight: .semibold))
                    .foregroundStyle(Vida.onForest)
                    .padding(.horizontal, 30)
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

    /// Signs out first so no session outlives the data, then wipes locally.
    private func performDeletion() {
        guard canDelete else { return }
        errorMessage = nil
        isDeleting = true

        Task {
            await auth.signOut()
            store.deleteEverything()
            isDeleting = false
            withAnimation(.smooth(duration: 0.4)) { finished = true }
        }
    }
}
