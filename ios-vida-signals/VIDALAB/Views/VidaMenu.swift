import SwiftUI

// MARK: - Tab routing

nonisolated private struct VidaSelectTabKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable (RootTab) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Switches the main tab. Set once by the root shell so any screen (and
    /// the Vida menu) can send her to Patterns, Ask, Lab or the Library.
    var vidaSelectTab: @MainActor @Sendable (RootTab) -> Void {
        get { self[VidaSelectTabKey.self] }
        set { self[VidaSelectTabKey.self] = newValue }
    }
}

// MARK: - Features

/// Everything Vida can do, in one place. The five tabs stay as they are; the
/// menu is where the deeper tools live, grouped so the list never feels like
/// a wall of buttons.
enum VidaFeature: String, CaseIterable, Identifiable {
    case diary, checkIn, weeklyReport, share
    case patterns, ask
    case library
    case doctorPrep, experiments
    case settings, website

    var id: String { rawValue }

    var title: String {
        switch self {
        case .diary: "Diary"
        case .checkIn: "Check in now"
        case .weeklyReport: "Your week"
        case .share: "Share today"
        case .patterns: "Pattern Map"
        case .ask: "Ask Vida"
        case .library: "The Library"
        case .doctorPrep: "Appointment Concierge"
        case .experiments: "Vida Experiments"
        case .settings: "Settings"
        case .website: "vidalab.co"
        }
    }

    var detail: String {
        switch self {
        case .diary: "Write about your life; check-ins appear beside your words"
        case .checkIn: "Two minutes, morning or evening"
        case .weeklyReport: "A readable summary you can send or print"
        case .share: "Make a card of today for your story"
        case .patterns: "What moves together in your body"
        case .ask: "Plain answers about symptoms and research"
        case .library: "Cited articles, translated"
        case .doctorPrep: "Health Snapshot, what to say, and how to be heard"
        case .experiments: "Test one change properly"
        case .settings: "Appearance, reminders, data and membership"
        case .website: "Condition Library and more on the web"
        }
    }

    var symbol: String {
        switch self {
        case .diary: "book.closed"
        case .checkIn: "leaf"
        case .weeklyReport: "calendar"
        case .share: "square.and.arrow.up"
        case .patterns: "point.3.connected.trianglepath.dotted"
        case .ask: "bubble.left.and.text.bubble.right"
        case .library: "books.vertical"
        case .doctorPrep: "stethoscope"
        case .experiments: "flask"
        case .settings: "gearshape"
        case .website: "globe"
        }
    }
}

struct VidaFeatureGroup: Identifiable {
    let title: String
    let features: [VidaFeature]
    var id: String { title }

    static let all: [VidaFeatureGroup] = [
        VidaFeatureGroup(title: "Track and reflect", features: [.checkIn, .diary, .weeklyReport, .share]),
        VidaFeatureGroup(title: "Understand", features: [.patterns, .ask]),
        VidaFeatureGroup(title: "Learn", features: [.library]),
        VidaFeatureGroup(title: "Care", features: [.doctorPrep, .experiments]),
        VidaFeatureGroup(title: "You", features: [.settings, .website])
    ]
}

// MARK: - Button

/// The orbit mark in the top-left corner of every tab. Tapping it opens the
/// full list of what Vida can do.
struct VidaMenuButton: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented = true
        } label: {
            OrbitMark()
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6)
                }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Everything in Vida")
        .accessibilityHint("Opens the list of all features")
    }
}

struct VidaMenuModifier: ViewModifier {
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VidaMenuButton(isPresented: $isPresented)
                }
            }
            .sheet(isPresented: $isPresented) {
                VidaMenuSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(32)
            }
    }
}

extension View {
    /// Adds the Vida menu button to the top-left of a tab screen. Apply
    /// inside the screen's `NavigationStack`.
    func vidaMenu() -> some View {
        modifier(VidaMenuModifier())
    }
}

// MARK: - Sheet

struct VidaMenuSheet: View {
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.vidaSelectTab) private var selectTab
    @Environment(\.openURL) private var openURL

    @State private var expanded: Set<String> = Set(VidaFeatureGroup.all.prefix(2).map(\.title))
    @State private var path: [VidaFeature] = []
    @State private var checkInPeriod: CheckInPeriod?
    @State private var showReport = false
    @State private var showShare = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        OrbitMark()
                            .frame(width: 38, height: 38)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Everything in Vida")
                                .font(Vida.display(24))
                                .tracking(Vida.displayTracking)
                                .foregroundStyle(Vida.forest)
                            Text("Your tabs stay as they are. The rest lives here.")
                                .font(Vida.sans(13))
                                .foregroundStyle(Vida.inkSoft)
                        }
                    }
                    .padding(.bottom, 12)

                    ForEach(VidaFeatureGroup.all) { group in
                        groupSection(group)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background { VidaCanvas().ignoresSafeArea() }
            .navigationDestination(for: VidaFeature.self) { feature in
                switch feature {
                case .diary: DiaryView()
                case .settings: SettingsView()
                default: EmptyView()
                }
            }
        }
        .sheet(item: $checkInPeriod) { CheckInFlow(period: $0) }
        .sheet(isPresented: $showReport) { WeeklyReportView() }
        .sheet(isPresented: $showShare) { ShareSnapshotView() }
    }

    private func groupSection(_ group: VidaFeatureGroup) -> some View {
        let isOpen = expanded.contains(group.title)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Vida.Motion.gentle) {
                    if isOpen { expanded.remove(group.title) } else { expanded.insert(group.title) }
                }
            } label: {
                HStack {
                    Text(group.title.uppercased())
                        .font(Vida.sans(11, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(Vida.taupe)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Vida.taupe)
                        .rotationEffect(.degrees(isOpen ? 0 : -90))
                }
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(isOpen ? "Expanded" : "Collapsed")

            if isOpen {
                VStack(spacing: 8) {
                    ForEach(group.features) { feature in
                        Button { open(feature) } label: { row(feature) }
                            .buttonStyle(PressableStyle())
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            HairlineDivider()
        }
    }

    private func row(_ feature: VidaFeature) -> some View {
        HStack(spacing: 14) {
            Image(systemName: feature.symbol)
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(Vida.moss)
                .frame(width: 40, height: 40)
                .background(Vida.shell.opacity(0.8), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(Vida.sans(16, weight: .medium))
                    .foregroundStyle(Vida.forest)
                Text(feature.detail)
                    .font(Vida.sans(12.5))
                    .foregroundStyle(Vida.inkSoft)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: feature == .website ? "arrow.up.right" : "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Vida.taupe)
        }
        .padding(12)
        .background(Vida.paper.opacity(0.9), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func open(_ feature: VidaFeature) {
        switch feature {
        case .diary, .settings:
            path.append(feature)
        case .checkIn:
            checkInPeriod = store.currentPeriod
        case .weeklyReport:
            showReport = true
        case .share:
            showShare = true
        case .patterns:
            go(to: .patterns)
        case .ask:
            go(to: .ask)
        case .library:
            go(to: .library)
        case .doctorPrep, .experiments:
            go(to: .lab)
        case .website:
            if let url = URL(string: "https://vidalab.co") { openURL(url) }
        }
    }

    private func go(to tab: RootTab) {
        dismiss()
        selectTab(tab)
    }
}
