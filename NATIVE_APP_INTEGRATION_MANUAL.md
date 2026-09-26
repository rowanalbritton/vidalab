# VIDA LAB — Native iOS App Integration Manual

> ## ⚠️ CRITICAL REMINDER — READ FIRST ⚠️
>
> **DO NOT remove, replace, or "clean up" ANY existing feature in the app.**
> Every feature currently in the VIDA LAB app — both web and native — must remain intact.
> This manual is about **ADDING** the website's features to the native app, not replacing them.
> If you are unsure whether something should stay, **it stays.**
>
> The web app and the native iOS app share the **same codebase and the same database.**
> They are already synonymous. This manual ensures all features are included in the
> native build and explains how to publish with push notifications enabled.

---

## Table of Contents

1. [How Base44 Native Publishing Works](#1-how-base44-native-publishing-works)
2. [Complete Feature Inventory](#2-complete-feature-inventory)
3. [Data Sync Between Web and App](#3-data-sync-between-web-and-app)
4. [Publishing the Native iOS App](#4-publishing-the-native-ios-app)
5. [Setting Up Push Notifications](#5-setting-up-push-notifications)
6. [Verifying Feature Parity](#6-verifying-feature-parity)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. How Base44 Native Publishing Works

**You do NOT need to rewrite anything in Xcode or Swift.**

Base44 apps are built in React + JavaScript. When you publish, Base44 compiles the **exact same code** into:
- A web app (live at `vidalab.base44.app`)
- A native iOS app (IPA bundle for App Store Connect)
- A native Android app (AAB bundle for Google Play)

This means:
- ✅ Every feature you build in the web app **automatically appears** in the native app
- ✅ Every page, component, chart, filter, and form is shared
- ✅ The database is shared — data written on the web is instantly visible in the app, and vice versa
- ✅ You do NOT open Xcode to build features. You build in Base44, then publish.

**What you DO use Xcode / App Store Connect for:**
- Uploading the generated IPA to App Store Connect
- Managing app listing metadata, screenshots, and submission
- Configuring push notification credentials (APNs key)

---

## 2. Complete Feature Inventory

The following is the full list of features that MUST be present in the native app.
All of these are already coded in the shared React codebase — publishing includes them automatically.

### Public Pages (no login required)
| Feature | Route | Description |
|--------|-------|-------------|
| Home | `/` | Landing page with research, wellness check-in, articles, newsletter |
| About | `/about` | Mission, founder bio, editorial standards |
| App Landing | `/app` | App promotion and membership info |
| Research | `/research` | Research papers and AP program info |
| Condition Detail | `/conditions/:slug` | Individual condition/condition report |
| Support | `/support` | Support and contact info |
| Rowan's Work | `/rowans-work` | Research papers showcase |
| Sasha | `/sasha` | AI health companion info |
| Library | `/library` | Chronic condition library with search and filters |
| Disease Detail | `/library/:slug` | Individual disease report with full content |
| **The Vida Apothecary** | `/health` | Recipes, remedies, exercises, meditations, supplements, habits — with category, subcategory, focus, and favorites filters |
| Privacy | `/privacy` | Privacy policy |
| Terms | `/terms` | Terms of service |
| Unsubscribe | `/unsubscribe` | Email unsubscribe page |
| Thank You | `/ThankYou` | Payment confirmation page |
| Getting Started | `/getting-started` | Onboarding guide |

### Member Pages (login required)
| Feature | Route | Description |
|--------|-------|-------------|
| Daily Signals | `/daily-signals` | Daily check-in form, history, mood/energy charts, **practice correlation dashboard**, reminder settings |
| Pattern Map | `/pattern-map` | Vida+ correlation analysis of check-ins (cycle, symptoms, mood, energy, sleep) |
| Doctor Prep | `/doctor-prep` | Printable health snapshot for appointments, treatment log, appointment concierge |
| Instagram Insights | `/instagram-insights` | Instagram analytics dashboard |
| Trends | `/trends` | Long-term trend analysis |
| Welcome | `/welcome` | Vida+ onboarding flow |
| Body Weather | `/body-weather` | AI health forecast |
| **Vida Differential** | `/vida-differential` | AI-powered differential diagnosis tool |
| Vida Experiments | `/vida-experiments` | N=1 experiment tracking with daily adherence logs |
| Doctor Finder | `/doctor-finder` | Doctor directory with map view and appointment booking |

### Authentication Pages
| Feature | Route |
|--------|-------|
| Login | `/login` |
| Register | `/register` |
| Forgot Password | `/forgot-password` |
| Reset Password | `/reset-password` |

### Backend Functions (shared between web and app)
| Function | Purpose |
|----------|---------|
| `create-checkout` | Stripe/Wix payment checkout for Vida+ membership |
| `payments-webhook` | Processes payment webhooks, grants Vida+ access |
| `check-payment-status` | Verifies payment status after checkout |
| `send-reminders` | **Evening check-in reminders** (email + push notification) — skips users who already checked in |
| `send-appointment-reminders` | 24-hour appointment email reminders |
| `send-appointment-snapshot` | Emails health snapshot to doctor's practice |
| `send-weekly-newsletter` | Weekly newsletter email |
| `newsletter-signup` | Newsletter signup processing |
| `unsubscribe` | Email unsubscribe processing |
| `appointment-concierge` | AI-generated appointment preparation guide |
| `body-weather-forecast` | AI health forecast generation |
| `vida-differential` | AI differential diagnosis analysis |
| `experiment-results` | AI experiment results analysis |
| `instagram-insights` | Instagram analytics data fetching |
| `post-daily-instagram` | Automated daily Instagram posting |
| `add-google-calendar-event` | Google Calendar appointment sync |

### Database Entities (shared between web and app)
| Entity | Purpose | Access |
|--------|---------|--------|
| DailyCheckin | Daily health check-ins (energy, mood, sleep, pain, symptoms, **practices**) | Per-user (RLS) |
| Favorite | Saved Apothecary resources | Per-user (RLS) |
| Experiment | N=1 experiments | Per-user (RLS) |
| ExperimentLog | Daily experiment adherence logs | Per-user (RLS) |
| Treatment | Medication/supplement history | Per-user (RLS) |
| Appointment | Doctor appointments | Per-user (RLS) |
| Doctor | Doctor directory | Public read, admin write |
| HealthResource | Apothecary library items (102+ items) | Public read, admin write |
| DiseaseReport | Chronic condition reports | Public read, admin write |
| Explainer | Educational explainers | Public read, admin write |
| SubstackArticle | Substack article links | Public read, admin write |
| ResearchPaper | AP Research papers | Public read, admin write |
| NewsletterSignup | Email newsletter signups | Admin only |
| Base44Purchase | Payment records | Per-user + admin |
| User | User accounts | Built-in |

### Automated Workflows
| Workflow | Schedule | Purpose |
|----------|----------|---------|
| `send-reminders` | Every 30 min (checks user's preferred hour, default 8 PM) | Evening check-in reminder email + push notification |
| `send-appointment-reminders` | Scheduled | 24-hour appointment reminders |
| `post-daily-instagram` | 8 AM ET daily | Automated Instagram post |

---

## 3. Data Sync Between Web and App

**This is the most important thing to understand: web and app share the same database.**

### How It Works
- Both the website (`vidalab.base44.app`) and the native iOS app connect to the **same Base44 backend**
- All data is stored in the same cloud database
- When a user logs in, their session token works on both web and app
- Any action on the web is instantly visible in the app, and vice versa

### Specific Sync Scenarios

#### ✅ Favorites
- User taps the heart on a recipe in the web app → a `Favorite` record is created in the database
- User opens the iOS app → the app loads the same `Favorite` records → the heart shows as filled
- User removes a favorite on the app → the `Favorite` record is deleted → it disappears from the web too
- **No extra code needed.** Both platforms read and write the same `Favorite` entity.

#### ✅ Daily Check-ins
- User completes a check-in on the web → a `DailyCheckin` record is created
- User opens the app → the app loads the same `DailyCheckin` records → history, charts, and practice correlations all show the same data
- User does a check-in on the app → it appears on the web history immediately
- **No extra code needed.** Both platforms read and write the same `DailyCheckin` entity.

#### ✅ Experiments, Treatments, Appointments
- All per-user data follows the same pattern — one shared database, automatic sync

#### ✅ Practice Correlation Dashboard
- The mood/pain trend chart and habit correlation cards on Daily Signals read from `DailyCheckin` records
- These records include the `practices` field (meditation, gentle exercise, anti-inflammatory meal, etc.)
- The same charts render identically on web and app because they use the same data

### What You Do NOT Need to Build
- ❌ A separate API for the app
- ❌ A separate database for the app
- ❌ A sync mechanism between web and app
- ❌ Duplicate versions of any feature

**Everything is already connected. Publishing the native app includes all features and all data sync automatically.**

---

## 4. Publishing the Native iOS App

### Prerequisites
- [ ] Apple Developer Program account (active)
- [ ] App Store Connect access
- [ ] Apple API keys (Issuer ID, Key ID, Team ID, .p8 file)
- [ ] Published Base44 web app (✅ already done at `vidalab.base44.app`)

### Step-by-Step

1. **Open your Base44 app editor**
   - Go to your Base44 workspace
   - Open the VIDA LAB app

2. **Navigate to Publish → Mobile app**
   - In the left sidebar of the app editor, find "Publish"
   - Click "Mobile app"

3. **Generate App Store files**
   - Click "Build Stores Files → Create App Store files"
   - Enter your App Store Connect credentials:
     - **Issuer ID** — from App Store Connect → Users and Access → Keys
     - **Key ID** — the 10-character key ID
     - **Team ID** — your Apple Developer Team ID
     - **.p8 API key file** — download this from App Store Connect when you create the key
   - Review your app logo (this becomes the app icon)
   - Click "Generate Files"

4. **Download the IPA bundle**
   - When generation completes, click "Download"
   - This downloads an `.ipa` file — the iOS app bundle
   - This IPA contains ALL features from the web app

5. **Upload to App Store Connect**
   - Go to [App Store Connect](https://appstoreconnect.apple.com)
   - Create a new app (or update an existing one)
   - Upload the IPA using:
     - **Transporter app** (free from Mac App Store), OR
     - **Xcode Organizer** (Window → Organizer → Distribute App), OR
     - **`xcrun altool`** command line
   - Base44 does NOT submit the app for you — you complete the listing and submit

6. **Complete the App Store listing**
   - Add app description, keywords, screenshots
   - Set up pricing (free app with in-app purchases for Vida+)
   - Submit for Apple review

7. **After approval**
   - The app goes live on the App Store
   - All features are included automatically
   - Data syncs with the website immediately

---

## 5. Setting Up Push Notifications

Push notifications (lock-screen reminders) require an APNs (Apple Push Notifications service) auth key.

### Step 1: Create an APNs Auth Key

1. Go to your [Apple Developer Account](https://developer.apple.com)
2. Navigate to **Certificates, Identifiers & Profiles → Keys**
3. Click the **+** button to create a new key
4. Name it (e.g., "VIDA LAB APNs Key")
5. Check the box for **Apple Push Notifications service (APNs)**
6. Click **Continue**, then **Register**
7. **Download the `.p8` file** — ⚠️ you can only download this once. Save it securely.
8. Note the **10-character Key ID** (shown on the key details page)

### Step 2: Upload the APNs Key to Base44

1. In your Base44 app editor, go to **Publish → Mobile app**
2. Start the "Create App Store files" process
3. Turn ON **"Add push notifications"**
4. Under **"Upload the APNs auth key (.p8)"**, upload your `.p8` file
5. Confirm or enter the **APNs Key ID**
6. Continue and generate the files

### Step 3: How Push Notifications Work in the App

The `send-reminders` backend function already sends push notifications. Here's what happens:

1. Every 30 minutes, the function runs automatically
2. For each user with reminders enabled, it checks if it's their preferred hour (default 8 PM their timezone)
3. It checks if they've already completed a daily check-in today
4. If they haven't checked in, it sends:
   - An email reminder
   - A **push notification** to their device:
     - **Title:** "Your daily check-in is waiting"
     - **Content:** "Two minutes to log your energy, mood, and symptoms. Your patterns build one check-in at a time."
     - **Action button:** "Check in now" → opens the Daily Signals page
5. The push notification appears on the user's lock screen like any Apple notification

### Step 4: Test Push Notifications

1. Install the updated app on a physical device (push notifications do NOT work in the simulator)
2. Log in with a user account that has reminders enabled
3. Wait until the preferred reminder time, OR temporarily change the user's `reminder_time` to the current hour
4. Verify the notification appears on the lock screen

### Push Notification Requirements
- ✅ Native iOS app installed on a physical device (not simulator)
- ✅ APNs key uploaded to Base44
- ✅ User must have `reminder_enabled` set to true (set in Reminder Settings on Daily Signals page)
- ✅ User must not have already completed a check-in for that day

---

## 6. Verifying Feature Parity

After publishing, verify that ALL features work in the native app. Use this checklist:

### Public Features
- [ ] Home page loads with all sections
- [ ] About page shows founder bio and editorial standards
- [ ] Research page shows papers
- [ ] Library page shows condition reports with search and filters
- [ ] The Vida Apothecary loads with 102+ resources
- [ ] Apothecary filters work (category, subcategory, focus groups, favorites)
- [ ] Apothecary heart/favorite button works
- [ ] Newsletter signup works
- [ ] All legal pages load (privacy, terms)

### Member Features (log in to test)
- [ ] Login and registration work
- [ ] Daily check-in form saves and shows insight
- [ ] Daily check-in includes "Today's practices" selection
- [ ] Mood & Pain Trends chart renders
- [ ] Practice Correlation cards show habit vs. mood/pain comparisons
- [ ] Pattern Map shows correlations
- [ ] Doctor Prep generates printable snapshot
- [ ] Vida Differential runs AI analysis
- [ ] Vida Experiments create and track experiments
- [ ] Doctor Finder shows directory and map
- [ ] Appointment booking works
- [ ] Treatment log works
- [ ] Body Weather forecast generates
- [ ] Reminder settings save

### Data Sync Verification
- [ ] Favorite an item on web → it appears favorited in app
- [ ] Favorite an item in app → it appears favorited on web
- [ ] Complete a check-in on web → it appears in app history
- [ ] Complete a check-in in app → it appears on web history
- [ ] Vida+ membership purchased on web → app recognizes it
- [ ] Vida+ membership purchased in app → web recognizes it

### Push Notifications
- [ ] Push notification appears on lock screen at preferred time
- [ ] Tapping "Check in now" opens Daily Signals
- [ ] No push sent if user already checked in that day

---

## 7. Troubleshooting

### "My feature isn't showing in the app"
- All features are in the shared codebase. If it works on the web, it works in the app.
- Make sure you generated NEW App Store files after the latest changes (re-publish).
- Old app installs won't have new features until updated.

### "Push notifications aren't arriving"
- Must test on a **physical device** (simulator doesn't support push)
- Verify the APNs `.p8` key was uploaded during file generation
- Verify the user has `reminder_enabled` set to true
- Check that the user hasn't already checked in today (the function skips them)
- Check backend function logs in Base44 → Logs

### "Favorites don't sync between web and app"
- They share the same database. If they don't sync:
  - Verify the user is logged into the same account on both
  - Check that the `Favorite` entity RLS is set to `created_by_id: {{user.id}}`
  - Check network connectivity

### "Data from the web doesn't show in the app"
- Both use the same Base44 backend. Verify:
  - Same user account is logged in
  - App has network access
  - No caching issues — try closing and reopening the app

### "I want to add a new feature to both web and app"
- Build it once in Base44 (React components, entities, backend functions)
- Re-publish the native app (generate new App Store files)
- The feature automatically appears in both web and app

---

## Summary

| Question | Answer |
|----------|--------|
| Do I need to rewrite features in Swift/Xcode? | **No.** Base44 compiles the same React code into a native IPA. |
| Are all website features in the native app? | **Yes.** Same codebase = same features. |
| Do favorites sync between web and app? | **Yes.** Same database. Automatic. |
| Do check-ins sync between web and app? | **Yes.** Same database. Automatic. |
| Do I need Xcode to build features? | **No.** Build in Base44. Use App Store Connect to upload the IPA. |
| How do push notifications work? | APNs key uploaded to Base44 → `send-reminders` function sends them. |
| Can I remove any existing features? | **NO. Everything stays. Only add.** |

---

*This manual was generated for the VIDA LAB app. All features described are already implemented in the shared Base44 codebase and will be included in the native iOS app when published.*