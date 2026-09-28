import SwiftUI

struct OnboardingView: View {
    /// Called exactly once after the first-run flow has been completed.
    var onCompleted: (() -> Void)?

    @Environment(VidaStore.self) private var store
    @State private var page: Int = 0
    @State private var nameField: String = ""
    /// Sample data is useful for an intentional product tour, but a new
    /// member's journal must always begin with their own history.
    @State private var wantsDemo: Bool = false
    @State private var showOrientation: Bool = false
    @FocusState private var nameFocused: Bool

    private let pages: [(eyebrow: String, title: String, body: String)] = [
        ("Vida Lab", "Health science,\ntranslated.",
         "Most health apps collect data. Vida helps you understand it — with real research behind every explanation."),
        ("The question", "What is your body\ntrying to tell you?",
         "Log how you feel morning and evening. Over time Vida finds the relationships between sleep, pain, energy, mood and everything else."),
        ("The principle", "You are the expert\non what you feel.",
         "Vida will never tell you what you have. It shows you patterns worth noticing, explains the science, and helps you ask better questions.")
    ]

    var body: some View {
        ZStack {
            VidaCanvas().ignoresSafeArea()
            OrganicBackdrop()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                if page < pages.count {
                    introPage(pages[page])
                        .transition(.vidaSoftRise)
                        .id(page)
                } else {
                    namePage
                        .transition(.vidaSoftRise)
                        .animation(.smooth(duration: 0.3), value: nameFocused)
                }

                Spacer(minLength: 0)

                controls
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .fullScreenCover(isPresented: $showOrientation) {
            OrientationView(isOnboarding: true) { enterApp() }
        }
        // A name given at sign-up is already hers; no need to ask twice.
        .onAppear { if nameField.isEmpty { nameField = store.name } }
    }

    private func introPage(_ content: (eyebrow: String, title: String, body: String)) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            LeafProgressMark(progress: Double(page + 1) / 4.0)
                .frame(width: 64, height: 84)
                .padding(.bottom, 12)

            Eyebrow(text: content.eyebrow)

            Text(content.title)
                .font(Vida.serif(40, weight: .regular))
                .foregroundStyle(Vida.forest)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(content.body)
                .font(Vida.sans(16))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var namePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Makes room for the keyboard rather than pushing into the status bar.
            if !nameFocused {
                LeafProgressMark(progress: 1.0)
                    .frame(width: 64, height: 84)
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }

            Eyebrow(text: "Before we begin")

            Text("What should\nVida call you?")
                .font(Vida.serif(40))
                .foregroundStyle(Vida.forest)
                .fixedSize(horizontal: false, vertical: true)

            Text("Optional — leave it blank if you'd rather not say.")
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)

            TextField("Your first name", text: $nameField)
                .font(Vida.serif(26))
                .foregroundStyle(Vida.forest)
                .tint(Vida.moss)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($nameFocused)
                // The keyboard's own key moves on, so there's no need to find
                // the button under it.
                .submitLabel(.next)
                .onSubmit { advance() }
                // The keyboard opens on its own here and covers the next
                // button, so there has to be a visible way to close it.
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { nameFocused = false }
                            .font(Vida.sans(15, weight: .semibold))
                            .foregroundStyle(Vida.moss)
                    }
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { HairlineDivider() }
                .padding(.top, 6)

            Button {
                withAnimation(Vida.Motion.gentle) { wantsDemo.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: wantsDemo ? "checkmark.square.fill" : "square")
                        .font(.system(size: 19))
                        .foregroundStyle(wantsDemo ? Vida.moss : Vida.taupe)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Explore with sample data")
                            .font(Vida.sans(15, weight: .medium))
                            .foregroundStyle(Vida.ink)
                        Text("Fills nine weeks of example signals so you can see the Pattern Map working right away. You can clear it any time.")
                            .font(Vida.sans(13))
                            .foregroundStyle(Vida.inkSoft)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 14)

            // App Review guideline 1.4.1: health apps must say, up front, that
            // they don't diagnose. Placed on the one screen every new member
            // passes through, before they see a single pattern.
            Label {
                Text("VIDA LAB is educational and doesn't diagnose. Talk with a doctor before making medical decisions.")
                    .font(Vida.sans(12))
                    .foregroundStyle(Vida.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Vida.taupe)
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controls: some View {
        VStack(spacing: 16) {
            // Decorative, so they step aside while the keyboard is up rather
            // than crowd the button.
            if !nameFocused {
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Vida.forest : Vida.taupe.opacity(0.35))
                            .frame(width: index == page ? 20 : 6, height: 6)
                    }
                }
                .animation(Vida.Motion.page, value: page)
                .accessibilityHidden(true)
            }

            Button {
                advance()
            } label: {
                Text(page < pages.count ? "Continue" : "Next: about you")
                    .font(Vida.sans(17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Vida.forest, in: Capsule())
                    .foregroundStyle(Vida.onForest)
            }
            .buttonStyle(PressableStyle())

            if page < pages.count {
                Button("Skip intro") {
                    withAnimation(.smooth(duration: 0.45)) { page = pages.count }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { nameFocused = true }
                }
                .font(Vida.sans(14, weight: .medium))
                .foregroundStyle(Vida.taupe)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
        }
    }

    private func advance() {
        if page < pages.count {
            withAnimation(Vida.Motion.page) { page += 1 }
            if page == pages.count {
                // Let the page finish settling before the keyboard rises, so
                // the two movements don't collide.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { nameFocused = true }
            }
        } else {
            // Name and sample data are settled here; the orientation guide
            // collects her health picture before the app opens.
            nameFocused = false
            store.name = nameField.trimmingCharacters(in: .whitespaces)
            if wantsDemo { store.seedDemoData() }
            store.save()
            showOrientation = true
        }
    }

    private func enterApp() {
        showOrientation = false
        withAnimation(.smooth(duration: 1.0)) { store.hasOnboarded = true }
        store.save()
        onCompleted?()
    }
}

