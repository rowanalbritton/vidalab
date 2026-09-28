import SwiftUI

enum RootTab: String, CaseIterable, Identifiable {
    // Community sits next to Ask deliberately. The two are the same question
    // asked of different sources — Ask answers from cited research and
    // refuses to guess, Community answers from other people's experience and
    // makes no such claim. Keeping them adjacent makes the difference legible.
    case home, patterns, ask, community, lab, library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Today"
        case .patterns: "Patterns"
        case .ask: "Ask"
        case .community: "Community"
        case .lab: "Lab"
        case .library: "Library"
        }
    }

    var symbol: String {
        switch self {
        case .home: "leaf"
        case .patterns: "point.3.connected.trianglepath.dotted"
        case .ask: "bubble.left.and.text.bubble.right"
        case .community: "person.2"
        case .lab: "flask"
        case .library: "books.vertical"
        }
    }
}

struct ContentView: View {
    @State private var store = VidaStore()
    @State private var health = HealthImportService()
    @State private var auth = AuthManager()
    @State private var sync = VidaSyncService()
    @State private var tab: RootTab = .home
    @State private var showFirstCheckIn: Bool = false
    @State private var showTour: Bool = false
    /// The Vida+ offer that closes onboarding, and whether the check-in the
    /// tour ended on should open once it's dismissed.
    @State private var showWelcomeOffer: Bool = false
    @State private var checkInAfterOffer: Bool = false
    /// The welcome curtain, raised once per cold launch. Not persisted on
    /// purpose: it belongs to the act of opening the app, not to the account.
    @State private var showWelcome: Bool = true
    @State private var keyboardVisible = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // The app is composed underneath the curtain rather than after it,
            // so lifting the welcome reveals a screen that has already settled
            // — including Home's own entrance animation, which has finished by
            // the time anyone sees it.
            rootContent
                .scaleEffect(showWelcome && !reduceMotion ? 0.97 : 1)
                .opacity(showWelcome ? 0 : 1)

