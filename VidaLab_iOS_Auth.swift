//
//  VidaLab_iOS_Auth.swift
//  VIDA LAB — Auth, Onboarding, Dashboard
//
//  Requires VidaLab_iOS_Core.swift in the same target.
//

import SwiftUI

// MARK: - Auth View Model

@MainActor
final class AuthVM: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var error: String?

    var isLoggedIn: Bool { VidaAPIClient.shared.authToken != nil }
    var needsOnboarding: Bool { user?.gender == nil || user?.gender?.isEmpty == true }

    func fetchUser() async {
        guard isLoggedIn else { return }
        do { user = try await VidaAPIClient.shared.getCurrentUser() }
        catch VidaAPIError.unauthorized { logout() }
        catch {}
    }
    func logout() { Task { await VidaAPIClient.shared.logout() }; user = nil }
}

// MARK: - App Root

struct VidaAppRoot: View {
    @StateObject private var auth = AuthVM()
    var body: some View {
        Group {
            if !auth.isLoggedIn { LoginView(auth: auth) }
            else if auth.needsOnboarding { OnboardingView(auth: auth) }
            else { DashboardView(auth: auth) }
        }
        .task { await auth.fetchUser() }
    }
}

// MARK: - Login View

struct LoginView: View {
    @ObservedObject var auth: AuthVM
    @State private var email = "", password = "", isLoading = false, error: String?
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                VStack(spacing: 8) {
                    Text("VIDA LAB").font(.system(size: 36, weight: .bold, design: .serif)).foregroundColor(Color(red: 0.18, green: 0.27, blue: 0.24))
                    Text("Research, translated").font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                VStack(spacing: 16) {
                    TextField("Email", text: $email).textFieldStyle(.roundedBorder).autocapitalization(.none).keyboardType(.emailAddress)
                    SecureField("Password", text: $password).textFieldStyle(.roundedBorder)
                    if let e = error { Text(e).foregroundColor(.red).font(.caption) }
                    Button(action: login) { if isLoading { ProgressView().tint(.white) } else { Text("Sign In").frame(maxWidth: .infinity) } }
                        .buttonStyle(.borderedProminent).tint(Color(red: 0.18, green: 0.27, blue: 0.24))
                        .disabled(isLoading || email.isEmpty || password.isEmpty)
                }
                NavigationLink("Don't have an account? Register", isActive: $showRegister) { RegisterView(auth: auth) }
                Spacer()
            }
            .padding().navigationBarHidden(true)
        }
    }
    private func login() {
        isLoading = true; error = nil
        Task { do { auth.user = try await VidaAPIClient.shared.login(email: email, password: password) } catch { self.error = "Login failed. Check your credentials."; isLoading = false } }
    }
}

// MARK: - Register View (with OTP)

