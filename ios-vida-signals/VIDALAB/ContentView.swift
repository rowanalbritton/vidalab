import SwiftUI

enum RootTab: String, CaseIterable, Identifiable {
    case home, patterns, ask, lab, library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Today"
        case .patterns: "Patterns"
        case .ask: "Ask"
        case .lab: "Lab"
        case .library: "Library"
        }
    }

    var symbol: String {
        switch self {
        case .home: "leaf"
        case .patterns: "point.3.connected.trianglepath.dotted"
        case .ask: "bubble.left.and.text.bubble.right"
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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
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
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .environment(store)
        .environment(health)
        .environment(auth)
        .environment(sync)
        .task {
            // Quietly refresh from Apple Health for members who already
            // connected — never prompts, never blocks the first paint.
            await health.syncIfNeeded(into: store)
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
            RevenueCatMembershipService.linkAccount(to: newID)
            Task { await backUpIfSignedIn(force: true) }
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
        }
        .tint(Vida.moss)
        // Every Vida colour is adaptive, so the whole palette follows whichever
        // mode she picked. Night exists because this app gets opened at 3am.
        .preferredColorScheme(store.appearance.colorScheme)
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
        VStack(spacing: 0) {
            ZStack {
                switch tab {
                case .home: HomeView(selectedTab: $tab)
                case .patterns: PatternMapView()
                case .ask: AskVidaView()
                case .lab: LabShell()
                case .library: LibraryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VidaTabBar(selection: $tab)
        }
        .background(Vida.cream.ignoresSafeArea())
    }
}

/// Lab tab pairs Experiments with Doctor Prep — both "tools" rather than content.
struct LabShell: View {
    @State private var section: Section = .experiments

    enum Section: String, CaseIterable, Identifiable {
        case experiments, prep
        var id: String { rawValue }
        var title: String {
            switch self {
            case .experiments: "Experiments"
            case .prep: "Doctor Prep"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(Section.allCases) { item in
                    Button {
                        withAnimation(.snappy) { section = item }
                    } label: {
                        Text(item.title)
                            .font(Vida.sans(14, weight: section == item ? .semibold : .regular))
                            .foregroundStyle(section == item ? Vida.onForest : Vida.inkSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background {
                                Capsule().fill(section == item ? Vida.forest : .clear)
                            }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(5)
            .background(Vida.paper, in: Capsule())
            .overlay { Capsule().strokeBorder(Vida.hairline, lineWidth: 0.9) }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 4)

            ZStack {
                switch section {
                case .experiments: ExperimentsView()
                case .prep: DoctorPrepView()
                }
            }
        }
        .background(Vida.cream.ignoresSafeArea())
    }
}

/// Custom tab bar — quieter and more editorial than the system default.
struct VidaTabBar: View {
    @Binding var selection: RootTab
    @Namespace private var namespace

    var body: some View {
        VStack(spacing: 0) {
            HairlineDivider()
            HStack(spacing: 0) {
                ForEach(RootTab.allCases) { item in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selection = item
                        }
                    } label: {
                        VStack(spacing: 5) {
                            ZStack {
                                if selection == item {
                                    Capsule()
                                        .fill(Vida.sage.opacity(0.28))
                                        .frame(width: 46, height: 30)
                                        .matchedGeometryEffect(id: "tab", in: namespace)
                                }
                                Image(systemName: item.symbol)
                                    .font(.system(size: 16, weight: selection == item ? .medium : .light))
                                    .foregroundStyle(selection == item ? Vida.forest : Vida.taupe)
                            }
                            .frame(height: 30)

                            Text(item.title)
                                .font(Vida.sans(10, weight: selection == item ? .semibold : .regular))
                                .foregroundStyle(selection == item ? Vida.forest : Vida.taupe)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 9)
            .padding(.bottom, 2)
        }
        .background(Vida.cream)
    }
}

#Preview {
    ContentView()
}