            if showWelcome {
                WelcomeView { showWelcome = false }
                    .transition(welcomeTransition)
                    .zIndex(1)
            }
        }
        .animation(revealAnimation, value: showWelcome)
        .fullScreenCover(isPresented: $showTour) {
            AppTourView { startCheckIn in
                // New members see what Vida+ adds once they've seen the app,
                // then land in the check-in they chose. Anything presented
                // while the tour's cover is still closing is dropped, so this
                // waits out its dismissal.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if store.isPlus {
                        if startCheckIn { showFirstCheckIn = true }
                    } else {
                        checkInAfterOffer = startCheckIn
                        showWelcomeOffer = true
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showWelcomeOffer, onDismiss: {
            guard checkInAfterOffer else { return }
            checkInAfterOffer = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showFirstCheckIn = true }
        }) {
            PaywallView(context: .onboarding)
        }
        .sheet(isPresented: $showFirstCheckIn) {
            CheckInFlow(period: store.nextPeriod ?? store.currentPeriod)
        }
        // Sign-in, onboarding and the app fade into each other slowly.
        .animation(.smooth(duration: 0.8), value: auth.isSignedIn)
        .animation(.smooth(duration: 0.8), value: auth.isLoading)
        .environment(store)
        .environment(health)
        .environment(auth)
        .environment(sync)
        .task {
            // Quietly refresh from Apple Health for members who already
            // connected — never prompts, never blocks the first paint.
            await health.syncIfNeeded(into: store)
        }
        .task(id: auth.user?.id) {
            // A journal belongs to an account, never merely to this device.
            store.activateAccount(auth.user?.id)
        }
        .task {
            // Re-link billing to the account on every launch, so a purchase
            // made while signed out still lands on her when she signs in.
            RevenueCatMembershipService.linkAccount(to: auth.user?.id)
        }
        .task { await verifyMembership() }
        // Backup follows the account: it starts when she signs in and stops
        // when she signs out, without her having to find a switch for it.
        .onChange(of: auth.user?.id) { _, newID in
            store.activateAccount(newID)
            RevenueCatMembershipService.linkAccount(to: newID)
            // Re-check membership for the account that just signed in:
            // activating it restores that account's saved tier, and a Vida+
            // bought on vidalab.co can only be seen once someone is signed in.
            Task { await verifyMembership() }
            Task { await backUpIfSignedIn(force: true) }
            // A device token can arrive before anyone is signed in, and it has
            // to be attached to an account to be any use. Whichever of the two
            // lands second performs the upload.
            Task { await PushNotificationService.shared.accountDidChange(isSignedIn: newID != nil) }
        }
        .onChange(of: scenePhase) { _, phase in
            // Coming back from her ring's app, or from anywhere else, should find
            // Vida already up to date. Throttled inside, so this is cheap.
            guard phase == .active else { return }
            // A membership bought on another surface lands here, and an
            // expired period downgrades here — both without a reinstall.
            store.refreshEntitlementIfNeeded()
            Task { await health.syncIfNeeded(into: store) }
            Task { await verifyMembership() }
            Task { await backUpIfSignedIn() }
            // APNs can rotate a token whenever it likes, so a device that has
            // already agreed re-registers on every foreground.
            Task { await PushNotificationService.shared.registerIfAlreadyAuthorized() }
        }
        .tint(Vida.moss)
        // Every Vida colour is adaptive, so the whole palette follows whichever
        // mode she picked. Night exists because this app gets opened at 3am.
        .preferredColorScheme(store.appearance.colorScheme)
        // SwiftUI's preference stops at SwiftUI. The window override carries it
        // into UIKit screens too (Mail composer, photo picker, share sheets),
        // which otherwise stayed on the device setting.
        .onAppear { store.appearance.applyToWindows() }
        .onChange(of: store.appearance) { _, mode in mode.applyToWindows() }
        .onChange(of: scenePhase) { _, phase in
            // New scenes (and returning from the background) get fresh windows.
            if phase == .active { store.appearance.applyToWindows() }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if auth.isLoading {
            authLoadingView
                .transition(.opacity)
        } else if !auth.isSignedIn {
            NavigationStack {
                SignInView()
            }
            .transition(.opacity)
        } else if store.hasOnboarded {
            mainShell
                .transition(.opacity)
        } else {
            OnboardingView {
                // The tour comes first, so the check-in it ends on has
                // context. Skipping it falls back to the check-in prompt.
                //
                // Onboarding finishes from inside its own full-screen
                // Orientation cover, which is still closing at this moment. A
                // second cover presented mid-dismissal is silently dropped, so
                // the tour waits out the 0.6s closing animation.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    showTour = true
                }
            }
            .transition(.opacity)
        }
    }

    /// The curtain lifts toward the viewer as the app settles into place —
    /// one movement read from two sides, rather than a cut.
    private var welcomeTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.06))
    }

    private var revealAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.35) : .smooth(duration: 0.7)
    }

    private var authLoadingView: some View {
        VStack(spacing: 18) {
            Image("Mark")
                .resizable()
                .scaledToFit()
                .frame(width: 74, height: 74)
                .accessibilityHidden(true)
            ProgressView()
                .tint(Vida.moss)
            Text("Opening VIDA LAB…")
                .font(Vida.sans(13))
                .foregroundStyle(Vida.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .vidaBackground()
        .accessibilityElement(children: .combine)
    }

    /// Asks the store what it believes, and reconciles quietly.
    ///
    /// Deliberately silent: a renewal, a refund or a failed card should be
    /// discovered without a spinner on the home screen. If the check fails
    /// the last known tier stands — never a silent downgrade to free.
    private func verifyMembership() async {
        do {
            let snapshot = try await withMembershipTimeout {
                try await MembershipServiceFactory.shared.currentEntitlement()
            }
            store.reconcile(with: snapshot)
        } catch {
            store.refreshEntitlementIfNeeded()
        }
        // After the store, so an App Store membership keeps precedence.
        if auth.user != nil {
            store.reconcileWebMembership(await WebMembershipService.hasPaidMembership())
        }
        #if DEBUG
        // Simulator testing only: launch with `-VidaDebugPlus` to open Vida+
        // screens without a sandbox purchase. Compiled out of Release builds.
        if ProcessInfo.processInfo.arguments.contains("-VidaDebugPlus") {
            store.isPlus = true
        }
        #endif
    }

    /// Encrypted backup for signed-in members. Throttled and silent by design —
    /// a backup attempt should never interrupt someone logging a symptom.
    private func backUpIfSignedIn(force: Bool = false) async {
        guard let user = auth.user else { return }
        await sync.syncIfNeeded(
            store: store,
            userID: user.id,
            email: user.email,
            name: user.name,
            force: force
        )
    }

    private var mainShell: some View {
        ZStack {
            // Tabs dissolve into each other instead of cutting.
            Group {
                switch tab {
                case .home: HomeView(selectedTab: $tab)
                case .patterns: PatternMapView()
                case .ask: AskVidaView()
                case .community: CommunityView()
                case .lab: LabShell()
                case .library: LibraryShell()
                }
            }
            .id(tab)
            .transition(.vidaDissolve)
        }
        // Lets the Vida menu (and any screen) switch tabs.
        .environment(\.vidaSelectTab, { [tab = $tab] newTab in
            withAnimation(Vida.Motion.page) { tab.wrappedValue = newTab }
        })
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The tab bar floats over the content instead of sitting below it, so
        // every screen scrolls all the way to the bottom edge and passes
        // softly underneath the glass. The inset keeps the last card clear.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !keyboardVisible {
                VidaTabBar(selection: $tab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .readsKeyboardVisibility($keyboardVisible)
        .background(VidaCanvas().ignoresSafeArea())
    }
}

/// Lab tab pairs Experiments with Doctor Prep — both "tools" rather than content.
struct LabShell: View {
    @State private var section: Section = .experiments

    enum Section: String, CaseIterable, Identifiable {
        case experiments, prep, treatments
        var id: String { rawValue }
        var title: String {
            switch self {
            case .experiments: "Experiments"
            case .prep: "Doctor Prep"
            case .treatments: "Treatments"
            }
        }
    }

    @Namespace private var segment

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(Section.allCases) { item in
                    Button {
                        withAnimation(Vida.Motion.page) { section = item }
                    } label: {
                        Text(item.title)
                            .font(Vida.sans(14, weight: section == item ? .semibold : .regular))
                            .foregroundStyle(section == item ? Vida.onForest : Vida.inkSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background {
                                // One indicator that slides between the two
                                // options, rather than two that blink.
                                if section == item {
                                    Capsule()
                                        .fill(Vida.forest)
                                        .matchedGeometryEffect(id: "segment", in: segment)
                                }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay { Capsule().strokeBorder(Vida.hairline.opacity(0.7), lineWidth: 0.7) }
            .sensoryFeedback(.selection, trigger: section)
            .padding(.horizontal, Vida.Space.gutter)
            .padding(.top, 10)
            .padding(.bottom, 4)

            ZStack {
                switch section {
                case .experiments: ExperimentsView().transition(.vidaDissolve)
                case .prep: DoctorPrepView().transition(.vidaDissolve)
                case .treatments: TreatmentLogView().transition(.vidaDissolve)
                }
            }
        }
        .background(VidaCanvas().ignoresSafeArea())
    }
}

/// Floating glass tab bar.
///
/// A capsule of frosted material that hovers above the content, the way Oura
/// and Hatch hold their navigation: the app's pages run edge to edge and the
/// controls sit on top of them like a lens rather than a shelf. The selected
/// tab gets a forest pill that slides between items, and every change lands
/// with a light selection haptic.
struct VidaTabBar: View {
    @Binding var selection: RootTab
    @Namespace private var namespace
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 2) {
            ForEach(RootTab.allCases) { item in
                let isSelected = selection == item
                Button {
                    guard selection != item else { return }
                    withAnimation(.spring(duration: 0.6, bounce: 0.08)) {
                        selection = item
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 16, weight: isSelected ? .regular : .light))
                            .frame(height: 20)
                        Text(item.title)
                            .font(Vida.sans(10, weight: isSelected ? .semibold : .medium))
                            .tracking(0.2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(isSelected ? Vida.onForest : Vida.inkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(Vida.forest)
                                .matchedGeometryEffect(id: "tab", in: namespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(5)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    // A whisper of the paper tone keeps the glass warm rather
                    // than the cool grey of stock material.
                    Capsule().fill(Vida.paper.opacity(colorScheme == .dark ? 0.35 : 0.55))
                }
                .shadow(color: Vida.forest.opacity(colorScheme == .dark ? 0.35 : 0.10), radius: 24, x: 0, y: 12)
                .shadow(color: Vida.forest.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 3, x: 0, y: 1)
        }
        .overlay {
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(colorScheme == .dark ? 0.14 : 0.8), Vida.hairline.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.7
                )
        }
        .sensoryFeedback(.selection, trigger: selection)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .readableColumn(maxWidth: 520)
    }
}

#Preview {
    ContentView()
}
