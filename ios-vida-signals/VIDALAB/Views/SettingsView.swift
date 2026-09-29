import SwiftUI
import PhotosUI

struct SettingsView: View {
    @Environment(VidaStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @Environment(VidaSyncService.self) private var sync
    @State private var showPaywall: Bool = false
    @State private var confirmReset: Bool = false
    @State private var confirmSeed: Bool = false
    @State private var showHealth: Bool = false
    @State private var showOrientation: Bool = false
    @State private var showReport: Bool = false
    @State private var showEmailSetup: Bool = false
    @State private var confirmSignOut: Bool = false
    @State private var showDeleteAccount: Bool = false
    @State private var showWebAccess: Bool = false
    /// `nil` until the account has been asked. Keeps the row from claiming
    /// "off" during the round trip, which would read as a broken setting.
    @State private var webAccessOn: Bool?
    @State private var aiSummarySharingOn: Bool?
    @State private var showingGuidelines: Bool = false
    @State private var showTour: Bool = false
    @AppStorage(AIDisclosure.acceptedKey) private var aiDisclosureAccepted: Bool = false
    @AppStorage(ClaudeInsightsDisclosure.acceptedKey) private var claudeInsightsAccepted: Bool = false
    /// Only ever a count. The block list itself is not readable by design —
    /// see `community_blocks` in the schema.
    @State private var blockedCount: Int = 0
    /// Its own instance: this screen only calls the block RPCs, and does not
    /// need the post and reply caches the Community tab holds.
    @State private var communityService = CommunityService()
    private var push: PushNotificationService { .shared }
    @State private var photoItem: PhotosPickerItem?
    @State private var nameField: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                profile
                account
                healthPicture
                membership
                stats
                appearance
                reports
                connections
                aiHealthSummaryConsent
                notifications
                community
                howVidaWorks
                privacy
                dataControls
                brandFooter
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
            ToolbarItem(placement: .principal) {
                Text("YOU")
                    .font(Vida.sans(12, weight: .bold))
                    .tracking(2.4)
                    .foregroundStyle(Vida.forest)
            }
        }
        .toolbarBackground(Vida.cream, for: .navigationBar)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showHealth) { HealthSyncView() }
        .sheet(isPresented: $showReport) { WeeklyReportView() }
        .sheet(isPresented: $showOrientation) { OrientationView() }
        .sheet(isPresented: $showEmailSetup) { ReportEmailSetupView { } }
        .sheet(isPresented: $showDeleteAccount) { DeleteAccountView() }
        .fullScreenCover(isPresented: $showTour) { AppTourView() }
        .sheet(isPresented: $showWebAccess) {
            WebAccessView()
        }
        .onAppear { nameField = store.name }
        .task(id: auth.user?.id) {
            await refreshWebAccess()
            await refreshAIHealthSummarySharing()
        }
        .onChange(of: showWebAccess) { _, isPresented in
            // The sheet can turn web access on or off, so the row is re-read
            // when it closes rather than left showing the stale answer.
            if !isPresented { Task { await refreshWebAccess() } }
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task { await loadPhoto(newItem) }
        }
        .alert("Clear all your data?", isPresented: $confirmReset) {
            Button("Clear everything", role: .destructive) {
                store.resetEverything()
            }
            Button("Keep it", role: .cancel) { }
        } message: {
            Text("This permanently removes every check-in, experiment and snapshot on this device. It can't be undone.")
        }
        .alert("Sign out?", isPresented: $confirmSignOut) {
            Button("Sign out", role: .destructive) {
                Task {
                    await auth.signOut()
                    // Sync state is cleared without touching the account's
                    // independent completed-restore marker.
                    sync.reset()
                }
            }
            Button("Stay signed in", role: .cancel) { }
        } message: {
            Text("Your check-ins stay on this device either way. Signing out only ends the account session and pauses encrypted backup.")
        }
    }

    /// Photos are downscaled before storage: a full-resolution image in a
    /// UserDefaults snapshot would bloat every save the app makes.
    private func loadPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }

        let side: CGFloat = 512
        let scale = max(side / image.size.width, side / image.size.height)
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }

        store.avatarData = resized.jpegData(compressionQuality: 0.8)
        store.save()
    }

    // MARK: - Profile

    private var profile: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    ZStack(alignment: .bottomTrailing) {
                        AvatarView(data: store.avatarData, name: nameField, size: 74)
                        Circle()
                            .fill(Vida.moss)
                            .frame(width: 24, height: 24)
                            .overlay {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Vida.onForest)
                            }
                            .overlay { Circle().strokeBorder(Vida.paper, lineWidth: 2) }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "Your name")
                    TextField("Your first name", text: $nameField)
                        .font(Vida.serif(24))
                        .foregroundStyle(Vida.forest)
                        .tint(Vida.moss)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .onSubmit(saveName)
                        .padding(.vertical, 4)
                        .overlay(alignment: .bottom) { HairlineDivider() }
                }
            }

            if store.avatarData != nil {
                Button {
                    store.avatarData = nil
                    photoItem = nil
                    store.save()
                } label: {
                    Text("Remove photo")
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.taupe)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .paperCard(padding: 20)
    }

    private func saveName() {
        store.name = nameField.trimmingCharacters(in: .whitespaces)
        store.save()
    }

    // MARK: - Account

    private var account: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Account")

            if let user = auth.user {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Vida.moss)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Signed in")
                                .font(Vida.sans(15, weight: .medium))
                                .foregroundStyle(Vida.forest)
                            Text(user.email ?? "Signed in")
                                .font(Vida.sans(13))
                                .foregroundStyle(Vida.inkSoft)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }

                    Button {
                        confirmSignOut = true
                    } label: {
                        Text("Sign out")
                            .font(Vida.sans(14, weight: .medium))
                            .foregroundStyle(Vida.inkSoft)
                    }
                    .buttonStyle(PressableStyle())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .paperCard(padding: 18)
            } else {
                NavigationLink {
                    SignInView()
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "person.badge.key")
                            .font(.system(size: 15, weight: .light))
                            .foregroundStyle(Vida.moss)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Create an account")
                                .font(Vida.sans(15, weight: .medium))
                                .foregroundStyle(Vida.forest)
                            Text("It keeps your Vida+ membership if you change phones.")
                                .font(Vida.sans(12))
                                .foregroundStyle(Vida.inkSoft)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Vida.taupe)
                            .padding(.top, 3)
                    }
                    .paperCard(padding: 18)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    // MARK: - Health picture

    private var healthPicture: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Your health picture")

            Button {
                showOrientation = true
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 15, weight: .light))
                            .foregroundStyle(Vida.moss)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.profile.hasAnyCondition ? store.profile.conditionSummary : "Tell Vida what you're dealing with")
                                .font(Vida.sans(15, weight: .medium))
                                .foregroundStyle(Vida.forest)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(healthPictureCaption)
                                .font(Vida.sans(12))
                                .foregroundStyle(Vida.inkSoft)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Vida.taupe)
                            .padding(.top, 3)
                    }

                    if !store.profile.worstSymptoms.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 7)], alignment: .leading, spacing: 7) {
                            ForEach(store.profile.worstSymptoms) { category in
                                HStack(spacing: 5) {
                                    Image(systemName: category.symbol)
                                        .font(.system(size: 10))
                                        .foregroundStyle(category.accent)
                                    Text(category.title)
                                        .font(Vida.sans(12))
                                        .foregroundStyle(Vida.inkSoft)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Vida.sage.opacity(0.16), in: Capsule())
                            }
                        }
                    }
                }
                .paperCard(padding: 18)
            }
            .buttonStyle(PressableStyle())
        }
    }

    private var healthPictureCaption: String {
        var parts: [String] = []
        if !store.profile.worstSymptoms.isEmpty {
            parts.append("\(store.profile.worstSymptoms.count) priority signal\(store.profile.worstSymptoms.count == 1 ? "" : "s")")
        }
        if !store.profile.goals.isEmpty {
            parts.append("\(store.profile.goals.count) goal\(store.profile.goals.count == 1 ? "" : "s")")
        }
        if parts.isEmpty {
            return "Conditions, worst symptoms and goals. It shapes your whole app."
        }
        return parts.joined(separator: " · ") + " · tap to edit"
    }

    // MARK: - Appearance

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Appearance")

            HStack(spacing: 8) {
                ForEach(VidaAppearance.allCases) { mode in
                    Button {
                        withAnimation(Vida.Motion.gentle) {
                            store.appearance = mode
                            store.save()
                        }
                    } label: {
                        VStack(spacing: 7) {
                            Image(systemName: mode.symbol)
                                .font(.system(size: 17, weight: .light))
                            Text(mode.title)
                                .font(Vida.sans(13, weight: store.appearance == mode ? .semibold : .regular))
                            Text(mode.caption)
                                .font(Vida.sans(10))
                                .opacity(0.75)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(store.appearance == mode ? Vida.onForest : Vida.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(store.appearance == mode ? Vida.forest : Vida.paper)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(store.appearance == mode ? .clear : Vida.hairline.opacity(0.7), lineWidth: 0.7)
                        }
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(mode.title). \(mode.caption)")
                    .accessibilityAddTraits(store.appearance == mode ? [.isButton, .isSelected] : .isButton)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Appearance")
        }
    }

    // MARK: - Reports

    private var reports: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Weekly report")

            Button {
                showReport = true
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(Vida.skyDeep)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Read this week")
                            .font(Vida.sans(15, weight: .medium))
                            .foregroundStyle(Vida.forest)
                        Text(store.reportEmail.isEmpty
                             ? "A plain summary of how your week went, yours to read or send."
                             : "Sending to \(store.reportEmail)")
                            .font(Vida.sans(12))
                            .foregroundStyle(Vida.inkSoft)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Vida.taupe)
                        .padding(.top, 3)
                }
                .paperCard(padding: 18)
            }
            .buttonStyle(PressableStyle())

            Button {
                showEmailSetup = true
            } label: {
                Text(store.reportEmail.isEmpty ? "Set up email delivery" : "Change email address")
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.moss)
            }
            .buttonStyle(PressableStyle())
        }
    }

    private var freeAllowances: some View {
        VStack(alignment: .leading, spacing: 7) {
            allowanceLine("\(store.askRemaining) of \(VidaStore.freeAskLimit) Ask Vida questions left today")
            allowanceLine("\(store.freeExperimentsRemaining) of \(VidaStore.freeExperimentLimit) experiment slots open")
            allowanceLine(store.canCreatePrep ? "Your free Health Snapshot is unused" : "Free Health Snapshot used")
        }
        .padding(.top, 2)
    }

    private func allowanceLine(_ text: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(Vida.moss).frame(width: 4, height: 4)
            Text(text)
                .font(Vida.sans(13))
                .foregroundStyle(Vida.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var membership: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12))
                Text(store.isPlus ? "VIDA+" : "VIDA FREE")
                    .font(Vida.sans(11, weight: .bold))
                    .tracking(1.8)
            }
            .foregroundStyle(Vida.moss)

            Text(store.isPlus ? "You have everything." : "You have unlimited check-ins, three patterns, two labs and a snapshot.")
                .font(Vida.serif(20))
                .foregroundStyle(Vida.forest)
                .fixedSize(horizontal: false, vertical: true)

            // Billing problems and countdowns are never silent, and never
            // lock anything on their own.
            if let title = store.entitlement.noticeTitle,
               let message = store.entitlement.noticeMessage {
                EntitlementNotice(
                    title: title,
                    message: message,
                    isUrgent: store.entitlement.noticeIsUrgent,
                    actionLabel: store.entitlement.status == .grace ? "Update payment" : nil
                ) {
                    openSubscriptionSettings()
                }
            }

            if store.isPlus {
                if !store.planName.isEmpty {
                    Text(planSummary)
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Opens Apple's own subscription screen. This used to mark the
                // membership cancelled locally, but an app cannot stop an App
                // Store renewal — Apple would have kept charging while Vida
                // said it was cancelled. The real status arrives through the
                // normal store reconciliation on the next foreground.
                Button {
                    openSubscriptionSettings()
                } label: {
                    Text("Manage or cancel subscription")
                        .font(Vida.sans(14, weight: .medium))
                        .foregroundStyle(Vida.inkSoft)
                        .frame(minHeight: 44)
                }
                .buttonStyle(PressableStyle())
            } else {
                freeAllowances
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 6) {
                        Text("Explore Vida+")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .font(Vida.sans(14, weight: .semibold))
                    .foregroundStyle(Vida.onForest)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Vida.forest, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Vida.sage.opacity(0.22), Vida.sky.opacity(0.16)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Vida.moss.opacity(0.28), lineWidth: 0.9)
        }
    }

    /// Plan line that names the actual renewal or end date rather than the
    /// vague "renews automatically".
    private var planSummary: String {
        let plan = store.planName
        guard let expiry = store.entitlement.expiresAt else {
            return "\(plan) plan"
        }
        let date = Entitlement.dayFormatter.string(from: expiry)
        switch store.entitlement.status {
        case .cancelled: return "\(plan) plan · ends \(date)"
        case .grace: return "\(plan) plan · payment overdue"
        default: return "\(plan) plan · renews \(date)"
        }
    }

    /// Cancellation copy that states the exact date access ends.
    /// Sends her to the real place a subscription can be changed.
    private func openSubscriptionSettings() {
        // A website membership can only be changed on the website.
        UIApplication.shared.open(
            store.entitlement.source == .web ? VidaLinks.webMembership : VidaLinks.manageSubscription
        )
    }

    private var stats: some View {
        HStack(spacing: 0) {
            statCell("\(store.loggedDayCount)", "days logged")
            Rectangle().fill(Vida.hairline).frame(width: 0.8, height: 40)
            statCell("\(store.streak)", "day streak")
            Rectangle().fill(Vida.hairline).frame(width: 0.8, height: 40)
            statCell("\(store.meaningfulLinks.count)", "connections")
        }
        .paperCard(padding: 18)
    }

    private func statCell(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Vida.serif(26))
                .foregroundStyle(Vida.forest)
                .monospacedDigit()
            Text(label)
                .font(Vida.sans(11))
                .foregroundStyle(Vida.taupe)
        }
        .frame(maxWidth: .infinity)
    }

    /// Once connected, this row should read as maintenance-free — she never has
    /// to come back and press anything.
    private var healthCaption: String {
        guard store.healthSyncEnabled else {
            return "Bring in sleep and movement from your Oura ring, Apple Watch, Garmin or Fitbit."
        }
        let count = store.healthReadingCount
        let readings = "\(count) reading\(count == 1 ? "" : "s")"
        if let last = store.lastHealthSync {
            return "Updating automatically · \(readings) · last checked \(last.formatted(.relative(presentation: .named)))"
        }
        return "Updating automatically · \(readings)"
    }

    private var connections: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Connections")
            Button {
                showHealth = true
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(Vida.moss)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Apple Health")
                            .font(Vida.sans(15, weight: .medium))
                            .foregroundStyle(Vida.forest)
                        Text(healthCaption)
                            .font(Vida.sans(12))
                            .foregroundStyle(Vida.inkSoft)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Vida.taupe)
                        .padding(.top, 3)
                }
                .paperCard(padding: 18)
            }
            .buttonStyle(PressableStyle())

            // Signed out there is no cloud copy to reach, so there is nothing
            // for a browser to read and nothing to configure.
            if auth.isSignedIn {
                Button {
                    showWebAccess = true
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: webAccessOn == true ? "globe.badge.chevron.backward" : "globe")
                            .font(.system(size: 15, weight: .light))
                            .foregroundStyle(Vida.skyDeep)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Read your data on the web")
                                .font(Vida.sans(15, weight: .medium))
                                .foregroundStyle(Vida.forest)
                            Text(webAccessCaption)
                                .font(Vida.sans(12))
                                .foregroundStyle(Vida.inkSoft)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Vida.taupe)
                            .padding(.top, 3)
                    }
                    .paperCard(padding: 18)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private var webAccessCaption: String {
        switch webAccessOn {
        case true: "On. vidalab.co can open your entries with your passphrase."
        case false: "Off. Set a passphrase to read your check-ins at vidalab.co."
        case nil: "Checking…"
        }
    }

    private func refreshWebAccess() async {
        guard let userID = auth.user?.id else {
            webAccessOn = nil
            return
        }
        webAccessOn = await sync.hasWebAccess(userID: userID)
    }

    private func refreshAIHealthSummarySharing() async {
        guard let userID = auth.user?.id else {
            aiSummarySharingOn = nil
            return
        }
        aiSummarySharingOn = await AskVidaAIService.healthSummarySharingEnabled(for: userID)
    }

    private func setAIHealthSummarySharing(_ enabled: Bool) {
        guard let userID = auth.user?.id else { return }
        let previous = aiSummarySharingOn
        aiSummarySharingOn = enabled
        Task {
            do {
                try await AskVidaAIService.setHealthSummarySharing(enabled, for: userID)
            } catch {
                aiSummarySharingOn = previous
            }
        }
    }

    private var aiHealthSummaryConsent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Ask Vida AI")

            // Withdraws the 5.1.2(i) permission given on first use. Off means
            // questions the cited library can't answer are never sent to AI.
            Toggle("Let Ask Vida use AI", isOn: $aiDisclosureAccepted)
                .font(Vida.sans(14, weight: .medium))
                .tint(Vida.moss)
            Text(aiDisclosureAccepted
                 ? "When the cited library has no answer, your question is sent to \(AIDisclosure.providerDescription) to write one. Never used for advertising."
                 : "Off. Questions the cited library can't answer won't be sent anywhere.")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            HairlineDivider()

            Text("You can let Ask Vida include a small, on-device summary of your tracking context. It never sends raw check-ins, meals, Apple Health samples, encrypted backups, or your full history.")
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("Include my approved health summary", isOn: Binding(
                get: { aiSummarySharingOn ?? false },
                set: setAIHealthSummarySharing
            ))
            .font(Vida.sans(14, weight: .medium))
            .tint(Vida.moss)
            .disabled(!auth.isSignedIn || aiSummarySharingOn == nil)

            Text(aiSummarySharingOn == true
                 ? "On. You can turn this off at any time."
                 : "Off. Ask Vida only receives the question you type.")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.inkSoft)

            HairlineDivider()

            // Withdraws the permission Body Weather, the Differential, and the
            // Concierge ask for on first use. Turning it off also removes the
            // results saved on this device.
            Eyebrow(text: "Vida+ tools")
            Toggle("Let Vida+ tools use AI", isOn: Binding(
                get: { claudeInsightsAccepted },
                set: { enabled in
                    claudeInsightsAccepted = enabled
                    if !enabled, let userID = auth.user?.id {
                        VidaPlusInsightsService.clearAll(userID: userID)
                    }
                }
            ))
            .font(Vida.sans(14, weight: .medium))
            .tint(Vida.moss)
            Text(claudeInsightsAccepted
                 ? "Body Weather, the Vida Differential, and the Appointment Concierge send a summary of your check-in scores and tags to Anthropic to write your result. Never your notes, meals, medications, or Apple Health data."
                 : "Off. You'll be asked before anything is sent.")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Vida.sky.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Reminders. Asked for here rather than at launch, because iOS offers the
    /// permission prompt once and a cold one on first run is the version most
    /// people decline.
    private var notifications: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Reminders")

            Text("A nudge when a check-in is open or your weekly report is ready. Vida never puts a symptom, score or note in a notification, because a lock screen is not a private place.")
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            switch push.status {
            case .denied:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notifications are off for Vida in iOS Settings.")
                        .font(Vida.sans(13, weight: .medium))
                        .foregroundStyle(Vida.ink)
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(Vida.sans(13, weight: .semibold))
                    .foregroundStyle(Vida.forest)
                    .frame(minHeight: 44)
                }

            case .registered:
                Label("Reminders are on for this iPhone", systemImage: "checkmark.circle.fill")
                    .font(Vida.sans(13, weight: .medium))
                    .foregroundStyle(Vida.forest)
                    .frame(minHeight: 44)

            case .notAsked, .unknown:
                Button("Turn on reminders") {
                    Task { await push.requestAuthorization() }
                }
                .font(Vida.sans(14, weight: .semibold))
                .foregroundStyle(Vida.forest)
                .frame(minHeight: 44)

            case .pending:
                Text("Waiting for Apple to finish setting this up. It usually takes a moment.")
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.inkSoft)
                    .frame(minHeight: 44)
            }

            if !auth.isSignedIn {
                Text("Reminders need an account, since they're sent from Vida's server rather than scheduled on this phone.")
                    .font(Vida.sans(12))
                    .foregroundStyle(Vida.taupe)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Vida.sky.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .task { await push.refreshStatus() }
    }

    /// Community safety in one place: the rules, the block list, and a real
    /// address to write to. Guideline 1.2 expects all three to be findable
    /// without going through a post.
    private var community: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Community")

            Button {
                showingGuidelines = true
            } label: {
                HStack {
                    Text("Community guidelines")
                        .font(Vida.sans(14, weight: .medium))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Vida.taupe)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Vida.ink)

            HairlineDivider()

            // The blocked people themselves are deliberately not listed:
            // naming them would hand back the author_id the board hides.
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(blockedCount == 1 ? "1 person blocked" : "\(blockedCount) people blocked")
                        .font(Vida.sans(14, weight: .medium))
                        .foregroundStyle(Vida.ink)
                    Text("Vida doesn't list who, so nobody can be identified from this screen.")
                        .font(Vida.sans(12))
                        .foregroundStyle(Vida.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if blockedCount > 0 {
                    Button("Unblock all") {
                        Task { await unblockEveryone() }
                    }
                    .font(Vida.sans(13, weight: .semibold))
                    .foregroundStyle(Vida.forest)
                    .frame(minHeight: 44)
                }
            }

            HairlineDivider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Reach a person about moderation")
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.inkSoft)
                Link(VidaLinks.supportAddress, destination: VidaLinks.support)
                    .font(Vida.sans(14, weight: .medium))
                    .foregroundStyle(Vida.forest)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Email VIDA LAB support at \(VidaLinks.supportAddress)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Vida.blush.opacity(0.14), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .task { await refreshBlockedCount() }
        .sheet(isPresented: $showingGuidelines) {
            CommunityGuidelinesView(isGate: false)
        }
    }

    private func refreshBlockedCount() async {
        guard auth.isSignedIn else { return }
        blockedCount = await communityService.blockedCount()
    }

    private func unblockEveryone() async {
        try? await communityService.unblockEveryone()
        await refreshBlockedCount()
    }

    /// Replays the tour. Settings is where people look when they've
    /// forgotten what a tab is for, and the first-week card may be gone.
    private var howVidaWorks: some View {
        Button {
            showTour = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "map")
                    .font(.system(size: 17))
                    .foregroundStyle(Vida.moss)
                    .frame(width: 26)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("How Vida works")
                        .font(Vida.sans(15, weight: .medium))
                        .foregroundStyle(Vida.ink)
                    Text("A two-minute tour of every tab and the habits that make it useful.")
                        .font(Vida.sans(12))
                        .foregroundStyle(Vida.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Vida.taupe)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .paperCard(padding: 20)
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Privacy")
            Text(auth.isSignedIn ? syncedPrivacyCopy : localOnlyPrivacyCopy)
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            // Reachable without hunting: required for HealthKit apps, and the
            // place people look when they want the full policy.
            LegalLinksRow(tint: Vida.forest)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Vida.sage.opacity(0.14), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Signed out, nothing has ever left the phone.
    private let localOnlyPrivacyCopy = "Everything you log lives on this device: your check-ins, your meals, your photo, your health picture, and anything read from Apple Health. Without an account nothing is uploaded anywhere. Vida doesn't sell your data and doesn't share it with whoever pays for a Family plan. Your body is your business."

    /// Signed in, a backup exists — and the wording has to say so plainly.
    /// Claiming "nothing leaves your phone" while running sync would be the
    /// kind of privacy promise that ends up in a regulator's screenshot.
    ///
    /// Which is also why this splits on web access. "A key only your iPhone
    /// and your iCloud Keychain hold" is true right up until she turns on web
    /// access, at which point a passphrase-sealed copy of that key is sitting
    /// in Vida's database — still unreadable, but no longer only in two
    /// places. A promise that quietly stops being true is worse than one that
    /// was never made.
    private var syncedPrivacyCopy: String {
        webAccessOn == true ? webAccessPrivacyCopy : keychainOnlyPrivacyCopy
    }

    private let keychainOnlyPrivacyCopy = "Your check-ins and meals are backed up so they survive a lost phone, but they're encrypted on this device first, with a key only your iPhone and your iCloud Keychain hold. Vida stores the result and cannot read any of it: not a symptom, not a score, not a note, not a meal. Apple Health data is read-only and never sent anywhere. Vida doesn't sell your data and doesn't share it with whoever pays for a Family plan. Your body is your business."

    private let webAccessPrivacyCopy = "Your check-ins and meals are backed up so they survive a lost phone, but they're encrypted on this device first, with a key your iPhone and your iCloud Keychain hold. Because you turned on web access, Vida also stores a copy of that key sealed with your passphrase, so vidalab.co can open your entries when you type it there. That sealed copy is useless without the passphrase, and the passphrase itself never leaves your device. Vida never receives it and cannot reset it. Vida stores the result and cannot read any of it: not a symptom, not a score, not a note, not a meal. Apple Health data is read-only and never sent anywhere. Vida doesn't sell your data and doesn't share it with whoever pays for a Family plan. Your body is your business."

    private var dataControls: some View {
        VStack(spacing: 10) {
            Button {
                confirmSeed = true
            } label: {
                settingRow("wand.and.sparkles", "Load sample data", "Replaces your logs with nine weeks of example signals.")
            }
            .buttonStyle(PressableStyle())
            .alert("Replace your data with samples?", isPresented: $confirmSeed) {
                Button("Load samples", role: .destructive) { store.seedDemoData() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This overwrites everything you've logged with nine weeks of example signals.")
            }

            Button {
                confirmReset = true
            } label: {
                settingRow("trash", "Clear all data", "Permanently removes everything on this device.", destructive: true)
            }
            .buttonStyle(PressableStyle())

            // Deletion has to be reachable in the app itself, not buried in an
            // email to support.
            Button {
                showDeleteAccount = true
            } label: {
                settingRow(
                    "person.crop.circle.badge.xmark",
                    "Delete account and data",
                    "Erases your profile and everything you've logged, and signs you out.",
                    destructive: true
                )
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func settingRow(_ symbol: String, _ title: String, _ subtitle: String, destructive: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(destructive ? Vida.blush : Vida.moss)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Vida.sans(15, weight: .medium))
                    .foregroundStyle(destructive ? Vida.ink : Vida.forest)
                Text(subtitle)
                    .font(Vida.sans(12))
                    .foregroundStyle(Vida.inkSoft)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .paperCard(padding: 18)
    }

    private var brandFooter: some View {
        VStack(spacing: 8) {
            HairlineDivider().padding(.bottom, 8)
            VidaLockup(size: .large, showsAttribution: true)
                .padding(.bottom, 2)
            Text("Health science, translated for women who are done being dismissed.")
                .font(Vida.serifItalic(15))
                .foregroundStyle(Vida.moss)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("VIDA LAB is an educational tool. It does not diagnose, treat, or replace care from a qualified clinician.")
                .font(Vida.sans(11))
                .foregroundStyle(Vida.taupe)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}
