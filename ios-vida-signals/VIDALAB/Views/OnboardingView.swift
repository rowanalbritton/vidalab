import SwiftUI

struct OnboardingView: View {
    @Environment(VidaStore.self) private var store
    @State private var page: Int = 0
    @State private var nameField: String = ""
    @State private var wantsDemo: Bool = true
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
            Vida.cream.ignoresSafeArea()
            OrganicBackdrop()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                if page < pages.count {
                    introPage(pages[page])
                        .transition(.asymmetric(
                            insertion: .offset(y: 24).combined(with: .opacity),
                            removal: .offset(y: -24).combined(with: .opacity)
                        ))
                        .id(page)
                } else {
                    namePage
                        .transition(.offset(y: 24).combined(with: .opacity))
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
            LeafProgressMark(progress: 1.0)
                .frame(width: 64, height: 84)
                .padding(.bottom, 12)

            Eyebrow(text: "One last thing")

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
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { HairlineDivider() }
                .padding(.top, 6)

            Button {
                withAnimation(.snappy) { wantsDemo.toggle() }
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Vida.forest : Vida.taupe.opacity(0.35))
                        .frame(width: index == page ? 20 : 6, height: 6)
                }
            }
            .animation(.snappy, value: page)

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
        }
    }

    private func advance() {
        if page < pages.count {
            withAnimation(.smooth(duration: 0.45)) { page += 1 }
            if page == pages.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { nameFocused = true }
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
        withAnimation(.smooth(duration: 0.6)) { store.hasOnboarded = true }
        store.save()
    }
}

/// Soft drifting organic shapes used behind hero moments.
struct OrganicBackdrop: View {
    @State private var drift: Bool = false

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
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

/// The Vida leaf mark that fills as progress increases.
struct LeafProgressMark: View {
    let progress: Double

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
            .animation(.smooth(duration: 0.8), value: progress)
        }
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
