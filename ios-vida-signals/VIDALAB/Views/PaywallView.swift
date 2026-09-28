import SwiftUI

/// Where the paywall is shown. The onboarding version leads with what Vida+
/// adds and ends with a clear way to carry on free; prices, renewal terms,
/// restore, and legal links are the same in both.
enum PaywallContext: Equatable {
    case standard
    case onboarding
}

struct PaywallView: View {
    var context: PaywallContext = .standard
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var appeared: Bool = false
    @State private var isPurchasing: Bool = false
    @State private var isRestoring: Bool = false
    @State private var showRestoreNote: Bool = false
    @State private var showDuplicateNote: Bool = false
    @State private var showPendingNote: Bool = false
    @State private var purchaseError: String?

    /// Prices come from the store, never from a hardcoded string, so they're
    /// correct in every currency and can change without an app update.
    @State private var products: [MembershipProduct] = []
    @State private var selectedProductID: String = MembershipProductID.yearly
    @State private var isLoadingProducts: Bool = true
    @State private var loadFailed: Bool = false

    private let billing: MembershipPurchasing = MembershipServiceFactory.shared

    private var selectedProduct: MembershipProduct? {
        products.first { $0.id == selectedProductID } ?? products.first
    }

    private let benefits: [(String, String, String)] = [
        ("point.3.connected.trianglepath.dotted", "Every connection, not just three", "Free shows your three strongest patterns. Vida+ opens the whole map, including the quieter threads."),
        ("bubble.left.and.text.bubble.right", "Unlimited Ask Vida", "Free gives you five questions a day. Vida+ never counts."),
        ("flask", "Unlimited experiments", "Free runs two labs at a time. Vida+ lets you run as many as you like, at once."),
        ("text.document", "Unlimited Doctor Prep", "Free includes one full Health Snapshot. Vida+ lets you build one for every appointment."),
        ("wind", "Every meditation session", "Box and 4-7-8 breathing and the full guided library: sleep, body scans, grounding, and more. The quiet timer and a few sessions stay free."),
        ("cloud.sun", "Three AI tools built on your tracking", "Body Weather looks ahead at your week, the Vida Differential maps patterns worth raising with a doctor, and the Appointment Concierge prepares you for visits."),
        ("books.vertical", "The deeper library", "The remaining pieces on pain science, the gut-brain axis, training across your cycle, and blood sugar."),
        ("clock.arrow.circlepath", "Your whole history", "Patterns across months and years instead of a rolling thirty days.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if context == .onboarding {
                        welcomeHero
                        featureTiles
                    } else {
                        hero
                    }
                    // Someone who already pays should never be sold the same
                    // thing twice — she gets her status and where to manage it.
                    if store.alreadySubscribed {
                        alreadyMemberCard
                    }
                    if context == .standard {
                        benefitList
                        freeComparison
                    }
                    if !store.alreadySubscribed {
                        planSection
                    }
                    if context == .onboarding {
                        continueFree
                    }
                    footnote
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 36)
                .readableColumn()
            }
            .scrollIndicators(.hidden)
            .background {
                ZStack {
                    Vida.cream
                    OrganicBackdrop().opacity(0.7)
                }
                .ignoresSafeArea()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // In onboarding the free path is named at the top as well
                    // as below the plans, so it never needs a scroll to find.
                    Button(context == .onboarding ? "Continue free" : "Not now") { dismiss() }
                        .font(Vida.sans(15, weight: context == .onboarding ? .semibold : .regular))
                        .foregroundStyle(context == .onboarding ? Vida.moss : Vida.inkSoft)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear { withAnimation(.smooth(duration: 0.6)) { appeared = true } }
        .task { await loadProducts() }
        .alert("Waiting for approval", isPresented: $showPendingNote) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("This purchase needs someone else to approve it — usually a parent or account holder. Vida+ unlocks by itself the moment it goes through.")
        }
        .alert("You're already a member", isPresented: $showDuplicateNote) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text(store.duplicateSubscriptionMessage)
        }
        .alert(
            "Purchase didn't go through",
            isPresented: Binding(
                get: { purchaseError != nil },
                set: { if !$0 { purchaseError = nil } }
            )
        ) {
            Button("Try again") { Task { await purchase() } }
            Button("Not now", role: .cancel) { purchaseError = nil }
        } message: {
            Text(purchaseError ?? "")
        }
    }

    // MARK: Onboarding

    private var welcomeHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill").font(.system(size: 13))
                Text("VIDA+").font(Vida.sans(12, weight: .bold)).tracking(2.4)
            }
            .foregroundStyle(Vida.moss)

            Text(store.name.isEmpty ? "You're all set.\nWant the full picture?" : "You're all set, \(store.name).\nWant the full picture?")
                .font(Vida.serif(32))
                .foregroundStyle(Vida.forest)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)

            Text("Vida Free has everything you need to start tracking. Vida+ turns your check-ins into forecasts, visit prep, and calm, and opens every pattern Vida finds.")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private let tiles: [(symbol: String, title: String, detail: String)] = [
        ("cloud.sun", "Body Weather", "A 7-day look ahead at your energy, mood, and harder days, with what to try before they hit."),
        ("stethoscope", "Appointment Concierge", "Visit prep in your own words, doctors near you, and appointment requests in one place."),
        ("wind", "Meditate", "The full guided library and every breathing pattern, with a before-and-after stress check."),
        ("point.3.connected.trianglepath.dotted", "Every pattern, every question", "The whole pattern map, unlimited Ask Vida, the Vida Differential, and your full history."),
    ]

    private var featureTiles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: tile.symbol)
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(Vida.moss)
                        .frame(width: 40, height: 40)
                        .background(Vida.sage.opacity(0.2), in: Circle())
                        .accessibilityHidden(true)
                    Text(tile.title)
                        .font(Vida.sans(15, weight: .semibold))
                        .foregroundStyle(Vida.forest)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(tile.detail)
                        .font(Vida.sans(12))
                        .foregroundStyle(Vida.inkSoft)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
                .paperCard(padding: 14)
                .accessibilityElement(children: .combine)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.smooth(duration: 0.5).delay(Double(index) * 0.06), value: appeared)
            }
        }
    }

    /// The free path, stated plainly and as easy to reach as the purchase.
    private var continueFree: some View {
        VStack(spacing: 6) {
            Button { dismiss() } label: {
                Text("Continue with Vida Free")
                    .font(Vida.sans(16, weight: .semibold))
                    .foregroundStyle(Vida.forest)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Vida.sage.opacity(0.2), in: Capsule())
            }
            .buttonStyle(PressableStyle())
            Text("You can start Vida+ any time from Settings.")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.inkSoft)
        }
    }

    /// Shown instead of a plan picker when she already has access.
    private var alreadyMemberCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Vida.moss)
                Text("You already have Vida+")
                    .font(Vida.sans(16, weight: .semibold))
                    .foregroundStyle(Vida.forest)
            }

            Text(store.duplicateSubscriptionMessage)
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                dismiss()
            } label: {
                Text("Back to Vida")
                    .font(Vida.sans(15, weight: .semibold))
                    .foregroundStyle(Vida.onForest)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(minHeight: 44)
                    .background(Vida.forest, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 13))
                Text("VIDA+")
                    .font(Vida.sans(12, weight: .bold))
                    .tracking(2.4)
            }
            .foregroundStyle(Vida.moss)

            Text("Understand the\nwhole picture.")
                .font(Vida.serif(34))
                .foregroundStyle(Vida.forest)
                .lineSpacing(1)

            Text("Vida Free is a real app, not a trailer — daily check-ins, three patterns, two experiments, a Health Snapshot and a month of history are yours for nothing. Vida+ simply removes the ceilings.")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var benefitList: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(benefits.enumerated()), id: \.offset) { index, benefit in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: benefit.0)
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(Vida.moss)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(benefit.1)
                            .font(Vida.sans(15, weight: .semibold))
                            .foregroundStyle(Vida.ink)
                        Text(benefit.2)
                            .font(Vida.sans(13))
                            .foregroundStyle(Vida.inkSoft)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.smooth(duration: 0.5).delay(Double(index) * 0.05), value: appeared)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 22)
    }

    private var freeComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "What you already have, free")
            ForEach(freeItems, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Vida.moss)
                        .padding(.top, 3)
                    Text(item)
                        .font(Vida.sans(14))
                        .foregroundStyle(Vida.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Vida.sage.opacity(0.14), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var freeItems: [String] {
        [
            "Unlimited daily check-ins across all twelve signals",
            "Your three strongest patterns, with the science behind them",
            "Five Ask Vida questions every day",
            "Two experiments running at a time",
            "Paced breathing, a quiet timer, and three guided meditations",
            "One complete Doctor Prep and Health Snapshot",
            "Thirty days of history and six full library pieces"
        ]
    }

    /// Plans, priced by the store, with a real state for every outcome:
    /// loading, loaded, and couldn't-load-with-a-way-out.
    @ViewBuilder
    private var planSection: some View {
        if isLoadingProducts {
            planPlaceholder
        } else if loadFailed || products.isEmpty {
            priceUnavailableCard
        } else {
            planPicker
            cta
        }
    }

    /// Skeleton rows rather than a spinner: the layout doesn't jump when the
    /// real prices land.
    private var planPlaceholder: some View {
        VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Vida.shell.opacity(0.5))
                    .frame(height: 78)
            }
        }
        .overlay {
            Text("Loading prices…")
                .font(Vida.sans(13))
                .foregroundStyle(Vida.taupe)
        }
        .accessibilityLabel("Loading prices")
    }

    /// The store can always fail. It must never become a dead end — the free
    /// tier is a genuine product, so saying so is an honest way out.
    private var priceUnavailableCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Prices aren't loading")
                .font(Vida.sans(16, weight: .semibold))
                .foregroundStyle(Vida.forest)
            Text("We couldn't reach the App Store just now, so we won't guess at a price. Vida Free keeps working exactly as it is in the meantime.")
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    Task { await loadProducts() }
                } label: {
                    Text("Try again")
                        .font(Vida.sans(15, weight: .semibold))
                        .foregroundStyle(Vida.onForest)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(minHeight: 44)
                        .background(Vida.forest, in: Capsule())
                }
                .buttonStyle(PressableStyle())

                Button {
                    dismiss()
                } label: {
                    Text("Keep using Free")
                        .font(Vida.sans(15))
                        .foregroundStyle(Vida.inkSoft)
                        .frame(minHeight: 44)
                }
                .buttonStyle(PressableStyle())
            }

            restoreButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }

    private var planPicker: some View {
        VStack(spacing: 10) {
            ForEach(products) { option in
                Button {
                    withAnimation(.snappy) { selectedProductID = option.id }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .strokeBorder(
                                    selectedProductID == option.id ? Vida.forest : Vida.hairline,
                                    lineWidth: selectedProductID == option.id ? 5 : 1.2
                                )
                                .frame(width: 20, height: 20)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(option.copy.title)
                                    .font(Vida.sans(16, weight: .semibold))
                                    .foregroundStyle(Vida.forest)
                                if let badge = option.copy.badge {
                                    Text(badge)
                                        .font(Vida.sans(9, weight: .bold))
                                        .tracking(1)
                                        .foregroundStyle(Vida.cream)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Vida.moss, in: Capsule())
                                }
                            }
                            Text(option.copy.detail)
                                .font(Vida.sans(12))
                                .foregroundStyle(Vida.inkSoft)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(option.priceText)
                                .font(Vida.serif(20))
                                .foregroundStyle(Vida.forest)
                            Text(option.copy.cadence)
                                .font(Vida.sans(11))
                                .foregroundStyle(Vida.taupe)
                        }
                    }
                    .padding(18)
                    .frame(minHeight: 44)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selectedProductID == option.id ? Vida.sage.opacity(0.16) : Vida.paper)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                selectedProductID == option.id ? Vida.moss : Vida.hairline.opacity(0.7),
                                lineWidth: selectedProductID == option.id ? 1.2 : 0.7
                            )
                    }
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(option.copy.title), \(option.priceText) \(option.copy.cadence). \(option.copy.detail)")
                .accessibilityAddTraits(selectedProductID == option.id ? [.isSelected] : [])
            }
        }
    }

    private var cta: some View {
        VStack(spacing: 12) {
            Button {
                Task { await purchase() }
            } label: {
                ZStack {
                    Text(ctaLabel)
                        .font(Vida.sans(17, weight: .semibold))
                        .opacity(isPurchasing ? 0 : 1)
                    if isPurchasing {
                        ProgressView()
                            .tint(Vida.cream)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Vida.forest, in: Capsule())
                .foregroundStyle(Vida.cream)
            }
            .buttonStyle(PressableStyle())
            .disabled(isPurchasing || selectedProduct == nil)
            .accessibilityLabel(isPurchasing ? "Completing your purchase" : ctaLabel)
            .accessibilityHint("Opens Apple's purchase sheet. You confirm the payment there.")

            restoreButton
        }
        // Finding nothing is a normal outcome, not an error. It gets a plain
        // sentence and no alarming language.
        .alert("Nothing to restore", isPresented: $showRestoreNote) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("There's no previous Vida+ purchase on this Apple Account. If you subscribed with a different one, sign in to that account and try again.")
        }
    }

    private var ctaLabel: String {
        guard let product = selectedProduct else { return "Start Vida+" }
        return "Start Vida+ · \(product.priceText) \(product.copy.cadence)"
    }

    /// Apple requires this to be reachable from the paywall, so it lives
    /// outside the CTA stack and appears in the failure state too.
    private var restoreButton: some View {
        Button {
            Task { await restore() }
        } label: {
            HStack(spacing: 6) {
                if isRestoring {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(Vida.taupe)
                }
                Text(isRestoring ? "Checking…" : "Restore purchases")
            }
            .font(Vida.sans(13))
            .foregroundStyle(Vida.taupe)
            .frame(minHeight: 44)
        }
        .buttonStyle(PressableStyle())
        .disabled(isRestoring)
        .accessibilityLabel(isRestoring ? "Checking for previous purchases" : "Restore purchases")
        .accessibilityHint("Checks this Apple Account for a Vida Plus subscription you already bought.")
    }

    private func loadProducts() async {
        isLoadingProducts = true
        loadFailed = false
        do {
            let loaded = try await withMembershipTimeout { [billing] in
                try await billing.availableProducts()
            }
            products = loaded
            // Keep the previous choice if it survived the reload.
            if !loaded.contains(where: { $0.id == selectedProductID }) {
                selectedProductID = loaded.first?.id ?? MembershipProductID.yearly
            }
            loadFailed = loaded.isEmpty
        } catch {
            loadFailed = true
        }
        isLoadingProducts = false
    }

    private func purchase() async {
        purchaseError = nil

        guard !store.alreadySubscribed else {
            showDuplicateNote = true
            return
        }
        guard let product = selectedProduct else { return }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let outcome = try await withMembershipTimeout { [billing] in
                try await billing.purchase(product)
            }
            switch outcome {
            case let .success(transactionID, expiresAt):
                store.applyEntitlement(
                    status: .active,
                    source: .appStore,
                    plan: product.copy.title,
                    expiresAt: expiresAt,
                    transactionID: transactionID,
                    detail: "Started \(product.copy.title) via the App Store."
                )
                dismiss()
            case .cancelled:
                // Backing out is a choice, not a failure. Say nothing.
                break
            case .pending:
                showPendingNote = true
            }
        } catch {
            purchaseError = (error as? MembershipError)?.errorDescription
                ?? MembershipError.unknown.errorDescription
        }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }

        do {
            let outcome = try await withMembershipTimeout { [billing] in
                try await billing.restore()
            }
            switch outcome {
            case let .restored(transactionID, productID, expiresAt):
                let name = MembershipCopy.known(productID)?.title ?? "Vida+"
                store.applyEntitlement(
                    status: .active,
                    source: .appStore,
                    plan: name,
                    expiresAt: expiresAt,
                    transactionID: transactionID,
                    detail: "Restored \(name) from a previous purchase."
                )
                dismiss()
            case .nothingFound:
                if store.alreadySubscribed {
                    showDuplicateNote = true
                } else {
                    showRestoreNote = true
                }
            }
        } catch {
            purchaseError = (error as? MembershipError)?.errorDescription
                ?? MembershipError.unknown.errorDescription
        }
    }

    private var footnote: some View {
        VStack(spacing: 10) {
            HairlineDivider()

            Text("Your health data stays on your device. On a Family plan, whoever pays can see the subscription — never the health logs.")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.taupe)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            // Apple requires the renewal terms on the screen that sells the
            // subscription — not buried in Settings or on the website.
            Text(renewalDisclosure)
                .font(Vida.sans(11))
                .foregroundStyle(Vida.taupe)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            LegalLinksRow()
        }
        .frame(maxWidth: .infinity)
    }

    /// Auto-renewal terms, naming the selected plan's real price and period.
    ///
    /// Falls back to generic wording when prices haven't loaded, so the
    /// disclosure is never absent and never invents a number.
    private var renewalDisclosure: String {
        let opening: String
        if let product = selectedProduct {
            opening = "Vida+ is \(product.priceText) \(product.copy.cadence) and renews automatically."
        } else {
            opening = "Vida+ is an auto-renewing subscription."
        }
        return opening + " Your Apple Account is charged at confirmation, then again within 24 hours of each period ending unless you cancel at least 24 hours beforehand. Manage or cancel any time in Settings › Apple Account › Subscriptions."
    }
}
