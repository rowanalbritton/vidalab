# VIDA LAB — iOS App Sync & Feature Update Guide

> ## ⚠️ CRITICAL — READ BEFORE TOUCHING ANYTHING ⚠️
>
> **DO NOT change, redesign, restyle, or "clean up" ANY existing UI.**
> The app's visual design, layout, colors, fonts, navigation structure, and
> interface elements MUST stay exactly as they are in your recovered Xcode project.
>
> This guide is **ONLY** about:
> 1. **Adding new backend API calls** for features that were added to the web app
> 2. **Integrating account sync** so the same user account + Vida+ membership works on both platforms
> 3. **Wiring up new data fields** that the backend now returns
>
> If you are unsure whether a change is "design" or "functionality" — **it's design. Don't touch it.**
> Only add new buttons, new API calls, and new data fields to existing screens.
> Do NOT move, restyle, recolor, or restructure anything that already exists.

---

## What Changed Since Your Last Build

The backend was migrated from Base44's built-in database to **Supabase** (a PostgreSQL database).
The API endpoints are **exactly the same** — your existing Swift networking code still works.
What changed:

1. **Same API URLs** — `https://vidalab.base44.app/api/...` is unchanged
2. **Same auth flow** — login, register, OTP, token storage all work identically
3. **Same entities** — DailyCheckin, Favorite, Experiment, etc. all still exist
4. **New backend functions** — Google integrations, monthly reports, practice correlations
5. **New user fields** — `reminder_time`, `reminder_timezone`, `last_rewind_date`, `email`
6. **Vida+ membership sync** — purchases on web instantly unlock features in app, and vice versa

---

## Table of Contents