struct RegisterView: View {
    @ObservedObject var auth: AuthVM
    @State private var email = "", password = "", confirmPassword = "", otpCode = "", isLoading = false, error: String?
    @State private var showOTP = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Create Account").font(.system(size: 28, weight: .bold, design: .serif)).foregroundColor(Color(red: 0.18, green: 0.27, blue: 0.24))
                if !showOTP {
                    VStack(spacing: 16) {
                        TextField("Email", text: $email).textFieldStyle(.roundedBorder).autocapitalization(.none).keyboardType(.emailAddress)
                        SecureField("Password", text: $password).textFieldStyle(.roundedBorder)
                        SecureField("Confirm", text: $confirmPassword).textFieldStyle(.roundedBorder)
                        if let e = error { Text(e).foregroundColor(.red).font(.caption) }
                        Button(action: register) { if isLoading { ProgressView().tint(.white) } else { Text("Register").frame(maxWidth: .infinity) } }
                            .buttonStyle(.borderedProminent).tint(Color(red: 0.18, green: 0.27, blue: 0.24))
                            .disabled(isLoading || email.isEmpty || password.isEmpty || password != confirmPassword)
                    }
                } else {
                    VStack(spacing: 16) {
                        Text("Enter the verification code sent to your email").font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                        TextField("6-digit code", text: $otpCode).textFieldStyle(.roundedBorder).keyboardType(.numberPad)
                        if let e = error { Text(e).foregroundColor(.red).font(.caption) }
                        Button(action: verify) { if isLoading { ProgressView().tint(.white) } else { Text("Verify").frame(maxWidth: .infinity) } }
                            .buttonStyle(.borderedProminent).tint(Color(red: 0.18, green: 0.27, blue: 0.24))
                            .disabled(isLoading || otpCode.count != 6)
                        Button("Resend code") { Task { try? await VidaAPIClient.shared.resendOTP(email: email) } }.font(.caption)
                    }
                }
                Spacer()
            }
            .padding().navigationBarTitleDisplayMode(.inline)
        }
    }
    private func register() {
        isLoading = true; error = nil
        Task { do { try await VidaAPIClient.shared.register(email: email, password: password); showOTP = true; isLoading = false } catch { self.error = "Registration failed."; isLoading = false } }
    }
    private func verify() {
        isLoading = true; error = nil
        Task { do { auth.user = try await VidaAPIClient.shared.verifyOTP(email: email, otpCode: otpCode) } catch { self.error = "Invalid code."; isLoading = false } }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @ObservedObject var auth: AuthVM
    @State private var gender = ""; @State private var concerns: Set<String> = []; @State private var isLoading = false
    private let healthConcerns = [("sleep","Sleep issues"),("energy","Low energy"),("mood","Mood / anxiety"),("pain","Chronic pain"),("digestion","Digestion"),("hormones","Hormonal / cycle"),("autoimmune","Autoimmune"),("brain_fog","Brain fog"),("stress","Stress"),("other","Other")]

    var body: some View {
        VStack(spacing: 24) {
            Text("Welcome to VIDA LAB").font(.system(size: 28, weight: .bold, design: .serif)).foregroundColor(Color(red: 0.18, green: 0.27, blue: 0.24))
            Text("Let's personalize your experience").font(.subheadline).foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                Text("I identify as").font(.headline)
                HStack(spacing: 12) {
                    ForEach(["female","male"], id: \.self) { g in
                        Button(g.capitalized) { gender = g }
                            .frame(maxWidth: .infinity).padding()
                            .background(gender == g ? Color(red: 0.18, green: 0.27, blue: 0.24) : Color(.systemGray6))
                            .foregroundColor(gender == g ? .white : .primary).cornerRadius(12)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("What are you tracking?").font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(healthConcerns, id: \.0) { tag, label in
                        Button(label) { if concerns.contains(tag) { concerns.remove(tag) } else { concerns.insert(tag) } }
                            .font(.caption).frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(concerns.contains(tag) ? Color(red: 0.24, green: 0.42, blue: 0.31) : Color(.systemGray6))
                            .foregroundColor(concerns.contains(tag) ? .white : .primary).cornerRadius(20)
                    }
                }
            }
            Spacer()
            Button(action: save) { if isLoading { ProgressView().tint(.white) } else { Text("Get Started").frame(maxWidth: .infinity) } }
                .buttonStyle(.borderedProminent).tint(Color(red: 0.18, green: 0.27, blue: 0.24))
                .disabled(isLoading || gender.isEmpty)
        }
        .padding()
    }
    private func save() {
        isLoading = true
        Task { do { auth.user = try await VidaAPIClient.shared.updateCurrentUser(["gender": gender, "health_concerns": Array(concerns)]) } catch { isLoading = false } }
    }
}

// MARK: - Dashboard View (Feature Grid)

enum FeatureDestination: Hashable { case dailySignals, bodyWeather, vidaDifferential, experiments, concierge, doctorFinder, patternMap, trends, askVida, community, library, apothecary }

struct FeatureItem: Identifiable { let id = UUID(); let icon: String; let title: String; let desc: String; let destination: FeatureDestination; let memberOnly: Bool; var plus: Bool = false }

struct DashboardView: View {
    @ObservedObject var auth: AuthVM
    @State private var dashboard: DashboardResponse?

