//
//  VidaLab_iOS_Core.swift
//  VIDA LAB — Core: Config, API Client, Models, Apothecary Data
//
//  Copy into your Xcode project. No third-party dependencies.
//  This file contains: configuration, keychain, network layer, all Codable models,
//  and the Apothecary category/filter data that mirrors the web app.
//

import Foundation

// MARK: - Configuration

struct VidaConfig {
    static let baseURL = "https://vidalab.base44.app"
    static let appId = "YOUR_APP_ID_HERE"
    static let apiBase = "\(baseURL)/api"
}

// MARK: - Keychain Helper

final class KeychainHelper {
    static let shared = KeychainHelper()
    private let service = "com.vidalab.ios"

    func save(_ value: String, _ key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        SecItemDelete(q as CFDictionary)
        var add = q; add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }
    func read(_ key: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        guard let data = SecItemCopyMatching(q as CFDictionary, nil) as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    func delete(_ key: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        SecItemDelete(q as CFDictionary)
    }
}

// MARK: - API Errors

enum VidaAPIError: Error, LocalizedError {
    case invalidURL, invalidResponse, unauthorized, forbidden
    case serverError(String), decodingError(String), networkError(String)
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .unauthorized: return "Please log in again"
        case .forbidden: return "You don't have access to this feature"
        case .serverError(let m): return m
        case .decodingError(let m): return "Data error: \(m)"
        case .networkError(let m): return m
        }
    }
}

// MARK: - API Client

final class VidaAPIClient {
    static let shared = VidaAPIClient()
    private var token: String? {
        get { KeychainHelper.shared.read("vida_auth_token") }
        set { if let v = newValue { KeychainHelper.shared.save(v, "vida_auth_token") } else { KeychainHelper.shared.delete("vida_auth_token") } }
    }
    var authToken: String? { token }

    // Auth
    func login(email: String, password: String) async throws -> User {
        let r: LoginResponse = try await post("/auth/login", body: ["email": email, "password": password])
        token = r.access_token; return r.user
    }
    func register(email: String, password: String) async throws {
        let _: RegisterResponse = try await post("/auth/register", body: ["email": email, "password": password])
    }
    func verifyOTP(email: String, otpCode: String) async throws -> User {
        let r: LoginResponse = try await post("/auth/verify-otp", body: ["email": email, "otp_code": otpCode])
        token = r.access_token; return r.user
    }
    func resendOTP(email: String) async throws { let _: EmptyResponse = try await post("/auth/resend-otp", body: ["email": email]) }
    func resetPasswordRequest(email: String) async throws { let _: EmptyResponse = try await post("/auth/reset-password-request", body: ["email": email]) }
    func resetPassword(resetToken: String, newPassword: String) async throws { let _: EmptyResponse = try await post("/auth/reset-password", body: ["reset_token": resetToken, "new_password": newPassword]) }
    func getCurrentUser() async throws -> User { try await get("/auth/me") }
    func updateCurrentUser(_ data: [String: Any]) async throws -> User { try await patch("/auth/me", body: data) }
    func logout() async { if token != nil { try? await postEmpty("/auth/logout") }; token = nil }
    func loginWithGoogle(idToken: String) async throws -> User {
        let r: LoginResponse = try await post("/auth/provider", body: ["provider": "google", "id_token": idToken])
        token = r.access_token; return r.user
    }

    // Mobile functions
    func getDashboard() async throws -> DashboardResponse { try await post("/functions/mobile-dashboard", body: [:]) }
    func submitCheckin(_ c: [String: Any]) async throws -> CheckInResponse { try await post("/functions/mobile-checkin", body: c) }
    func toggleFavorite(resourceId: String, title: String, category: String?) async throws -> FavoriteToggleResponse {
        var b: [String: Any] = ["resource_id": resourceId, "resource_title": title]; if let c = category { b["resource_category"] = c }
        return try await post("/functions/mobile-favorite-toggle", body: b)
    }
    func flagCommunityContent(type: String, id: String) async throws { let _: EmptyResponse = try await post("/functions/flag-community-content", body: ["type": type, "id": id]) }

    // Vida+ AI functions
    func getBodyWeather() async throws -> BodyWeatherResponse { try await post("/functions/body-weather-forecast", body: [:]) }
    func getExperimentResults(experimentId: String) async throws -> ExperimentResultsResponse { try await post("/functions/experiment-results", body: ["experimentId": experimentId]) }
    func getAppointmentConcierge(conditionSlug: String?, visitReason: String?) async throws -> AppointmentConciergeResponse {
        var b: [String: Any] = [:]; if let s = conditionSlug { b["conditionSlug"] = s }; if let r = visitReason { b["visitReason"] = r }
        return try await post("/functions/appointment-concierge", body: b)
    }
    func sendChatMessage(conversationId: String, content: String) async throws { let _: EmptyResponse = try await post("/functions/vida-chat-send", body: ["conversationId": conversationId, "content": content]) }
    func checkPaymentStatus() async throws -> PaymentStatusResponse { try await post("/functions/check-payment-status", body: [:]) }

