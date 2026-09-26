# VIDA LAB — iOS App Update Guide

> **Purpose:** This document covers every feature added to the web app **after** the initial iOS API integration guide was created. Follow these instructions to bring your Xcode app to feature parity with the current web app.
>
> **Architecture reminder:** Your iOS app talks to the same Base44 REST API (`https://vidalab.base44.app/api`). All new entities and backend functions are already deployed — you just need to build the native Swift screens that call them.

---

## Table of Contents

1. [Onboarding Flow (Gender + Health Concerns)](#1-onboarding-flow)
2. [Conditional Cycle Tracking in Check-in Form](#2-conditional-cycle-tracking)
3. [Sleep & Mood Chart](#3-sleep--mood-chart)
4. [Community Feature](#4-community-feature)
5. [Backend-Only Changes (No iOS UI Needed)](#5-backend-only-changes)

---

## 1. Onboarding Flow

After a new user registers and verifies their OTP, show a multi-step onboarding before landing on the dashboard. This personalizes their experience.

### Step 1: Gender Selection

Show two options: **Male** and **Female**. This field controls whether cycle tracking appears in the check-in form (see section 2).

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

Optionally let the user complete their first check-in right in the onboarding flow using the existing `mobile-checkin` function (see section 2 for the conditional cycle field).

### When to Show

- After successful OTP verification (new registrations only)
- After `GET /api/auth/me`, check if `user.gender` is null/missing — if so, show onboarding
- Existing users who already have a gender set skip this flow

---

## 2. Conditional Cycle Tracking

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

## 3. Sleep & Mood Chart

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

## 4. Community Feature

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

## 5. Backend-Only Changes

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

*This guide covers all features added after the initial `IOS_API_INTEGRATION_GUIDE.md` was created. The backend is deployed and ready — build the Swift screens and your app will be at full parity with the web app.*