    private let features: [FeatureItem] = [
        .init(icon: "calendar", title: "Daily Signals", desc: "Log energy, sleep, mood, and symptoms in two minutes. Each check-in returns a small, relevant insight.", destination: .dailySignals, memberOnly: true),
        .init(icon: "cloud.sun", title: "Body Weather", desc: "Your week ahead, forecasted from your patterns — predicted energy, mood, and flare risk before they hit.", destination: .bodyWeather, memberOnly: true, plus: true),
        .init(icon: "safari", title: "The Vida Differential", desc: "Stuck or dismissed? Your patterns mapped to conditions worth exploring, with tests to ask for and specialists to see.", destination: .vidaDifferential, memberOnly: true, plus: true),
        .init(icon: "flask", title: "Vida Experiments", desc: "Stop guessing. Run structured n=1 self-experiments on supplements, diets, and lifestyle changes.", destination: .experiments, memberOnly: true, plus: true),
        .init(icon: "stethoscope", title: "Appointment Concierge", desc: "Walk in prepared — a symptom narrative, questions to ask, tests to request, and an advocacy script.", destination: .concierge, memberOnly: true, plus: true),
        .init(icon: "mappin.circle", title: "Local Doctor Finder", desc: "Find specialists and doctors in your area who match your needs — no more guessing where to turn next.", destination: .doctorFinder, memberOnly: true, plus: true),
        .init(icon: "chart.line.uptrend.xyaxis", title: "Pattern Map", desc: "See how your energy, mood, and symptoms correlate across your cycle and over time.", destination: .patternMap, memberOnly: true, plus: true),
        .init(icon: "arrow.up.right.square", title: "Trends", desc: "Visualize your energy, sleep, and mood over 90 days to spot long-term patterns and seasonal shifts.", destination: .trends, memberOnly: true),
        .init(icon: "sparkles", title: "Ask Vida", desc: "Chat with Vida, your AI health companion, about research, symptoms, and terminology in plain language.", destination: .askVida, memberOnly: false),
        .init(icon: "bubble.left.and.bubble.right", title: "Community", desc: "An anonymous, moderated space to discuss health topics and share wellness tips with others.", destination: .community, memberOnly: true),
        .init(icon: "book", title: "Condition Library", desc: "Browse detailed reports on 150+ chronic conditions with advocacy guides and action plans.", destination: .library, memberOnly: false),
        .init(icon: "heart.text.square", title: "The Vida Apothecary", desc: "100+ original recipes, gentle exercises, guided meditations, supplement guides, and wellness rituals — all cited and evidence-informed.", destination: .apothecary, memberOnly: false),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(features) { f in FeatureCard(feature: f) }
                }
                .padding()
            }
            .navigationTitle("VIDA LAB")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Sign Out") { auth.logout() } } }
            .navigationDestination(for: FeatureDestination.self) { dest in destinationView(dest) }
            .task { if dashboard == nil { do { dashboard = try await VidaAPIClient.shared.getDashboard(); if let u = dashboard?.user { auth.user = u } } catch {} } }
        }
    }

    @ViewBuilder private func destinationView(_ d: FeatureDestination) -> some View {
        switch d {
        case .dailySignals: DailySignalsView()
        case .bodyWeather: BodyWeatherView()
        case .vidaDifferential: Text("Vida Differential — patterns mapped to conditions worth exploring.").padding()
        case .experiments: VidaExperimentsView()
        case .concierge: AppointmentConciergeView()
        case .doctorFinder: DoctorFinderView()
        case .patternMap: PatternMapView()
        case .trends: TrendsView()
        case .askVida: AskVidaView()
        case .community: CommunityView()
        case .library: ConditionLibraryView()
        case .apothecary: ApothecaryView()
        }
    }
}

struct FeatureCard: View {
    let feature: FeatureItem
    var body: some View {
        NavigationLink(value: feature.destination) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: feature.icon).font(.system(size: 20)).foregroundColor(Color(red: 0.18, green: 0.27, blue: 0.24)).frame(width: 32)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(feature.title).font(.system(size: 14, weight: .semibold)).foregroundColor(Color(red: 0.2, green: 0.25, blue: 0.28))
                        Spacer()
                        if feature.plus {
                            Text("+").font(.system(size: 10, weight: .bold)).foregroundColor(.white).frame(width: 18, height: 18).background(Color(red: 0.24, green: 0.42, blue: 0.31)).clipShape(Circle())
                        }
                    }
                    Text(feature.desc).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14).background(Color(red: 0.93, green: 0.94, blue: 0.95)).cornerRadius(14)
        }
    }
}