/// Soft drifting organic shapes used behind hero moments.
struct OrganicBackdrop: View {
    @State private var drift: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(Vida.sky.opacity(0.22))
                .frame(width: 320)
                .blur(radius: 60)
                .offset(x: drift ? 120 : 90, y: drift ? -260 : -300)
            Circle()
                .fill(Vida.blush.opacity(0.20))
                .frame(width: 280)
                .blur(radius: 60)
                .offset(x: drift ? -130 : -100, y: drift ? 300 : 340)
            Circle()
                .fill(Vida.sage.opacity(0.18))
                .frame(width: 240)
                .blur(radius: 55)
                .offset(x: drift ? 100 : 140, y: drift ? 220 : 180)
        }
        .ignoresSafeArea()
        .onAppear {
            // A permanently drifting background is not a neutral flourish for
            // this audience: migraine, POTS and long COVID all count motion
            // sensitivity as a symptom. With Reduce Motion on, the shapes
            // stay exactly where they are — the atmosphere survives, the
            // movement doesn't.
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

/// The Vida leaf mark that fills as progress increases.
struct LeafProgressMark: View {
    let progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack {
                LeafMark()
                    .stroke(Vida.forest.opacity(0.55), lineWidth: 1.2)

                LeafMark()
                    .fill(
                        LinearGradient(
                            colors: [Vida.moss, Vida.sage],
                            startPoint: .bottom, endPoint: .top
                        )
                    )
                    .mask(alignment: .bottom) {
                        Rectangle()
                            .frame(height: h * min(1, max(0, progress)))
                    }

                Path { p in
                    p.move(to: CGPoint(x: geo.size.width / 2, y: h))
                    p.addLine(to: CGPoint(x: geo.size.width / 2, y: h * 0.12))
                }
                .stroke(Vida.forest.opacity(0.35), lineWidth: 0.9)
            }
            .animation(reduceMotion ? nil : .smooth(duration: 0.8), value: progress)
        }
    }
}

/// Press feedback used on every button in the app: a small scale, an
/// opacity dip and a soft haptic tick.
///
/// The scale change is the tactile part, so it's the part Reduce Motion drops;
/// the opacity dip stays, because a button that gives no feedback at all reads
/// as broken.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // A shallow, slow press: the button sinks a little and eases
            // back rather than snapping, so a tap feels cushioned.
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.975 : 1))
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(
                reduceMotion ? .easeOut(duration: 0.15) : Vida.Motion.press,
                value: configuration.isPressed
            )
            // A soft tick on touch-down, the way a well-made physical switch
            // answers before it moves. Only on press, never on release, so
            // a tap is one sensation rather than two.
            .sensoryFeedback(trigger: configuration.isPressed) { _, isPressed in
                isPressed ? .impact(flexibility: .soft, intensity: 0.35) : nil
            }
    }
}
