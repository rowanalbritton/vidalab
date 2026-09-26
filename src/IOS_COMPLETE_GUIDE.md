# VIDA LAB — iOS App Complete Integration Guide

> ## ⚠️ CRITICAL REMINDER ⚠️>
> **DO NOT remove, replace, or "clean up" ANY existing feature in the web app.**
> This guide is for building a **separate native iOS app in Xcode** that connects
> to the same Base44 backend as the website. The web app stays untouched.
> All features must remain intact on both platforms.

---

## Table of Contents

**Getting Started**
1. [Architecture Overview](#1-architecture-overview)
2. [What You Need to Get Started](#2-what-you-need-to-get-started)
3. [Authentication — Login, Register, OTP](#3-authentication)
4. [Custom Backend Functions](#4-custom-backend-functions)
5. [Standard Entity API (CRUD)](#5-standard-entity-api)
6. [Data Sync Explained](#6-data-sync-explained)
7. [Push Notifications](#7-push-notifications)
8. [Swift Code Examples](#8-swift-code-examples)
9. [Complete Endpoint Reference](#9-complete-endpoint-reference)
10. [Troubleshooting](#10-troubleshooting)

**New Features to Build (added after initial integration)**
11. [Onboarding Flow (Gender + Health Concerns)](#11-onboarding-flow)
12. [Conditional Cycle Tracking in Check-in Form](#12-conditional-cycle-tracking)
13. [Sleep & Mood Chart](#13-sleep--mood-chart)
14. [Community Feature](#14-community-feature)
15. [Backend-Only Changes (No iOS UI Needed)](#15-backend-only-changes)

---

# PART ONE: Core Integration

---

## 1. Architecture Overview

```
┌─────────────────┐         ┌─────────────────┐
│   Website       │         │   iOS App       │
│   (React)       │         │   (Swift/Xcode) │
│   vidalab       │         │                 │
│   .base44.app   │         │                 │
└────────┬────────┘         └────────┬────────┘
         │                           │
         │    Same Base44 Backend     │
         │    (Shared Database)       │
         └───────────┬─────────────────┘
                     │
         ┌───────────▼─────────────────┐
         │   Base44 API + Backend       │
         │   Functions                  │
         │   • Authentication           │
         │   • DailyCheckin entity      │
         │   • Favorite entity          │
         │   • Experiment entity        │
         │   • Treatment entity         │
         │   • Appointment entity       │
         │   • HealthResource entity    │
         │   • DiseaseReport entity     │
         │   • CommunityPost entity     │
         │   • CommunityReply entity    │
         │   • + custom mobile-* fns   │
         └─────────────────────────────┘
```

**Key concept:** The website and the iOS app are two different frontends that talk to the **same backend**. User accounts, favorites, check-ins, and all data are shared. When a user favorites something on the web, it appears in the iOS app, and vice versa.

---

## 2. What You Need to Get Started

### From Your Base44 Dashboard

1. **App ID** — Found in your Base44 dashboard under the **API** page. This identifies your app.
2. **API Base URL** — `https://vidalab.base44.app` (your published app URL)
3. **API Documentation** — Available in the Base44 dashboard under **API** → API docs

### You Do NOT Need
- ❌ A repository or code from the web app
- ❌ A separate database
- ❌ A sync service
- ❌ Any web app code changes

### What Your iOS App Needs
- ✅ Your **App ID**
- ✅ A network layer that calls the Base44 REST API
- ✅ A secure token store (Keychain) for the user's auth token
- ✅ Standard HTTP request/response handling

---

## 3. Authentication

The Base44 API handles all authentication. The same accounts work on both web and iOS.

### 3.1 Login (Email + Password)

```
POST https://vidalab.base44.app/api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "theirpassword"
}
```

**Response (200):**
```json
{
  "access_token": "eyJhbGci...",
  "user": {
    "id": "user_123",
    "email": "user@example.com",
    "full_name": "Jane Doe",
    "role": "user",
    "membership": "vida_plus"
  }
}
```

**Store the `access_token` in Keychain.** Send it as a Bearer token with every subsequent request:
```
Authorization: Bearer eyJhbGci...
```

### 3.2 Register

```
POST https://vidalab.base44.app/api/auth/register
Content-Type: application/json

{
  "email": "newuser@example.com",
  "password": "securepassword"
}
```

**Response (200):**
```json
{
  "message": "Registration successful. Please verify your email."
}
```

After registration, the user must verify via OTP (one-time code sent to their email).

### 3.3 Verify OTP

```
POST https://vidalab.base44.app/api/auth/verify-otp
Content-Type: application/json

{
  "email": "newuser@example.com",
  "otp_code": "123456"
}
```

**Response (200):**
```json
{
  "access_token": "eyJhbGci...",
  "user": { ... }
}
```

Store this token — the user is now logged in.

### 3.4 Resend OTP

```
POST https://vidalab.base44.app/api/auth/resend-otp
Content-Type: application/json

{
  "email": "newuser@example.com"
}
```

### 3.5 Forgot Password

```
POST https://vidalab.base44.app/api/auth/reset-password-request
Content-Type: application/json

{
  "email": "user@example.com"
}
```

Always show generic success (the API doesn't reveal whether the email exists).

### 3.6 Reset Password

```
POST https://vidalab.base44.app/api/auth/reset-password
Content-Type: application/json

{
  "reset_token": "token_from_email_link",
  "new_password": "newsecurepassword"
}
```

### 3.7 Get Current User

```
GET https://vidalab.base44.app/api/auth/me
Authorization: Bearer <token>
```

**Response (200):**
```json
{
  "id": "user_123",
  "email": "user@example.com",
  "full_name": "Jane Doe",
  "role": "user",
  "membership": "vida_plus",
  "gender": "female",
  "health_concerns": ["sleep", "energy"]
}
```

### 3.8 Update Current User

```
PATCH https://vidalab.base44.app/api/auth/me
Authorization: Bearer <token>
Content-Type: application/json

{ "gender": "female", "health_concerns": ["sleep", "energy"] }
```

> Use this endpoint to save onboarding data (gender, health concerns) and any user preferences. Built-in fields (`id`, `email`, `full_name`, `role`) cannot be overridden.

### 3.9 Logout

```
POST https://vidalab.base44.app/api/auth/logout
Authorization: Bearer <token>
```

Clear the token from Keychain after logout.

### 3.10 Google OAuth

For Google sign-in on iOS, use Google's Sign-In SDK to get a Google ID token, then send it to Base44:

```
POST https://vidalab.base44.app/api/auth/provider
Content-Type: application/json

{
  "provider": "google",
  "id_token": "google_id_token_here"
}
```

---

## 4. Custom Backend Functions

Three custom backend functions bundle common operations, reducing API calls.

### 4.1 Mobile Dashboard — One Call for Everything

Returns the user's profile, latest check-ins, favorites, active experiments, upcoming appointments, and current treatments in a single API call.

```
POST https://vidalab.base44.app/api/functions/mobile-dashboard
Authorization: Bearer <token>
Content-Type: application/json
```

**No body needed.** The user is identified by the token.

**Response (200):**
```json
{
  "user": {
    "id": "user_123",
    "email": "user@example.com",
    "full_name": "Jane Doe",
    "role": "user",
    "membership": "vida_plus",
    "has_vida_plus": true
  },
  "latestCheckin": { ... } | null,
  "recentCheckins": [ ...up to 30 ],
  "favorites": [
    {
      "id": "fav_123",
      "resource_id": "resource_456",
      "resource_title": "Anti-Inflammatory Salmon Bowl",
      "resource_category": "recipe"
    }
  ],
  "activeExperiments": [ ... ],
  "upcomingAppointments": [ ... ],
  "currentTreatments": [ ... ]
}
```

**Use this on app launch** to populate the home screen instantly.

### 4.2 Mobile Check-in — Submit + Get Insight

Submits a daily check-in, generates the educational insight (same rule-based engine as the web), saves it, and returns the saved record with the insight.

```
POST https://vidalab.base44.app/api/functions/mobile-checkin
Authorization: Bearer <token>
Content-Type: application/json

{
  "checkin_date": "2026-09-20",
  "energy": 4,
  "sleep_hours": 7.5,
  "sleep_quality": 3,
  "mood": "calm",
  "pain_level": 0,
  "cycle_phase": "luteal",
  "symptoms": ["bloating"],
  "practices": ["meditation", "anti_inflammatory_meal"],
  "notes": "Felt good today after morning meditation"
}
```

**Required fields:** `checkin_date`, `energy` (1-5), `mood` (one of: calm, happy, neutral, anxious, sad, irritable, motivated)

**Optional fields:** `sleep_hours` (0-14), `sleep_quality` (1-5), `pain_level` (0-3), `cycle_phase` (menstrual, follicular, ovulation, luteal, not_tracking), `symptoms` (array), `practices` (array), `notes` (string)

**Valid symptoms:** headache, cramps, bloating, fatigue, breast_tenderness, acne, backache, nausea, brain_fog, cravings, none

**Valid practices:** meditation, gentle_exercise, anti_inflammatory_meal, supplement, breathing_exercise, nature_time, sleep_hygiene, hydration, gratitude, stretching

**Response (200):**
```json
{
  "success": true,
  "checkin": {
    "id": "checkin_789",
    "checkin_date": "2026-09-20",
    "energy": 4,
    "mood": "calm",
    "insight": "Good energy on rested sleep is your baseline state..."
  },
  "insight": "Good energy on rested sleep is your baseline state..."
}
```

The insight is the same educational, non-diagnostic wellness observation the web app generates.

### 4.3 Mobile Favorite Toggle — Add or Remove

Toggles a favorite in one call. If the resource is already favorited, it removes it. If not, it adds it.

```
POST https://vidalab.base44.app/api/functions/mobile-favorite-toggle
Authorization: Bearer <token>
Content-Type: application/json

{
  "resource_id": "resource_456",
  "resource_title": "Anti-Inflammatory Salmon Bowl",
  "resource_category": "recipe"
}
```

**Required fields:** `resource_id`, `resource_title`
**Optional:** `resource_category`

**Response (200):**
```json
{
  "favorited": true,
  "resource_id": "resource_456"
}
```

Or if it was already favorited and is now removed:
```json
{
  "favorited": false,
  "resource_id": "resource_456"
}
```

**The favorite syncs to the web instantly** — the user will see it on the website too.

---

## 5. Standard Entity API

For operations not covered by the custom functions, your iOS app can call the standard Base44 entity API directly.

### 5.1 List Records

```
GET https://vidalab.base44.app/api/entities/DailyCheckin?sort=-checkin_date&limit=30
Authorization: Bearer <token>
```

### 5.2 Filter Records

```
GET https://vidalab.base44.app/api/entities/DailyCheckin?filter={"checkin_date":{"$gte":"2026-09-01"}}
Authorization: Bearer <token>
```

### 5.3 Get Single Record

```
GET https://vidalab.base44.app/api/entities/DailyCheckin/record_id_here
Authorization: Bearer <token>
```

### 5.4 Create Record

```
POST https://vidalab.base44.app/api/entities/DailyCheckin
Authorization: Bearer <token>
Content-Type: application/json

{
  "checkin_date": "2026-09-20",
  "energy": 4,
  "mood": "calm"
}
```

### 5.5 Update Record

```
PATCH https://vidalab.base44.app/api/entities/DailyCheckin/record_id_here
Authorization: Bearer <token>
Content-Type: application/json

{
  "notes": "Updated note"
}
```

### 5.6 Delete Record

```
DELETE https://vidalab.base44.app/api/entities/DailyCheckin/record_id_here
Authorization: Bearer <token>
```

### Available Entities

| Entity | Access | Notes |
|--------|--------|-------|
| `DailyCheckin` | User's own records only | Per-user (RLS) |
| `Favorite` | User's own records only | Per-user (RLS) |
| `Experiment` | User's own records only | Per-user (RLS) |
| `ExperimentLog` | User's own records only | Per-user (RLS) |
| `Treatment` | User's own records only | Per-user (RLS) |
| `Appointment` | User's own records only | Per-user (RLS) |
| `CommunityPost` | Active posts visible to all; hidden admin-only | Authenticated users create |
| `CommunityReply` | Active replies visible to all; hidden admin-only | Authenticated users create |
| `Doctor` | Public read | Directory |
| `HealthResource` | Public read | Apothecary library |
| `DiseaseReport` | Public read | Condition reports |
| `Explainer` | Public read | Educational content |
| `SubstackArticle` | Public read | Article links |
| `ResearchPaper` | Public read | AP papers |

---

## 6. Data Sync Explained

### How It Works
- Both the website and the iOS app connect to the **same Base44 backend**
- All data lives in one cloud database
- The user's auth token works on both platforms
- Any action on the web is instantly visible in the iOS app, and vice versa

### Favorites Sync
1. User taps heart on a recipe in the iOS app → `mobile-favorite-toggle` creates a `Favorite` record
2. User opens the website → the web app loads the same `Favorite` records → heart shows as filled
3. User removes a favorite on the web → `Favorite` record is deleted → disappears from iOS app
4. **No extra sync code needed.** Both platforms read/write the same entity.

### Check-in Sync
1. User submits a check-in on the iOS app → `mobile-checkin` creates a `DailyCheckin` record
2. User opens the website → the web app loads the same `DailyCheckin` records → history, charts, and insights all show the same data
3. User does a check-in on the web → it appears in the iOS app immediately
4. **No extra sync code needed.** Both platforms read/write the same entity.

### Membership Sync
1. User purchases Vida+ on the web → `payments-webhook` sets `membership: "vida_plus"` on the user
2. User opens the iOS app → `GET /api/auth/me` returns `membership: "vida_plus"` → app unlocks premium features
3. **Same account, same membership, both platforms.**

---

## 7. Push Notifications

The `send-reminders` backend function already sends push notifications for daily check-in reminders. To receive them in your iOS app:

### 7.1 Set Up APNs Key

1. Go to your Apple Developer account → **Certificates, Identifiers & Profiles → Keys**
2. Create a new key with **Apple Push Notifications service (APNs)** enabled
3. Download the `.p8` file and note the **Key ID**
4. In your Base44 dashboard → **Publish → Mobile app** → upload the `.p8` file and enter the Key ID

### 7.2 How Push Notifications Work

The `send-reminders` function runs every 30 minutes and:
1. Checks each user's preferred reminder time (default 8 PM their timezone)
2. Checks if they've already completed a check-in today
3. If not, sends an email AND a push notification:
   - **Title:** "Your daily check-in is waiting"
   - **Body:** "Two minutes to log your energy, mood, and symptoms."
   - **Action:** "Check in now" → opens the Daily Signals page

### 7.3 iOS Push Notification Setup

In your Xcode project:
1. Enable **Push Notifications** capability
2. Enable **Background Modes** → Remote notifications
3. Register for remote notifications in `AppDelegate.swift`
4. Send the device token to Base44 (via a backend function or user update)

---

## 8. Swift Code Examples

### 8.1 Network Manager

```swift
import Foundation

class VidaAPIClient {
    static let shared = VidaAPIClient()
    
    private let baseURL = "https://vidalab.base44.app/api"
    private var token: String? {
        get { KeychainHelper.shared.read("vida_auth_token") }
        set { 
            if let newValue = newValue {
                KeychainHelper.shared.save(newValue, "vida_auth_token")
            } else {
                KeychainHelper.shared.delete("vida_auth_token")
            }
        }
    }
    
    // Login
    func login(email: String, password: String) async throws -> User {
        let response: LoginResponse = try await post(
            "/auth/login",
            body: ["email": email, "password": password]
        )
        self.token = response.access_token
        return response.user
    }
    
    // Get Dashboard (one call for everything)
    func getDashboard() async throws -> DashboardResponse {
        return try await post("/functions/mobile-dashboard", body: [:])
    }
    
    // Submit Check-in
    func submitCheckin(_ checkin: CheckInRequest) async throws -> CheckInResponse {
        return try await post("/functions/mobile-checkin", body: checkin)
    }
    
    // Toggle Favorite
    func toggleFavorite(resourceId: String, title: String, category: String) async throws -> FavoriteToggleResponse {
        return try await post("/functions/mobile-favorite-toggle", body: [
            "resource_id": resourceId,
            "resource_title": title,
            "resource_category": category
        ])
    }
    
    // Generic POST helper
    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func logout() {
        token = nil
    }
}
```

### 8.2 Models

```swift
struct User: Codable {
    let id: String
    let email: String
    let full_name: String?
    let role: String
    let membership: String?
    let gender: String?
    let health_concerns: [String]?
    var hasVidaPlus: Bool { membership == "vida_plus" }
}

struct LoginResponse: Codable {
    let access_token: String
    let user: User
}

struct DashboardResponse: Codable {
    let user: User
    let latestCheckin: CheckIn?
    let recentCheckins: [CheckIn]
    let favorites: [Favorite]
    let activeExperiments: [Experiment]
    let upcomingAppointments: [Appointment]
    let currentTreatments: [Treatment]
}

struct CheckIn: Codable, Identifiable {
    let id: String
    let checkin_date: String
    let energy: Int
    let mood: String
    let sleep_hours: Double?
    let sleep_quality: Int?
    let pain_level: Int?
    let cycle_phase: String?
    let symptoms: [String]?
    let practices: [String]?
    let notes: String?
    let insight: String?
}

struct Favorite: Codable, Identifiable {
    let id: String
    let resource_id: String
    let resource_title: String
    let resource_category: String?
}

struct CheckInRequest: Codable {
    let checkin_date: String
    let energy: Int
    let mood: String
    let sleep_hours: Double?
    let sleep_quality: Int?
    let pain_level: Int?
    let cycle_phase: String?
    let symptoms: [String]
    let practices: [String]
    let notes: String?
}

struct CheckInResponse: Codable {
    let success: Bool
    let checkin: CheckIn
    let insight: String
}

struct FavoriteToggleResponse: Codable {
    let favorited: Bool
    let resource_id: String
}
```

### 8.3 Login View

```swift
import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var error: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("VIDA LAB")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            
            if let error = error {
                Text(error).foregroundColor(.red)
            }
            
            Button(action: login) {
                if isLoading { ProgressView() }
                else { Text("Sign In") }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
        }
        .padding()
    }
    
    func login() {
        isLoading = true
        error = nil
        Task {
            do {
                let user = try await VidaAPIClient.shared.login(email: email, password: password)
                // Navigate to dashboard
            } catch {
                self.error = "Login failed. Check your credentials."
                isLoading = false
            }
        }
    }
}
```

### 8.4 Check-in View

```swift
import SwiftUI

struct CheckInView: View {
    @State private var energy = 3
    @State private var mood = "neutral"
    @State private var symptoms: Set<String> = []
    @State private var practices: Set<String> = []
    @State private var notes = ""
    @State private var insight: String?
    @State private var isLoading = false
    
    let moods = ["calm", "happy", "neutral", "anxious", "sad", "irritable", "motivated"]
    let allSymptoms = ["headache", "cramps", "bloating", "fatigue", "brain_fog", "cravings", "none"]
    let allPractices = ["meditation", "gentle_exercise", "anti_inflammatory_meal", "supplement", "breathing_exercise", "nature_time", "sleep_hygiene", "hydration", "gratitude", "stretching"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Energy") {
                    Stepper("Energy: \(energy)/5", value: $energy, in: 1...5)
                }
                
                Section("Mood") {
                    Picker("Mood", selection: $mood) {
                        ForEach(moods, id: \.self) { Text($0.capitalized) }
                    }
                }
                
                Section("Symptoms") {
                    ForEach(allSymptoms, id: \.self) { symptom in
                        Toggle(symptom.replacingOccurrences(of: "_", with: " ").capitalized, isOn: Binding(
                            get: { symptoms.contains(symptom) },
                            set: { if $0 { symptoms.insert(symptom) } else { symptoms.remove(symptom) } }
                        ))
                    }
                }
                
                Section("Practices") {
                    ForEach(allPractices, id: \.self) { practice in
                        Toggle(practice.replacingOccurrences(of: "_", with: " ").capitalized, isOn: Binding(
                            get: { practices.contains(practice) },
                            set: { if $0 { practices.insert(practice) } else { practices.remove(practice) } }
                        ))
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                }
                
                if let insight = insight {
                    Section("Your Insight") {
                        Text(insight).italic()
                    }
                }
            }
            .navigationTitle("Daily Check-in")
            .toolbar {
                Button("Save") { submitCheckin() }
                    .disabled(isLoading)
            }
        }
    }
    
    func submitCheckin() {
        isLoading = true
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let request = CheckInRequest(
            checkin_date: formatter.string(from: Date()),
            energy: energy,
            mood: mood,
            sleep_hours: nil,
            sleep_quality: nil,
            pain_level: nil,
            cycle_phase: "not_tracking",
            symptoms: Array(symptoms),
            practices: Array(practices),
            notes: notes
        )
        Task {
            do {
                let response = try await VidaAPIClient.shared.submitCheckin(request)
                insight = response.insight
                isLoading = false
            } catch {
                isLoading = false
            }
        }
    }
}
```

---

## 9. Complete Endpoint Reference

### Authentication
| Method | Endpoint | Auth Required | Purpose |
|--------|----------|---------------|---------|
| POST | `/api/auth/login` | No | Login with email + password |
| POST | `/api/auth/register` | No | Register new account |
| POST | `/api/auth/verify-otp` | No | Verify OTP after registration |
| POST | `/api/auth/resend-otp` | No | Resend OTP code |
| POST | `/api/auth/reset-password-request` | No | Request password reset email |
| POST | `/api/auth/reset-password` | No | Reset password with token |
| GET | `/api/auth/me` | Yes | Get current user |
| PATCH | `/api/auth/me` | Yes | Update current user (gender, concerns, etc.) |
| POST | `/api/auth/logout` | Yes | Logout |
| POST | `/api/auth/provider` | No | OAuth login (Google) |

### Custom Mobile Functions
| Method | Endpoint | Auth Required | Purpose |
|--------|----------|---------------|---------|
| POST | `/api/functions/mobile-dashboard` | Yes | Get all dashboard data in one call |
| POST | `/api/functions/mobile-checkin` | Yes | Submit check-in + get insight |
| POST | `/api/functions/mobile-favorite-toggle` | Yes | Add or remove a favorite |
| POST | `/api/functions/flag-community-content` | Yes | Flag a community post or reply for moderation |

### Standard Entity CRUD
| Method | Endpoint | Auth Required | Purpose |
|--------|----------|---------------|---------|
| GET | `/api/entities/{EntityName}` | Yes | List/filter records |
| GET | `/api/entities/{EntityName}/{id}` | Yes | Get single record |
| POST | `/api/entities/{EntityName}` | Yes | Create record |
| PATCH | `/api/entities/{EntityName}/{id}` | Yes | Update record |
| DELETE | `/api/entities/{EntityName}/{id}` | Yes | Delete record |

### Available Entities
`DailyCheckin`, `Favorite`, `Experiment`, `ExperimentLog`, `Treatment`, `Appointment`, `CommunityPost`, `CommunityReply`, `Doctor`, `HealthResource`, `DiseaseReport`, `Explainer`, `SubstackArticle`, `ResearchPaper`

---

## 10. Troubleshooting

### "401 Unauthorized"
- Token is missing, expired, or invalid
- Re-authenticate the user with login or check `auth/me`

### "403 Forbidden"
- User is trying to access another user's data (RLS blocks this)
- Or the user account isn't registered for this app
- Or calling an admin-only function (like `send-reminders`) without admin role

### "Favorites don't sync"
- Verify the same user account is logged in on both web and iOS
- Check that the `resource_id` matches exactly between platforms
- Both platforms use the same `Favorite` entity — sync is automatic

### "Check-ins don't sync"
- Verify the same user account is logged in on both platforms
- Both platforms use the same `DailyCheckin` entity — sync is automatic

### "Push notifications not arriving"
- Must test on a physical device (simulator doesn't support push)
- Verify APNs key is uploaded to Base44
- Verify the user has `reminder_enabled` set to true
- The function skips users who already checked in today

### "Can't create User records"
- Users are created through the registration flow, not the entity API
- Use `POST /api/auth/register` to create new users

---

# PART TWO: New Features to Build

> These features were added to the web app after the initial iOS integration. Build these native screens to reach full feature parity.

---

## 11. Onboarding Flow

After a new user registers and verifies their OTP, show a multi-step onboarding before landing on the dashboard. This personalizes their experience.

### Step 1: Gender Selection

Show two options: **Male** and **Female**. This field controls whether cycle tracking appears in the check-in form (see section 12).

**API call to save:**
```
PATCH https://vidalab.base44.app/api/auth/me
Authorization: Bearer <token>
Content-Type: application/json

{ "gender": "female" }
```

> `gender` is stored on the User entity. Values: `"male"` or `"female"`.

### Step 2: Health Concerns

Show a multi-select list of health concerns the user wants to track. Suggested options:

- Sleep issues
- Low energy / fatigue
- Mood / anxiety
- Chronic pain
- Digestion / gut health
- Hormonal / cycle
- Autoimmune
- Brain fog
- Stress management
- Other

**API call to save:**
```
PATCH https://vidalab.base44.app/api/auth/me
Authorization: Bearer <token>
Content-Type: application/json

{ "health_concerns": ["sleep", "energy", "mood"] }
```

> `health_concerns` is a string array on the User entity. Use any short tag values you like — they're for personalization.

### Step 3: First Check-in (optional)

Optionally let the user complete their first check-in right in the onboarding flow using the existing `mobile-checkin` function (see section 12 for the conditional cycle field).

### When to Show

- After successful OTP verification (new registrations only)
- After `GET /api/auth/me`, check if `user.gender` is null/missing — if so, show onboarding
- Existing users who already have a gender set skip this flow

---

## 12. Conditional Cycle Tracking

The check-in form's **Cycle Phase** picker should only appear for users who selected "female" as their gender. All other users skip it.

### How to Implement

In your `CheckInView`, read `user.gender` from the logged-in user (returned by `GET /api/auth/me` or the login response):

```swift
if user.gender == "female" {
    // Show cycle phase picker: menstrual, follicular, ovulation, luteal, not_tracking
} else {
    // Hide the picker entirely
}
```

### API Call (unchanged)

The `mobile-checkin` function already accepts `cycle_phase`. When the user is not female, send:

```json
{ "cycle_phase": "not_tracking" }
```

No backend changes needed — this is purely a UI conditional.

---

## 13. Sleep & Mood Chart

A dual-axis chart showing the last 30 days of check-ins, plotting **sleep hours** and **mood score** together so the user can see how sleep affects mood.

### Data Fetch

```
GET https://vidalab.base44.app/api/entities/DailyCheckin?sort=-checkin_date&limit=30
Authorization: Bearer <token>
```

### Mood Score Mapping

Map the mood string to a 1–5 numeric score for charting:

```swift
func moodScore(_ mood: String) -> Double {
    switch mood {
    case "happy": return 5
    case "calm": return 4
    case "motivated": return 4
    case "neutral": return 3
    case "anxious": return 2
    case "irritable": return 2
    case "sad": return 1
    default: return 3
    }
}
```

### Chart Spec

- **X axis:** date (last 30 check-ins, oldest → newest)
- **Y axis (left):** sleep hours (0–14), line chart
- **Y axis (right):** mood score (1–5), line chart
- Use **SwiftUI Charts** (iOS 16+) or a library like [Charts](https://github.com/danielgindi/Charts)
- Show a legend: "Sleep (hours)" and "Mood (1–5)"
- Empty state: "No check-ins yet. Your sleep-mood pattern appears after a few days of tracking."

### Where to Show

On the Daily Signals / check-in history screen, below the existing mood-energy chart and above the check-in history list.

---

## 14. Community Feature

An anonymous, moderated community where users discuss health topics and share wellness tips.

### New Entities

| Entity | Fields | Access |
|--------|--------|--------|
| `CommunityPost` | `title`, `content`, `category`, `display_name`, `status`, `flagged` | Authenticated users create; active posts visible to all; hidden posts admin-only |
| `CommunityReply` | `post_id`, `content`, `display_name`, `status`, `flagged` | Same pattern as posts |

### New Backend Function

`flag-community-content` — lets any authenticated user flag a post or reply for moderator review.

### API Endpoints

#### List Posts (newest first)
```
GET https://vidalab.base44.app/api/entities/CommunityPost?sort=-created_date&limit=100
Authorization: Bearer <token>
```

> RLS automatically filters: regular users only see `status: "active"` posts. Admins see all (including hidden and flagged).

#### Create Post
```
POST https://vidalab.base44.app/api/entities/CommunityPost
Authorization: Bearer <token>
Content-Type: application/json

{
  "title": "How do you manage brain fog?",
  "content": "I've been struggling with foggy mornings...",
  "category": "mood",
  "display_name": "Anonymous",
  "status": "active",
  "flagged": false
}
```

**Categories:** `general`, `sleep`, `mood`, `nutrition`, `movement`, `stress`, `chronic_conditions`, `treatments`, `other`

**Anonymity:** `display_name` is what other users see. It does NOT link to the user's account. Default to "Anonymous" — let the user customize it (max 50 chars).

#### Get Replies for a Post
```
GET https://vidalab.base44.app/api/entities/CommunityReply?filter={"post_id":"<post_id>"}&sort=created_date&limit=200
Authorization: Bearer <token>
```

#### Create Reply
```
POST https://vidalab.base44.app/api/entities/CommunityReply
Authorization: Bearer <token>
Content-Type: application/json

{
  "post_id": "<post_id>",
  "content": "I've found that morning sunlight helps me...",
  "display_name": "Anonymous",
  "status": "active",
  "flagged": false
}
```

#### Flag a Post or Reply (report to moderators)
```
POST https://vidalab.base44.app/api/functions/flag-community-content
Authorization: Bearer <token>
Content-Type: application/json

{ "type": "post", "id": "<post_id>" }
```

> Use `"type": "reply"` for replies. Any authenticated user can flag. Flagged content stays visible until an admin hides it.

#### Admin Moderation (admin users only)

Hide a post:
```
PATCH https://vidalab.base44.app/api/entities/CommunityPost/<post_id>
Authorization: Bearer <token>
Content-Type: application/json

{ "status": "hidden" }
```

Delete a post:
```
DELETE https://vidalab.base44.app/api/entities/CommunityPost/<post_id>
Authorization: Bearer <token>
```

Same pattern for replies using `CommunityReply` entity.

### Swift Models

```swift
struct CommunityPost: Codable, Identifiable {
    let id: String
    let title: String
    let content: String
    let category: String
    let display_name: String?
    let status: String?
    let flagged: Bool?
    let created_date: String?
    let created_by_id: String?
}

struct CommunityReply: Codable, Identifiable {
    let id: String
    let post_id: String
    let content: String
    let display_name: String?
    let status: String?
    let flagged: Bool?
    let created_date: String?
}

struct CommunityCategory: Identifiable {
    let id: String  // "general", "sleep", etc.
    let label: String  // "General", "Sleep", etc.
}

let communityCategories: [CommunityCategory] = [
    .init(id: "general", label: "General"),
    .init(id: "sleep", label: "Sleep"),
    .init(id: "mood", label: "Mood"),
    .init(id: "nutrition", label: "Nutrition"),
    .init(id: "movement", label: "Movement"),
    .init(id: "stress", label: "Stress"),
    .init(id: "chronic_conditions", label: "Chronic Conditions"),
    .init(id: "treatments", label: "Treatments"),
    .init(id: "other", label: "Other"),
]
```

### Screens to Build

1. **CommunityListView** — category filter bar, post list (cards with title, preview, author, time, reply count), "New Post" button
2. **NewPostView** — display name field (default "Anonymous"), title, category picker, content textarea, submit
3. **PostDetailView** — full post content, reply list, reply form, report button
4. **Admin moderation** — if `user.role == "admin"`, show Hide/Show/Delete buttons on posts and replies, plus a "Moderation Queue" filter for flagged content

### Important Notes

- **Medical disclaimer:** Show a banner at the top of the community screen: "This is a peer-to-peer space for sharing experiences and wellness tips — not medical advice. Always consult a qualified healthcare professional."
- **Anonymity:** Never display `created_by_id` or user email to other users. Only show `display_name`.
- **RLS is enforced server-side:** Regular users automatically only see active posts. You don't need to filter client-side, but you can filter `status == "active"` for safety.

---

## 15. Backend-Only Changes

These changes were made to the backend and require **no iOS UI updates**, but you should be aware of them:

### Security Fixes
- `send-reminders` and `send-appointment-reminders` backend functions now require admin authentication. If your iOS app was calling these directly, it will now get a 403. These are scheduled functions — they run automatically and should not be called from the app.
- A hardcoded Supabase anonymous key was removed from a config comment. No iOS impact.

### Newsletter Unsubscribe Tokens
- The unsubscribe flow now requires a token for security. This is a web-only page (`/unsubscribe`) — no iOS impact.

---

## Summary Checklist

| Feature | New iOS Screen? | New API Calls? | Notes |
|---------|----------------|----------------|-------|
| Onboarding (gender + concerns) | ✅ Yes | `PATCH /api/auth/me` | Show after registration if `gender` is null |
| Conditional cycle tracking | ❌ No (form change) | None | Hide cycle picker when `gender != "female"` |
| Sleep & Mood chart | ✅ Yes | `GET /api/entities/DailyCheckin` | Dual-axis chart, 30 days |
| Community | ✅ Yes (3 screens) | `GET/POST CommunityPost`, `GET/POST CommunityReply`, `POST flag-community-content` | Anonymous, moderated |

---

| Question | Answer |
|----------|--------|
| Do I need the web app's repository? | **No.** Your iOS app talks to the Base44 API. |
| Do user accounts transfer? | **Yes.** Same auth system, same database. |
| Do favorites sync? | **Yes.** Same `Favorite` entity, automatic. |
| Do check-ins sync? | **Yes.** Same `DailyCheckin` entity, automatic. |
| Does membership sync? | **Yes.** Same user record, same `membership` field. |
| Do I need to build a separate backend? | **No.** Use the Base44 API + custom functions. |
| What do I need from Base44? | **Your App ID** (from the API page in your dashboard). |

---

*This is the complete iOS integration guide for the VIDA LAB app. All custom backend functions are already deployed. The web app remains unchanged — only additions were made, nothing was removed.*