1. [Account Sync (Same User, Both Platforms)](#1-account-sync)
2. [Vida+ Membership Sync](#2-vida-membership-sync)
3. [New User Fields to Read](#3-new-user-fields)
4. [Google Integration Features (New)](#4-google-integrations)
5. [Monthly Report Export (New)](#5-monthly-report)
6. [Health Data CSV Export (New)](#6-csv-export)
7. [Practice Correlation Dashboard (New)](#7-practice-correlation)
8. [Vida Rewind — Monthly Review (New)](#8-vida-rewind)
9. [Reminder Settings (New Fields)](#9-reminder-settings)
10. [Updated Endpoint Reference](#10-endpoint-reference)

---

## 1. Account Sync

**The most important thing: the same user account works on both web and iOS.**

### How It Works
- User registers on the website → same account works in the iOS app (same email + password)
- User registers in the iOS app → same account works on the website
- User logs in on web → their token works on iOS too (same auth system)
- User logs in on iOS → their token works on web too
- **No duplicate accounts. No separate sign-up. One account, both platforms.**

### What You Need to Do
- **Nothing new.** Your existing login/register/OTP flow already works.
- The backend auth API (`/api/auth/login`, `/api/auth/register`, `/api/auth/verify-otp`) is unchanged.
- The `User` model returned by `/api/auth/me` now includes new fields (see Section 3).

### Data That Automatically Syncs
| Data | How It Syncs |
|------|-------------|
| Daily check-ins | Same `DailyCheckin` entity — write on web, read on app, and vice versa |
| Favorites | Same `Favorite` entity — heart a recipe on app, see it filled on web |
| Experiments | Same `Experiment` entity — create on web, track on app |
| Treatments | Same `Treatment` entity |
| Appointments | Same `Appointment` entity |
| Community posts/replies | Same `CommunityPost` / `CommunityReply` entities |
| Profile fields (gender, concerns) | Same user record — set on web, reflected on app |

**You do NOT need to build any sync mechanism. Both platforms read/write the same database.**

---

## 2. Vida+ Membership Sync

**Vida+ membership purchased on the web instantly unlocks features in the iOS app, and vice versa.**

### How It Works
1. User purchases Vida+ on the website → `payments-webhook` sets `membership: "vida_plus"` on their user record
2. User opens the iOS app → `GET /api/auth/me` returns `membership: "vida_plus"` → app unlocks premium features
3. User purchases Vida+ in the iOS app (if you build in-app purchase) → same webhook fires → same membership field set
4. User opens the website → `membership: "vida_plus"` → premium features unlocked

### What You Need to Do

#### Check Membership Status
Your `User` model already has a `membership` field. After login or on app launch, check:

```swift
// In your AuthVM or wherever you check user state
var isVidaPlus: Bool { user?.membership == "vida_plus" }
```

#### Gate Premium Features
For Vida+ features (Body Weather, Pattern Map, Vida Experiments results, etc.), check `isVidaPlus` before allowing access:

```swift
if !auth.isVidaPlus {
    // Show a message: "Vida+ membership required. Upgrade at vidalab.base44.app/vida-plus"
    // Do NOT build a full paywall UI — just a simple message is fine
    // The actual purchase happens on the website (or via in-app purchase if you add it)
}
```

#### Purchasing Vida+ from the App (Optional)
If you want to allow in-app Vida+ purchases, call the same checkout function the web uses:

```
POST https://vidalab.base44.app/api/functions/create-checkout
Authorization: Bearer <token>
Content-Type: application/json

{ "productId": "vida_plus_monthly" }
```

**Response:**
```json
{
  "redirectUrl": "https://checkout.wix.com/..."
}
```

Open `redirectUrl` in `SFSafariViewController` or the system browser. After payment, the webhook fires and sets `membership: "vida_plus"`. The user returns to the app and `GET /api/auth/me` will show the updated membership.

> **Note:** You can also just direct users to `https://vidalab.base44.app/vida-plus` in the browser to purchase, and the membership will sync automatically. This is simpler and requires no in-app purchase code.

---

## 3. New User Fields

The `User` object returned by `/api/auth/me` and the login response now includes these fields. **Add them to your `User` Swift struct — do NOT remove any existing fields.**

```swift
struct User: Codable {
    let id: String
    let email: String
    let full_name: String?
    let role: String
    let membership: String?          // "vida_plus" or nil
    let gender: String?             // "male" or "female" (set during onboarding)
    let health_concerns: [String]?   // e.g. ["sleep", "energy", "mood"]
    
    // NEW FIELDS — add these to your existing User struct:
    let reminder_enabled: Bool?        // default true — user wants check-in reminders
    let reminder_time: String?         // "20:00" — preferred reminder hour (24h format)
    let reminder_timezone: String?     // "America/New_York" — user's timezone
    let content_updates: Bool?         // default true — user wants new content emails
    let cycle_tracking_enabled: Bool?  // default true — show cycle phase in check-in
    let last_rewind_date: String?      // ISO date — last time user saw monthly rewind
    let last_reminder_date: String?    // ISO date — last time a reminder was sent
    
    var hasVidaPlus: Bool { membership == "vida_plus" }
}
```

> **Do NOT remove any existing fields.** Only add the new ones marked with `// NEW FIELDS`.

---

## 4. Google Integrations

The web app now supports Google integrations. These are **app-user connectors** — each user connects their own Google account. Your iOS app can trigger these same backend functions.

### How It Works on iOS
1. User taps "Export to Google Sheets" in the iOS app
2. iOS calls the backend function
3. If the user hasn't connected their Google account yet, the function returns a `connectUrl`
4. Open that URL in `SFSafariViewController` so the user can authorize
5. After authorization, the user returns to the app and taps the button again
6. The function runs and returns the result (e.g., a spreadsheet URL)

### Available Google Functions

#### Export Check-ins to Google Sheets
```
POST https://vidalab.base44.app/api/functions/export-to-google-sheets
Authorization: Bearer <token>
Content-Type: application/json

{}
```

**Response (success):**
```json
{ "ok": true, "url": "https://docs.google.com/spreadsheets/d/..." }
```

**Response (needs connection):**
```json
{ "ok": false, "needsConnect": true, "connectUrl": "https://vidalab.base44.app/..." }
```

#### Save Health Snapshot to Google Drive
```
POST https://vidalab.base44.app/api/functions/save-snapshot-to-drive
Authorization: Bearer <token>
Content-Type: application/json

{}
```

Same response pattern — `url` on success, `connectUrl` if needs auth.

#### Sync Favorited Practices to Google Tasks
```
POST https://vidalab.base44.app/api/functions/sync-practices-to-tasks
Authorization: Bearer <token>
Content-Type: application/json

{}
```

#### Sync Doctor List to Google Contacts
```
POST https://vidalab.base44.app/api/functions/sync-doctors-to-contacts
Authorization: Bearer <token>
Content-Type: application/json

{}
```

#### Add Appointment to Google Calendar
```
POST https://vidalab.base44.app/api/functions/add-google-calendar-event
Authorization: Bearer <token>
Content-Type: application/json

{ "appointmentId": "<appointment_id>" }
```

#### Sync Daily Check-in to Google Calendar
```
POST https://vidalab.base44.app/api/functions/sync-checkin-to-calendar
Authorization: Bearer <token>
Content-Type: application/json

{ "checkinId": "<checkin_id>" }
```

### Swift Helper for Google Functions

Add this to your `VidaAPIClient` — do NOT modify existing methods, just add new ones:

```swift
// MARK: - Google Integration Functions

struct GoogleFunctionResponse: Codable {
    let ok: Bool
    let url: String?           // result URL on success
    let needsConnect: Bool?    // true if user needs to authorize
    let connectUrl: String?    // URL to open for authorization
    let error: String?
}

func callGoogleFunction(_ functionName: String, body: [String: Any] = [:]) async throws -> GoogleFunctionResponse {
    return try await post("/functions/\(functionName)", body: body)
}

// Convenience methods
func exportToGoogleSheets() async throws -> GoogleFunctionResponse {
    try await callGoogleFunction("export-to-google-sheets")
}
func saveSnapshotToDrive() async throws -> GoogleFunctionResponse {
    try await callGoogleFunction("save-snapshot-to-drive")
}
func syncPracticesToTasks() async throws -> GoogleFunctionResponse {
    try await callGoogleFunction("sync-practices-to-tasks")
}
func syncDoctorsToContacts() async throws -> GoogleFunctionResponse {
    try await callGoogleFunction("sync-doctors-to-contacts")
}
func addAppointmentToCalendar(appointmentId: String) async throws -> GoogleFunctionResponse {
    try await callGoogleFunction("add-google-calendar-event", body: ["appointmentId": appointmentId])
}
func syncCheckinToCalendar(checkinId: String) async throws -> GoogleFunctionResponse {
    try await callGoogleFunction("sync-checkin-to-calendar", body: ["checkinId": checkinId])
}
```

### How to Handle the Connect Flow in SwiftUI

```swift
// Generic handler for any Google function button
func handleGoogleFunction(_ functionName: String) {
    Task {
        do {
            let result = try await VidaAPIClient.shared.callGoogleFunction(functionName)
            if result.needsConnect == true, let connectUrl = result.connectUrl {
                // Open the authorization URL in Safari
                await MainActor.run {
                    if let url = URL(string: connectUrl) {
                        UIApplication.shared.open(url)
                    }
                }
            } else if result.ok, let url = result.url {
                // Success — show the result URL or a success message
                await MainActor.run {
                    // Show success alert or open the URL
                }
            } else if let error = result.error {
                await MainActor.run { self.error = error }
            }
        } catch {
            await MainActor.run { self.error = "Something went wrong." }
        }
    }
}
```

### Where to Add Buttons (No New Screens)

Add these as simple buttons on **existing** screens — do NOT create new screens or change layouts:

| Button | Where to Add It | Function |
|--------|-----------------|----------|
| "Export to Sheets" | Daily Signals screen, near history | `export-to-google-sheets` |
| "Save to Drive" | Daily Signals screen, near history | `save-snapshot-to-drive` |
| "Sync to Tasks" | Apothecary screen, near favorites | `sync-practices-to-tasks` |
| "Sync Contacts" | Doctor Finder screen | `sync-doctors-to-contacts` |
| "Add to Calendar" | Appointment detail / booking | `add-google-calendar-event` |
| "Sync Check-in" | After saving a check-in | `sync-checkin-to-calendar` |

> **Keep buttons minimal.** A simple text button or small icon button is fine. Do NOT redesign the screen around these buttons.

---

## 5. Monthly Report

The web app can generate a monthly health report. The backend function is available to iOS too.

### API Call
```
POST https://vidalab.base44.app/api/functions/body-weather-forecast
Authorization: Bearer <token>
Content-Type: application/json

{}
```

This already exists in your app as `BodyWeatherView`. No changes needed — the function is the same.

### Monthly Report (Client-Side)
The monthly report is generated from check-in data on the client side. You can build a simple "Monthly Report" view that:

1. Fetches the last 30 check-ins: `GET /api/entities/DailyCheckin?sort=-checkin_date&limit=30`
2. Calculates averages (energy, sleep, mood) and practice frequency
3. Shows a summary

> This is optional — if you don't want to build it, users can access it on the web at `vidalab.base44.app/daily-signals`.

---

## 6. CSV Export

The web app has a "Export Health Data" button that downloads a CSV of all check-ins. You can replicate this on iOS:

### How to Do It
1. Fetch all check-ins: `GET /api/entities/DailyCheckin?sort=-checkin_date&limit=1000`
2. Convert to CSV in Swift
3. Use `UIActivityViewController` to let the user save or share the file

```swift
func exportCheckinsAsCSV(checkins: [CheckIn]) {
    var csv = "Date,Energy,Mood,Sleep Hours,Sleep Quality,Pain Level,Cycle Phase,Symptoms,Practices,Notes\n"
    for c in checkins {
        let row = [
            c.checkin_date,
            "\(c.energy)",
            c.mood,
            "\(c.sleep_hours ?? 0)",
            "\(c.sleep_quality ?? 0)",
            "\(c.pain_level ?? 0)",
            c.cycle_phase ?? "",
            (c.symptoms ?? []).joined(separator: ";"),
            (c.practices ?? []).joined(separator: ";"),
            (c.notes ?? "").replacingOccurrences(of: "\n", with: " ")
        ].map { "\"\($0)\"" }.joined(separator: ",")
        csv += row + "\n"
    }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("vida-health-\(Date().timeIntervalSince1970).csv")
    try? csv.data(using: .utf8)?.write(to: url)
    let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    // Present the activity controller
}
```

Add a simple "Export CSV" button on the Daily Signals screen. Do NOT create a new screen for this.

---

## 7. Practice Correlation

The web app shows how wellness practices (meditation, exercise, etc.) correlate with mood and energy. You can add this to your existing Daily Signals screen.

### How It Works
1. Fetch check-ins: `GET /api/entities/DailyCheckin?sort=-checkin_date&limit=60`
2. For each practice, compare average energy/mood on days the user did the practice vs. days they didn't
3. Show a simple list: "Meditation: +0.8 energy on days you practiced"

### Swift Implementation

```swift
struct PracticeCorrelation {
    let practice: String
    let energyDiff: Double    // average energy with practice minus without
    let moodDiff: Double      // average mood score with practice minus without
    let daysPracticed: Int
}

func calculateCorrelations(checkins: [CheckIn]) -> [PracticeCorrelation] {
    let practices = ["meditation", "gentle_exercise", "anti_inflammatory_meal", "supplement",
                     "breathing_exercise", "nature_time", "sleep_hygiene", "hydration",
                     "gratitude", "stretching"]
    
    return practices.compactMap { practice in
        let withPractice = checkins.filter { ($0.practices ?? []).contains(practice) }
        let withoutPractice = checkins.filter { !($0.practices ?? []).contains(practice) }
        guard !withPractice.isEmpty, !withoutPractice.isEmpty else { return nil }
        
        let avgEnergyWith = Double(withPractice.map { $0.energy }.reduce(0, +)) / Double(withPractice.count)
        let avgEnergyWithout = Double(withoutPractice.map { $0.energy }.reduce(0, +)) / Double(withoutPractice.count)
        
        let moodScore: (String) -> Double = { mood in
            switch mood {
            case "happy": return 5; case "calm", "motivated": return 4
            case "neutral": return 3; case "anxious", "irritable": return 2; case "sad": return 1
            default: return 3
            }
        }
        let avgMoodWith = withPractice.map { moodScore($0.mood) }.reduce(0, +) / Double(withPractice.count)
        let avgMoodWithout = withoutPractice.map { moodScore($0.mood) }.reduce(0, +) / Double(withoutPractice.count)
        
        return PracticeCorrelation(
            practice: practice,
            energyDiff: avgEnergyWith - avgEnergyWithout,
            moodDiff: avgMoodWith - avgMoodWithout,
            daysPracticed: withPractice.count
        )
    }
}
```

Show this as a simple list below the check-in history on Daily Signals. Do NOT create a new screen.

---

## 8. Vida Rewind

The web app shows a monthly "Vida Rewind" — a review of the past 30 days. This is a Vida+ feature.

### How It Works
1. After the user has 10+ check-ins in the last 30 days, the rewind becomes available
2. The user views it once per month
3. After viewing, `last_rewind_date` is set on their profile

### API Call to Mark as Seen
```
PATCH https://vidalab.base44.app/api/auth/me
Authorization: Bearer <token>
Content-Type: application/json

{ "last_rewind_date": "2026-09-22" }
```

### When to Show
- User has `hasVidaPlus == true`
- User has 10+ check-ins in the last 30 days
- `last_rewind_date` is not in the current month (compare `YYYY-MM` prefixes)

### What to Show
A simple summary of the last 30 days:
- Total check-ins
- Average energy
- Average sleep
- Most common mood
- Most frequent practices
- Most frequent symptoms

This is client-side computation from the check-in data you already fetch. Add it as a sheet or alert on the Daily Signals screen — do NOT create a new screen.

---

## 9. Reminder Settings

The web app lets users configure their check-in reminder time and timezone. The user profile now has these fields:

- `reminder_enabled` (Bool, default true)
- `reminder_time` (String, "HH:mm" 24h format, default "20:00")
- `reminder_timezone` (String, IANA timezone, default user's device timezone)
- `content_updates` (Bool, default true — new content emails)

### API Call to Update
```
PATCH https://vidalab.base44.app/api/auth/me
Authorization: Bearer <token>
Content-Type: application/json

{
  "reminder_enabled": true,
  "reminder_time": "20:00",
  "reminder_timezone": "America/New_York",
  "content_updates": true
}
```

### Where to Add
Add a simple "Reminder Settings" section to the existing Daily Signals screen or profile screen. A few toggles and a time picker — do NOT create a new screen.

```swift
// Example: simple reminder settings form section
Section("Reminders") {
    Toggle("Daily check-in reminder", isOn: $reminderEnabled)
    if reminderEnabled {
        DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
    }
    Toggle("New content updates", isOn: $contentUpdates)
}
.onChange(of: reminderEnabled) { _ in saveReminderSettings() }
.onChange(of: reminderTime) { _ in saveReminderSettings() }
.onChange(of: contentUpdates) { _ in saveReminderSettings() }
```

```swift
func saveReminderSettings() {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    let body: [String: Any] = [
        "reminder_enabled": reminderEnabled,
        "reminder_time": formatter.string(from: reminderTime),
        "reminder_timezone": TimeZone.current.identifier,
        "content_updates": contentUpdates
    ]
    Task { try? await VidaAPIClient.shared.patch("/auth/me", body: body) }
}
```

---

## 10. Endpoint Reference

### All Backend Functions (Existing + New)

| Function | Method | Auth | Purpose |
|----------|--------|------|---------|
| `mobile-dashboard` | POST | Yes | Get all dashboard data in one call |
| `mobile-checkin` | POST | Yes | Submit check-in + get insight |
| `mobile-favorite-toggle` | POST | Yes | Add or remove a favorite |
| `body-weather-forecast` | POST | Yes | AI health forecast (Vida+) |
| `experiment-results` | POST | Yes | AI experiment analysis (Vida+) |
| `appointment-concierge` | POST | Yes | AI appointment prep guide |
| `flag-community-content` | POST | Yes | Flag a post/reply for moderation |
| **`export-to-google-sheets`** | POST | Yes | **NEW** — Export check-ins to Google Sheets |
| **`save-snapshot-to-drive`** | POST | Yes | **NEW** — Save health snapshot to Google Drive |
| **`sync-practices-to-tasks`** | POST | Yes | **NEW** — Sync favorited practices to Google Tasks |
| **`sync-doctors-to-contacts`** | POST | Yes | **NEW** — Sync doctor list to Google Contacts |
| **`add-google-calendar-event`** | POST | Yes | **NEW** — Add appointment to Google Calendar |
| **`sync-checkin-to-calendar`** | POST | Yes | **NEW** — Sync check-in to Google Calendar |
| `create-checkout` | POST | Yes | Start Vida+ checkout (returns redirect URL) |
| `check-payment-status` | POST | Yes | Verify payment after checkout |
| `send-reminders` | POST | Admin | Scheduled — do NOT call from app |
| `send-appointment-reminders` | POST | Admin | Scheduled — do NOT call from app |

### Auth Endpoints (Unchanged)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/auth/login` | Login |
| POST | `/api/auth/register` | Register |
| POST | `/api/auth/verify-otp` | Verify OTP |
| POST | `/api/auth/resend-otp` | Resend OTP |
| POST | `/api/auth/reset-password-request` | Request reset |
| POST | `/api/auth/reset-password` | Reset password |
| GET | `/api/auth/me` | Get current user (now with new fields) |
| PATCH | `/api/auth/me` | Update user (reminder settings, gender, etc.) |
| POST | `/api/auth/logout` | Logout |

### Entity Endpoints (Unchanged)

Same as before: `GET/POST/PATCH/DELETE /api/entities/{EntityName}`

---

## Summary Checklist

| Feature | New Screen? | New API Calls? | Design Change? |
|---------|------------|----------------|----------------|
| Account sync | ❌ No | ❌ No (same auth) | ❌ **NO** |
| Vida+ membership sync | ❌ No | ✅ Check `membership` field | ❌ **NO** |
| Google Sheets export | ❌ No (button on existing screen) | ✅ `export-to-google-sheets` | ❌ **NO** |
| Google Drive snapshot | ❌ No (button on existing screen) | ✅ `save-snapshot-to-drive` | ❌ **NO** |
| Google Tasks sync | ❌ No (button on existing screen) | ✅ `sync-practices-to-tasks` | ❌ **NO** |
| Google Contacts sync | ❌ No (button on existing screen) | ✅ `sync-doctors-to-contacts` | ❌ **NO** |
| Google Calendar (appointment) | ❌ No (button on existing screen) | ✅ `add-google-calendar-event` | ❌ **NO** |
| Google Calendar (check-in) | ❌ No (button on existing screen) | ✅ `sync-checkin-to-calendar` | ❌ **NO** |
| CSV export | ❌ No (button on existing screen) | ❌ No (client-side) | ❌ **NO** |
| Practice correlation | ❌ No (section on existing screen) | ❌ No (client-side) | ❌ **NO** |
| Vida Rewind | ❌ No (sheet/alert on existing screen) | ✅ `PATCH /api/auth/me` | ❌ **NO** |
| Reminder settings | ❌ No (section on existing screen) | ✅ `PATCH /api/auth/me` | ❌ **NO** |
| New user fields | ❌ No | ❌ No (just read new fields) | ❌ **NO** |

---

## Final Reminders

1. **DO NOT change any design, layout, colors, fonts, or navigation.** Only add functionality.
2. **DO NOT remove any existing features.** Only add new ones.
3. **DO NOT create new screens.** Add buttons and sections to existing screens.
4. **DO NOT restructure existing code.** Add new methods to existing classes.
5. **The same user account works on web and app.** No separate sign-up needed.
6. **Vida+ membership syncs automatically.** Check `user.membership == "vida_plus"`.
7. **All data syncs automatically.** Same database, same entities.
8. **Google integrations require per-user authorization.** Handle the `connectUrl` flow.
9. **Reminder settings save via `PATCH /api/auth/me`.** No new endpoint needed.
10. **When in doubt, don't change it.** Add only what's in this guide.

---

*This guide covers all features added since the last iOS build. The backend is deployed and ready. Build the Swift additions and your app will be at full parity with the web app — with zero design changes.*