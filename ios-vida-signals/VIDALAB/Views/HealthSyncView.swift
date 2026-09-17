import SwiftUI

/// Connect screen for Apple Health. Every major wearable writes into Health,
/// so this one connection covers Oura, Apple Watch, Garmin, Whoop and Fitbit.
struct HealthSyncView: View {
    @Environment(VidaStore.self) private var store
    @Environment(HealthImportService.self) private var health
    @Environment(\.dismiss) private var dismiss

    @State private var isWorking: Bool = false
    @State private var confirmDisconnect: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if health.isAvailable {
                        statusCard
                        signalList
                        rulesCard
                    } else {
                        unavailableCard
                    }
                    deviceNote
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("APPLE HEALTH")
                        .font(Vida.sans(12, weight: .bold))
                        .tracking(2.4)
                        .foregroundStyle(Vida.forest)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Vida.sans(15, weight: .medium))
                        .foregroundStyle(Vida.moss)
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
        .alert("Disconnect Apple Health?", isPresented: $confirmDisconnect) {
            Button("Disconnect", role: .destructive) {
                health.stopObserving()
                store.disconnectHealth()
            }
            Button("Stay connected", role: .cancel) { }
        } message: {
            Text("Vida will remove everything Apple Health contributed. Anything you logged yourself stays exactly where it is.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Let your ring\ndo the typing.")
                .font(Vida.serif(30))
                .foregroundStyle(Vida.forest)
            Text("Your Oura ring, Apple Watch, Garmin, Whoop or Fitbit already writes into Apple Health. Connect once and Vida keeps itself current from then on — sleep, movement and cycle data arrive on their own, so your patterns are built from measurement rather than memory.")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: store.healthSyncEnabled ? "heart.text.square.fill" : "heart.text.square")
                    .font(.system(size: 17))
                    .foregroundStyle(store.healthSyncEnabled ? Vida.moss : Vida.taupe)
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.healthSyncEnabled ? "Connected" : "Not connected yet")
                        .font(Vida.sans(16, weight: .semibold))
                        .foregroundStyle(Vida.forest)
                    Text(statusDetail)
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if case .failed(let message) = health.phase {
                Text(message)
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Vida.blush.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                Task { await connect() }
            } label: {
                HStack(spacing: 8) {
                    if isWorking {
                        ProgressView().tint(Vida.cream)
                    }
                    Text(buttonTitle)
                        .font(Vida.sans(16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Vida.forest, in: Capsule())
                .foregroundStyle(Vida.cream)
            }
            .buttonStyle(PressableStyle())
            .disabled(isWorking)

            if store.healthSyncEnabled {
                Button {
                    confirmDisconnect = true
                } label: {
                    Text("Disconnect")
                        .font(Vida.sans(14, weight: .medium))
                        .foregroundStyle(Vida.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }

    private var statusDetail: String {
        if isWorking { return "Reading the last 30 days…" }
        switch health.phase {
        case .finished(let imported, let days) where imported > 0:
            return "Brought in \(imported) reading\(imported == 1 ? "" : "s") across \(days) day\(days == 1 ? "" : "s")."
        case .finished:
            return "Nothing new to bring in. Apple Health had no data Vida could read for this period."
        default:
            break
        }
        if store.healthSyncEnabled {
            let count = store.healthReadingCount
            if let last = store.lastHealthSync {
                return "\(count) reading\(count == 1 ? "" : "s") from Health · last checked \(last.formatted(date: .abbreviated, time: .shortened))."
            }
            return "\(count) reading\(count == 1 ? "" : "s") from Apple Health."
        }
        return "One tap: Vida asks for read-only access, brings in the last 90 days, then keeps itself up to date."
    }

    private var buttonTitle: String {
        if isWorking { return "Syncing" }
        return store.healthSyncEnabled ? "Sync now" : "Connect Apple Health"
    }

    private func connect() async {
        isWorking = true
        if store.healthSyncEnabled {
            await health.importRecent(days: 30, into: store)
        } else {
            // One tap covers permission, the first import, and starting the
            // live watch — she should never have to come back and press again.
            await health.connect(into: store)
        }
        isWorking = false
    }

    private var signalList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "What Vida reads")
            VStack(spacing: 0) {
                ForEach(Array(HealthImportService.mappings.enumerated()), id: \.element.id) { index, mapping in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: mapping.category.symbol)
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(mapping.category.accent)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(mapping.sourceLabel)
                                .font(Vida.sans(15, weight: .medium))
                                .foregroundStyle(Vida.forest)
                            Text(mapping.explanation)
                                .font(Vida.sans(12))
                                .foregroundStyle(Vida.inkSoft)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 13)

                    if index < HealthImportService.mappings.count - 1 {
                        HairlineDivider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Two promises", color: Vida.skyDeep)
            rule("Read-only. Vida never writes anything back into Apple Health.")
            rule("What you type always wins. If you logged a signal yourself, an import will never overwrite it — your own account of your body is the ground truth.")
            rule("Nothing leaves your phone. Health data is read on the device and stays there.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Vida.sky.opacity(0.12), in: RoundedRectangle(cornerRadius: Vida.cardRadius, style: .continuous))
    }

    private func rule(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(Vida.skyDeep).frame(width: 4, height: 4).padding(.top, 7)
            Text(text)
                .font(Vida.sans(14))
                .foregroundStyle(Vida.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var unavailableCard: some View {
        QuietEmptyState(
            symbol: "heart.slash",
            title: "Apple Health isn't available",
            message: "This device doesn't provide Health data, so there's nothing for Vida to read. Everything else in the app works exactly as normal."
        )
        .paperCard(padding: 8)
    }

    private var deviceNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "About your devices")
            Text("Oura, Whoop, Garmin and Fitbit each have a setting that writes their data into Apple Health — turn it on in that app once, and it appears here too. Apple Watch does it automatically. Vida reads the result rather than talking to each company, which means fewer accounts, no extra logins, and nothing of yours leaving this phone.")
                .font(Vida.sans(13))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Vida.sage.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