    // Entity CRUD
    func listEntities<T: Decodable>(_ name: String, sort: String? = nil, limit: Int? = nil, filter: [String: Any]? = nil) async throws -> [T] {
        var path = "/entities/\(name)"; var params: [String: String] = [:]
        if let s = sort { params["sort"] = s }; if let l = limit { params["limit"] = String(l) }
        if let f = filter { let d = try JSONSerialization.data(withJSONObject: f); params["filter"] = String(data: d, encoding: .utf8) }
        if !params.isEmpty { path += "?" + params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&") }
        return try await get(path)
    }
    func getEntity<T: Decodable>(_ name: String, id: String) async throws -> T { try await get("/entities/\(name)/\(id)") }
    func createEntity<T: Decodable>(_ name: String, body: [String: Any]) async throws -> T { try await post("/entities/\(name)", body: body) }
    func updateEntity<T: Decodable>(_ name: String, id: String, body: [String: Any]) async throws -> T { try await patch("/entities/\(name)/\(id)", body: body) }
    func deleteEntity(_ name: String, id: String) async throws { try await delete("/entities/\(name)/\(id)") }

    // HTTP helpers
    private func get<T: Decodable>(_ p: String) async throws -> T { try await req(p, "GET", nil) }
    private func post<T: Decodable>(_ p: String, body: [String: Any]) async throws -> T { try await req(p, "POST", body) }
    private func postEmpty(_ p: String) async throws { let _: EmptyResponse = try await req(p, "POST", Optional<[String: Any]>.none) }
    private func patch<T: Decodable>(_ p: String, body: [String: Any]) async throws -> T { try await req(p, "PATCH", body) }
    private func delete(_ p: String) async throws { let _: EmptyResponse = try await req(p, "DELETE", Optional<[String: Any]>.none) }

    private func req<T: Decodable>(_ path: String, _ method: String, _ body: [String: Any]?) async throws -> T {
        guard let url = URL(string: VidaConfig.apiBase + path) else { throw VidaAPIError.invalidURL }
        var r = URLRequest(url: url); r.httpMethod = method
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = token { r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        if let b = body { r.httpBody = try JSONSerialization.data(withJSONObject: b) }
        do {
            let (data, resp) = try await URLSession.shared.data(for: r)
            guard let h = resp as? HTTPURLResponse else { throw VidaAPIError.invalidResponse }
            if h.statusCode == 401 { throw VidaAPIError.unauthorized }
            if h.statusCode == 403 { throw VidaAPIError.forbidden }
            guard (200...299).contains(h.statusCode) else { throw VidaAPIError.serverError(String(data: data, encoding: .utf8) ?? "Error (\(h.statusCode))") }
            do { return try JSONDecoder().decode(T.self, from: data) } catch { throw VidaAPIError.decodingError(String(describing: error)) }
        } catch let e as VidaAPIError { throw e } catch { throw VidaAPIError.networkError(error.localizedDescription) }
    }
}

// MARK: - Data Models

struct EmptyResponse: Codable {}
struct RegisterResponse: Codable { let message: String? }

struct User: Codable, Identifiable {
    let id: String; let email: String; let full_name: String?; let role: String
    var membership: String?; var gender: String?; var health_concerns: [String]?
    var hasVidaPlus: Bool { membership == "vida_plus" }
}
struct LoginResponse: Codable { let access_token: String; let user: User }

struct DashboardResponse: Codable {
    let user: User; let latestCheckin: CheckIn?; let recentCheckins: [CheckIn]
    let favorites: [Favorite]; let activeExperiments: [Experiment]
    let upcomingAppointments: [Appointment]; let currentTreatments: [Treatment]
}

struct CheckIn: Codable, Identifiable {
    let id: String; let checkin_date: String; let energy: Int; let mood: String
    let sleep_hours: Double?; let sleep_quality: Int?; let pain_level: Int?
    let cycle_phase: String?; let symptoms: [String]?; let practices: [String]?
    let notes: String?; let insight: String?
}
struct CheckInResponse: Codable { let success: Bool; let checkin: CheckIn; let insight: String }

struct Favorite: Codable, Identifiable { let id: String; let resource_id: String; let resource_title: String; let resource_category: String? }
struct FavoriteToggleResponse: Codable { let favorited: Bool; let resource_id: String }

struct Experiment: Codable, Identifiable {
    let id: String; let title: String; let intervention: String; let hypothesis: String
    let duration_days: Int; let start_date: String?; let end_date: String?; let status: String
    let metrics_to_watch: [String]?; let results_summary: String?
}
struct ExperimentLog: Codable, Identifiable { let id: String; let experiment_id: String; let log_date: String; let adhered: Bool; let notes: String? }
struct ExperimentResultsResponse: Codable { let status: String; let results: ExperimentResults?; let stats: ExperimentStats?; let generatedAt: String? }
struct ExperimentResults: Codable { let verdict: String; let confidence: String; let on_days_summary: String?; let off_days_summary: String?; let key_findings: [String]; let recommendations: [String]?; let disclaimer: String }
struct ExperimentStats: Codable { let adherent: ExperimentStatGroup; let nonAdherent: ExperimentStatGroup }
struct ExperimentStatGroup: Codable { let count: Int; let avgEnergy: Double?; let avgSleepHours: Double?; let avgSleepQuality: Double?; let avgPain: Double? }

struct Treatment: Codable, Identifiable { let id: String; let name: String; let type: String; let start_date: String?; let end_date: String?; let dosage: String?; let effectiveness: Int?; let side_effects: String?; let notes: String?; let status: String? }

struct Appointment: Codable, Identifiable { let id: String; let doctor_id: String?; let doctor_name: String; let practice_name: String?; let specialty: String?; let appointment_date: String; let appointment_time: String; let reason: String?; let status: String; let notes: String? }

struct HealthResource: Codable, Identifiable { let id: String; let title: String; let category: String; let subcategory: String?; let description: String?; let content: String?; let duration_minutes: Double?; let difficulty: String?; let tags: [String]?; let citations: String?; let is_public: Bool?; let sort_order: Double? }

struct DiseaseReport: Codable, Identifiable { let id: String; let name: String; let slug: String; let category: String; let summary: String?; let overview: String?; let symptoms: String?; let diagnosis: String?; let treatments: String?; let resources: String?; let doctors_guide: String?; let advocacy_guide: String?; let conquer_plan: String?; let is_public: Bool? }

struct Doctor: Codable, Identifiable { let id: String; let practice_name: String; let specialty: String; let category: String?; let phone: String?; let email: String?; let address: String?; let city: String?; let state: String?; let zip_code: String?; let website: String?; let accepting_new_patients: Bool?; let notes: String? }

struct CommunityPost: Codable, Identifiable { let id: String; let title: String; let content: String; let category: String; let display_name: String?; let status: String?; let flagged: Bool?; let created_date: String? }
struct CommunityReply: Codable, Identifiable { let id: String; let post_id: String; let content: String; let display_name: String?; let status: String?; let flagged: Bool?; let created_date: String? }

struct BodyWeatherResponse: Codable { let status: String; let forecast: BodyWeatherForecast?; let message: String?; let checkinCount: Int?; let generatedAt: String? }
struct BodyWeatherForecast: Codable { let summary: String; let patterns: [String]; let forecast: [ForecastDay]; let top_triggers: [String]; let weekly_actions: [String]; let disclaimer: String }
struct ForecastDay: Codable, Identifiable { var id: String { date }; let day: String; let date: String; let energy: String; let mood: String; let risk_level: String; let risk_areas: [String]?; let headline: String; let why: String; let actions: [String] }

struct AppointmentConciergeResponse: Codable { let status: String; let prep: AppointmentConciergePrep?; let message: String?; let checkinCount: Int?; let generatedAt: String? }
struct AppointmentConciergePrep: Codable { let visit_summary: String; let symptom_narrative: String; let key_metrics: [ConciergeMetric]?; let questions_to_ask: [String]; let tests_to_request: [String]?; let advocacy_script: String; let what_to_bring: [String]?; let disclaimer: String }
struct ConciergeMetric: Codable, Identifiable { var id: String { label }; let label: String; let value: String; let context: String? }

struct PaymentStatusResponse: Codable { let status: String }

// MARK: - Apothecary Data (mirrors src/data/healthCategories.js)

enum ApothecaryCategory: String, CaseIterable, Identifiable {
    case all, recipe, exercise, meditation, supplement, habit
    var id: String { rawValue }
    var label: String {
        switch self { case .all: return "All"; case .recipe: return "Recipes"; case .exercise: return "Exercises"; case .meditation: return "Meditations"; case .supplement: return "Supplements"; case .habit: return "Habits" }
    }
}

enum ApothecarySubcategory {
    static let all: [String: [String]] = [
        "recipe": ["anti-inflammatory", "breakfast", "lunch", "dinner", "snacks", "drinks"],
        "exercise": ["push", "pull", "legs", "abs", "cardio", "pilates", "strength", "stretching", "yoga", "mobility", "education"],
        "meditation": ["breathing", "body-scan", "mindfulness", "sleep"],
        "supplement": ["anti-inflammatory", "sleep", "energy", "immune", "gut-health"],
        "habit": ["sleep", "nutrition", "movement", "stress", "hydration"],
    ]
    static func forCategory(_ cat: String) -> [String] { all[cat] ?? [] }
    static func prettyLabel(_ sub: String) -> String { sub.replacingOccurrences(of: "-", with: " ").capitalized }
}

struct FocusFilter: Identifiable { let id: String; let label: String; let tag: String; let categories: [String]? }
struct FocusGroup: Identifiable { let id: String; let label: String; let categories: [String]; let filters: [FocusFilter] }

let apothecaryFocusGroups: [FocusGroup] = [
    FocusGroup(id: "Dietary", label: "Dietary", categories: ["recipe"], filters: [
        .init(id: "high-protein", label: "High Protein", tag: "high-protein", categories: nil),
        .init(id: "vegetarian", label: "Vegetarian", tag: "vegetarian", categories: nil),
        .init(id: "vegan", label: "Vegan", tag: "vegan", categories: nil),
        .init(id: "gluten-free", label: "Gluten-Free", tag: "gluten-free", categories: nil),
        .init(id: "low-carb", label: "Low-Carb", tag: "low-carb", categories: nil),
        .init(id: "grain-free", label: "Grain-Free", tag: "grain-free", categories: nil),
    ]),
    FocusGroup(id: "Wellness Goals", label: "Wellness Goals", categories: ["recipe", "exercise", "meditation", "supplement", "habit"], filters: [
        .init(id: "anti-inflammatory", label: "Anti-Inflammatory", tag: "anti-inflammatory", categories: nil),
        .init(id: "sleep", label: "Sleep Support", tag: "sleep", categories: nil),
        .init(id: "energy", label: "Energy", tag: "energy", categories: nil),
        .init(id: "gut-health", label: "Gut Health", tag: "gut-health", categories: nil),
        .init(id: "immune", label: "Immune Support", tag: "immune", categories: nil),
        .init(id: "stress", label: "Stress Relief", tag: "stress", categories: nil),
        .init(id: "pain", label: "Pain Relief", tag: "pain", categories: nil),
        .init(id: "digestion", label: "Digestion", tag: "digestion", categories: nil),
        .init(id: "recovery", label: "Recovery", tag: "recovery", categories: nil),
        .init(id: "focus", label: "Focus & Clarity", tag: "focus", categories: nil),
    ]),
    FocusGroup(id: "Practical", label: "Practical", categories: ["exercise", "meditation", "habit", "recipe"], filters: [
        .init(id: "quick", label: "Quick (≤5 min)", tag: "quick", categories: nil),
        .init(id: "desk-friendly", label: "Desk-Friendly", tag: "desk-friendly", categories: nil),
        .init(id: "flare-safe", label: "Flare-Safe", tag: "flare-safe", categories: nil),
        .init(id: "chair-friendly", label: "Chair-Friendly", tag: "chair-friendly", categories: nil),
        .init(id: "one-pot", label: "One-Pot", tag: "one-pot", categories: ["recipe"]),
        .init(id: "no-cook", label: "No-Cook", tag: "no-cook", categories: ["recipe"]),
        .init(id: "meal-prep", label: "Meal Prep", tag: "meal-prep", categories: ["recipe"]),
    ]),
    FocusGroup(id: "Equipment", label: "Equipment", categories: ["exercise"], filters: [
        .init(id: "bodyweight", label: "Bodyweight", tag: "bodyweight", categories: nil),
        .init(id: "dumbbell", label: "Dumbbells", tag: "dumbbell", categories: nil),
        .init(id: "barbell", label: "Barbell", tag: "barbell", categories: nil),
        .init(id: "cable", label: "Cable", tag: "cable", categories: nil),
        .init(id: "machine", label: "Machine", tag: "machine", categories: nil),
        .init(id: "kettlebell", label: "Kettlebell", tag: "kettlebell", categories: nil),
    ]),
    FocusGroup(id: "Audience", label: "Audience", categories: ["recipe", "exercise", "meditation", "supplement", "habit"], filters: [
        .init(id: "mens-health", label: "For Men", tag: "mens-health", categories: nil),
        .init(id: "womens-health", label: "For Women", tag: "womens-health", categories: nil),
        .init(id: "seniors", label: "Seniors", tag: "seniors", categories: nil),
        .init(id: "injured", label: "Injured / Rehab", tag: "injured", categories: nil),
        .init(id: "beginners", label: "Beginners", tag: "beginners", categories: nil),
        .init(id: "athletes", label: "Athletes", tag: "athletes", categories: nil),
        .init(id: "prenatal", label: "Prenatal", tag: "prenatal", categories: nil),
    ]),
]