import SwiftUI
import Charts

// Body metrics from an Apple Watch, Oura Ring, or other wearable, read
// through Apple Health and shown as 30-day trends against her usual.

/// Where to switch on Apple Health syncing in each wearable's own app.
struct DeviceSetupGuide: View {
    private let devices: [(name: String, symbol: String, steps: String)] = [
        ("Apple Watch", "applewatch", "Nothing to set up. Wear it, and its heart rate, heart rate variability, sleep, temperature, and activity go to Apple Health on their own."),
        ("Oura Ring", "circle.circle", "In the Oura app, open Settings, then Apple Health, and turn it on. Allow sleep, heart rate, heart rate variability, temperature, and mindful minutes."),
        ("Garmin", "watch.analog", "In Garmin Connect, open More, then Settings, Connected Apps, Apple Health, and allow what you'd like shared."),
        ("Whoop", "waveform.path.ecg", "In the Whoop app, open More, then App Settings, Integrations, and connect Apple Health."),
        ("Fitbit", "figure.walk", "Fitbit doesn't write to Apple Health directly. A syncing app from the App Store can bridge it."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Connect your devices")
            Text("Vida reads everything through Apple Health, so a wearable only needs to share with Health once.")
                .font(Vida.sans(13))
                .foregroundStyle(Vida.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(devices, id: \.name) { device in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: device.symbol)
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(Vida.moss)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(device.name).font(Vida.sans(15, weight: .semibold)).foregroundStyle(Vida.forest)
                        Text(device.steps).font(Vida.sans(13)).foregroundStyle(Vida.inkSoft).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Vida.sage.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// A compact Today card with three headline metrics.
struct BodyMetricsCard: View {
    @Environment(VidaStore.self) private var store
    private let metrics = BodyMetricsService.shared
    @State private var isPresented = false

    private var headline: [BodyMetricSeries] {
        [BodyMetricKind.restingHeartRate, .heartRateVariability, .steps]
            .compactMap { kind in metrics.available.first { $0.kind == kind } }
    }

    var body: some View {
        if store.healthSyncEnabled {
            Button { isPresented = true } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Eyebrow(text: "Body metrics", color: Vida.moss)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Vida.taupe)
                            .accessibilityHidden(true)
                    }
                    if headline.isEmpty {
                        Text("See heart rate, HRV, temperature, and activity from your watch or ring.")
                            .font(Vida.sans(14))
                            .foregroundStyle(Vida.inkSoft)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(headline) { series in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(series.latest.map { series.kind.format($0.value) } ?? "–")
                                        .font(Vida.serif(22))
                                        .foregroundStyle(Vida.forest)
                                    Text(series.kind == .heartRateVariability ? "HRV, ms" : series.kind == .restingHeartRate ? "Resting bpm" : "Steps")
                                        .font(Vida.sans(11))
                                        .foregroundStyle(Vida.inkSoft)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .paperCard(padding: 18)
            }
            .buttonStyle(PressableStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens your body metrics")
            .task { await metrics.load() }
            .sheet(isPresented: $isPresented) {
                BodyMetricsView().presentationDetents([.large])
            }
        }
    }
}

struct BodyMetricsView: View {
    @Environment(VidaStore.self) private var store
    @Environment(HealthImportService.self) private var health
    @Environment(\.dismiss) private var dismiss
    private let metrics = BodyMetricsService.shared
    @State private var needsPermission = false
    @State private var showConnect = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Body metrics")
                            .font(Vida.serif(30))
                            .foregroundStyle(Vida.forest)
                        Text("From your Apple Watch, Oura Ring, or other wearable, through Apple Health. This week is compared with your usual over the past month. Read only, and never stored or shared.")
                            .font(Vida.sans(15))
                            .foregroundStyle(Vida.inkSoft)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !health.isAvailable {
                        QuietEmptyState(symbol: "heart.slash", title: "Apple Health isn't available", message: "This device doesn't provide Health data.")
                    } else if !store.healthSyncEnabled {
                        actionCard(
                            text: "Connect Apple Health to see metrics from your watch or ring.",
                            button: "Connect Apple Health"
                        ) { showConnect = true }
                    } else {
                        if needsPermission {
                            actionCard(
                                text: "Allow heart rate, HRV, temperature, and activity so Vida can show them here.",
                                button: "Allow body metrics"
                            ) {
                                Task {
                                    await health.requestAccess()
                                    needsPermission = await health.needsPermissionPrompt()
                                    await metrics.load(force: true)
                                }
                            }
                        }
                        if metrics.isLoading && metrics.series.isEmpty {
                            ProgressView().tint(Vida.moss).frame(maxWidth: .infinity).padding(.vertical, 30)
                        } else {
                            ForEach(BodyMetricKind.allCases) { kind in
                                BodyMetricCard(kind: kind, series: metrics.series[kind])
                            }
                        }
                    }

                    DeviceSetupGuide()

                    Text("Wearable measurements are estimates and vary with fit and movement. Trends are for your own reflection, not a diagnosis. If something worries you, talk with a clinician.")
                        .font(Vida.sans(12))
                        .foregroundStyle(Vida.taupe)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
                .readableColumn()
            }
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Vida.moss)
                }
            }
            .refreshable { await metrics.load(force: true) }
        }
        .task {
            needsPermission = await health.needsPermissionPrompt()
            await metrics.load(force: true)
        }
        .sheet(isPresented: $showConnect) { HealthSyncView() }
    }

    private func actionCard(text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text).font(Vida.sans(15)).foregroundStyle(Vida.forest).fixedSize(horizontal: false, vertical: true)
            Button(action: action) {
                Text(button)
                    .font(Vida.sans(15, weight: .semibold))
                    .foregroundStyle(Vida.onForest)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Vida.forest, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .paperCard(padding: 18)
    }
}

struct BodyMetricCard: View {
    let kind: BodyMetricKind
    let series: BodyMetricSeries?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(kind.title, systemImage: kind.symbol)
                    .font(Vida.sans(15, weight: .semibold))
                    .foregroundStyle(Vida.forest)
                Spacer()
                if let latest = series?.latest {
                    Text("\(kind.format(latest.value)) \(kind.unit)")
                        .font(Vida.sans(15, weight: .medium))
                        .foregroundStyle(Vida.ink)
                }
            }

            if let series, series.days.count >= 2 {
                Chart(series.days) { day in
                    LineMark(x: .value("Day", day.date, unit: .day), y: .value(kind.title, day.value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Vida.moss)
                    PointMark(x: .value("Day", day.date, unit: .day), y: .value(kind.title, day.value))
                        .symbolSize(14)
                        .foregroundStyle(Vida.moss)
                }
                .chartYScale(domain: .automatic(includesZero: kind.isCumulative))
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { _ in AxisGridLine(); AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
                .frame(height: 110)
                .accessibilityLabel("\(kind.title) over the last 30 days")

                if let comparison = series.comparison() {
                    Text(comparison.summary)
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("A few more days of data and Vida can compare this week with your usual.")
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("No data yet. This usually comes from \(kind.source).")
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.taupe)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 16)
    }
}
