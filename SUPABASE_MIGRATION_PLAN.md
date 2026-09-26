# VIDA LAB — Base44 → Supabase Migration Plan

> **Status:** Planning document — review before any code changes.
> **Goal:** Move the entire application backend, auth, and data layer from Base44 to Supabase while keeping the app live and the iOS app functional.

---

## 1. Current State Assessment

### What's on Base44 today

| Layer | What exists | Count |
|-------|------------|-------|
| **Entities** | DailyCheckin, Favorite, Experiment, ExperimentLog, Treatment, Appointment, CommunityPost, CommunityReply, Doctor, HealthResource, DiseaseReport, Explainer, SubstackArticle, ResearchPaper, NewsletterSignup, Base44Purchase, User | 17 entities |
| **Backend functions** | mobile-checkin, mobile-dashboard, mobile-favorite-toggle, vida-chat-gate, vida-chat-send, appointment-concierge, body-weather-forecast, vida-differential, experiment-results, check-payment-status, create-checkout, payments-webhook, send-reminders, send-appointment-reminders, send-appointment-snapshot, send-weekly-newsletter, post-daily-instagram, newsletter-signup, unsubscribe, flag-community-content, add-google-calendar-event, instagram-insights | 22 functions |
| **Auth** | Email/password + OTP, Google OAuth, password reset — all via Base44 Auth SDK | 4 pages + context |
| **Agents** | Vida AI chat agent (base44/agents/vida.jsonc) with Explainer read access | 1 agent |
| **Workflows** | Scheduled: send-reminders, send-appointment-reminders, send-weekly-newsletter, post-daily-instagram | 4 workflows |
| **Integrations** | InvokeLLM, SendEmail, GenerateImage, TranscribeAudio, GenerateSpeech, GenerateVideo, UploadPublicFile, UploadPrivateFile, ExtractDataFromUploadedFile, CreateFileSignedUrl | 10 Core integrations |
| **Connectors** | HubSpot (oauth), Instagram Business, Mailchimp, Google Calendar (workspace) | 4 connectors |
| **Payments** | Wix/Base44 Payments — create-checkout + payments-webhook + Base44Purchase entity | Full checkout flow |
| **Realtime** | Entity subscriptions (e.g., DailyCheckin.subscribe) | Built into SDK |
| **Frontend SDK** | `base44.entities.*`, `base44.auth.*`, `base44.functions.*`, `base44.agents.*`, `base44.integrations.Core.*` | ~40+ files |

### What Supabase infrastructure already exists

| Component | Status | Notes |
|-----------|--------|-------|
| **Supabase project** | ✅ Provisioned | Secrets set: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY |
| **SQL schema** | ✅ Written (`supabase_schema.sql`) | Covers 15 tables + RLS + triggers — but **missing** CommunityPost, CommunityReply tables and several profile fields (see §3.1) |
| **Supabase client** | ✅ Initialized (`src/lib/supabaseClient.js`) | Using `@supabase/supabase-js` v2 |
| **Config file** | ⚠️ Placeholders (`src/lib/supabaseConfig.js`) | URL and anon key need real values |
| **Schema run** | ❓ Unknown | You need to confirm the SQL has been executed in your Supabase project |

### What does NOT exist on Supabase yet

- Auth pages (Login, Register, ForgotPassword, ResetPassword) rewritten for Supabase Auth
- AuthContext rewritten for Supabase sessions
- Supabase Edge Functions (replacements for all 22 backend functions)
- Frontend data layer (replacing all `base44.entities.*` calls with `supabase.from(*)` calls)
- LLM/email/image integration replacements (Supabase has no built-in equivalents)
- Agent system replacement (Supabase has no agent framework)
- Payment webhook handler as a Supabase Edge Function
- Scheduled task replacement (Supabase pg_cron or external scheduler)
- Realtime subscription replacement (Supabase Realtime)
- File storage (Supabase Storage buckets)
- iOS app API guide update (new endpoints, new auth token format)

---

## 2. Migration Strategy

### Principles

1. **App stays live on Base44** until each layer is ready to switch over — no big-bang cutover.
2. **Phased approach** — each phase is independently testable and deployable.
3. **Dual-write window** — during transition, write to both Base44 and Supabase so no data is lost.
4. **iOS app compatibility** — the iOS app uses raw REST calls; it will need updated endpoints and auth token format. Plan a coordinated release.
5. **No feature changes** — this is a platform migration, not a redesign. Every feature must work identically on Supabase.

### Phase Order

```
Phase 1: Database schema (fill gaps in existing SQL)
    ↓
Phase 2: Data access layer (Supabase client wrapper)
    ↓
Phase 3: Authentication (Supabase Auth)
    ↓
Phase 4: Backend functions → Supabase Edge Functions
    ↓
Phase 5: Frontend migration (swap all base44.* calls)
    ↓
Phase 6: Integrations (LLM, email, image, storage)
    ↓
Phase 7: Agent system (Vida AI chat)
    ↓
Phase 8: Payments (Wix webhook → Supabase Edge Function)
    ↓
Phase 9: Scheduled tasks (pg_cron / external scheduler)
    ↓
Phase 10: Realtime + file storage
    ↓
Phase 11: iOS app update
    ↓
Phase 12: Cutover + Base44 decommission
```

---

## 3. Phase Details

### Phase 1: Database Schema (fill gaps)

**Effort:** Small — mostly additions to the existing `supabase_schema.sql`.

#### 1.1 Missing tables

```sql
-- Community posts (missing from current schema)
CREATE TABLE IF NOT EXISTS community_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  title text NOT NULL,
  content text NOT NULL,
  category text CHECK (category IN ('general','sleep','mood','nutrition','movement','stress','chronic_conditions','treatments','other')) DEFAULT 'general',
  display_name text DEFAULT 'Anonymous',
  status text CHECK (status IN ('active','hidden')) DEFAULT 'active',
  flagged boolean DEFAULT false,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);
-- RLS: active posts visible to all; hidden admin-only; creator can create; admin can update/delete

-- Community replies (missing from current schema)
CREATE TABLE IF NOT EXISTS community_replies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  post_id uuid NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  content text NOT NULL,
  display_name text DEFAULT 'Anonymous',
  status text CHECK (status IN ('active','hidden')) DEFAULT 'active',
  flagged boolean DEFAULT false,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);
-- RLS: active replies visible to all; hidden admin-only; creator can create; admin can update/delete
```

#### 1.2 Missing profile fields

The Base44 User entity has custom fields that aren't in the `profiles` table yet:

```sql
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS gender text,                    -- 'male' | 'female'
  ADD COLUMN IF NOT EXISTS health_concerns text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS last_rewind_date date,
  ADD COLUMN IF NOT EXISTS reminder_enabled boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS reminder_time text DEFAULT '20:00',
  ADD COLUMN IF NOT EXISTS content_updates boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS cycle_tracking_enabled boolean DEFAULT true;
```

#### 1.3 Unsubscribe tokens

The `newsletter_signups` table needs an unsubscribe token column:

```sql
ALTER TABLE newsletter_signups
  ADD COLUMN IF NOT EXISTS unsubscribe_token text;
```

#### 1.4 Verify schema is applied

You need to run the updated SQL in your Supabase Dashboard → SQL Editor.

---

### Phase 2: Data Access Layer

**Effort:** Medium — create a wrapper module that mirrors the Base44 entity API shape.

**Why:** Instead of rewriting every page's data calls individually, create a thin wrapper that translates `base44.entities.X.list()` → `supabase.from('x').select()`. This lets us swap pages one at a time.

**New file:** `src/lib/supabaseEntities.js`

```javascript
// Wrapper that mirrors base44.entities.* API shape using Supabase client.
// Each Base44 entity maps to a Supabase table (snake_case).
//
// Example:
//   const items = await db.DailyCheckin.list('-checkin_date', 200)
// becomes:
//   const { data } = await supabase.from('daily_checkins').select('*').order('checkin_date', { ascending: false }).limit(200)

import { supabase } from './supabaseClient';

function mapEntity(name) {
  const tableMap = {
    DailyCheckin: 'daily_checkins',
    Favorite: 'favorites',
    Experiment: 'experiments',
    ExperimentLog: 'experiment_logs',
    Treatment: 'treatments',
    Appointment: 'appointments',
    CommunityPost: 'community_posts',
    CommunityReply: 'community_replies',
    Doctor: 'doctors',
    HealthResource: 'health_resources',
    DiseaseReport: 'disease_reports',
    Explainer: 'explainers',
    SubstackArticle: 'substack_articles',
    ResearchPaper: 'research_papers',
    NewsletterSignup: 'newsletter_signups',
    Base44Purchase: 'purchases',
  };
  return tableMap[name] || name.toLowerCase();
}

// Build a per-entity API object matching Base44's shape:
// .list(sort, limit), .filter(query, sort, limit), .get(id), .create(data),
// .bulkCreate(arr), .update(id, data), .delete(id), .subscribe(callback)
export const db = new Proxy({}, {
  get(_, entityName) {
    const table = mapEntity(entityName);
    return {
      async list(sort, limit) { /* translate sort + limit to supabase query */ },
      async filter(query, sort, limit) { /* translate filter object to supabase filters */ },
      async get(id) { /* select by id */ },
      async create(data) { /* insert + return */ },
      async bulkCreate(arr) { /* bulk insert */ },
      async update(id, data) { /* update by id */ },
      async delete(id) { /* delete by id */ },
      subscribe(callback) { /* supabase realtime channel */ },
    };
  }
});
```

**Key translation challenges:**
- Base44 sort format: `'-checkin_date'` (minus prefix = desc) → Supabase: `.order('checkin_date', { ascending: false })`
- Base44 filter format: `{ status: 'active' }` → Supabase: `.eq('status', 'active')`
- Base44 `$or` / `$gte` / `$set` operators → Supabase filter chains
- `created_by_id` (Base44 built-in) → `user_id` (Supabase, set by RLS)
- Realtime: `base44.entities.X.subscribe()` → `supabase.channel().on('postgres_changes')`

---

### Phase 3: Authentication

**Effort:** Large — rewrite 4 auth pages + AuthContext + ProtectedRoute.

#### 3.1 Files to change

| File | Current | New |
|------|---------|-----|
| `src/lib/AuthContext.jsx` | Uses `base44.auth.me()`, `base44.auth.logout()` | Use `supabase.auth.getSession()`, `supabase.auth.onAuthStateChange()`, `supabase.auth.signOut()` |
| `src/pages/Login.jsx` | `base44.auth.loginViaEmailPassword()` | `supabase.auth.signInWithPassword()` |
| `src/pages/Register.jsx` | `base44.auth.register()` + OTP flow | `supabase.auth.signUp()` — Supabase handles email verification natively (no manual OTP step) |
| `src/pages/ForgotPassword.jsx` | `base44.auth.resetPasswordRequest()` | `supabase.auth.resetPasswordEmail()` |
| `src/pages/ResetPassword.jsx` | `base44.auth.resetPassword()` | `supabase.auth.updateUser()` |
| `src/components/ProtectedRoute.jsx` | Reads from AuthContext | Same, but AuthContext now reads from Supabase |
| `src/components/GoogleIcon.jsx` | Used with `base44.auth.loginWithProvider('google')` | `supabase.auth.signInWithOAuth({ provider: 'google' })` |

#### 3.2 Key behavioral differences

| Behavior | Base44 | Supabase |
|----------|--------|---------|
| Registration | register → OTP → verifyOtp → token | signUp → email confirmation link → user clicks → logged in |
| Session | Token in URL/header | JWT in localStorage (auto-refreshed) |
| User data | `base44.auth.me()` returns full user + custom fields | `supabase.auth.getUser()` returns auth user; custom fields in `profiles` table (separate query or join) |
| Update user | `base44.auth.updateMe({ gender })` | `supabase.from('profiles').update({ gender }).eq('id', user.id)` |
| Google OAuth | `base44.auth.loginWithProvider('google')` | `supabase.auth.signInWithOAuth({ provider: 'google', redirectTo })` |

#### 3.3 OTP flow change

Base44 uses a 6-digit OTP after registration. Supabase uses an email confirmation link by default. You have two options:

- **Option A:** Switch to Supabase's native email link flow (simpler, but changes UX — no more 6-digit code entry).
- **Option B:** Enable Supabase's OTP via email template customization (Supabase supports 6-digit OTP if configured).

**Decision needed:** Which flow do you prefer?

#### 3.4 Profile data

Base44's `auth.me()` returns custom fields (gender, health_concerns, membership, etc.) on the user object. Supabase separates auth users from profile data. We need a helper:

```javascript
// Get current user + profile in one call
async function getCurrentUser() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;
  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .single();
  return { ...user, ...profile };
}
```

---

### Phase 4: Backend Functions → Supabase Edge Functions

**Effort:** Large — 22 functions to port.

#### 4.1 Supabase Edge Function basics

Supabase Edge Functions are Deno-based TypeScript functions deployed to Supabase's edge network. They replace Base44's `base44/functions/*/entry.ts`.

**Directory structure:**
```
supabase/functions/
  mobile-checkin/index.ts
  mobile-dashboard/index.ts
  ...
```

**Deploy:** `supabase functions deploy mobile-checkin`

**Invoke from frontend:** `await fetch('https://YOUR-PROJECT.supabase.co/functions/v1/mobile-checkin', { method: 'POST', headers: { Authorization: `Bearer ${session.access_token}` }, body: JSON.stringify(payload) })`

#### 4.2 Function-by-function migration map

| Base44 function | Supabase Edge Function | Key changes |
|----------------|----------------------|-------------|
| `mobile-checkin` | `mobile-checkin` | `createClientFromRequest` → `createClient(url, key, { global: { headers: { Authorization } } })`; `base44.entities.DailyCheckin.create()` → `supabase.from('daily_checkins').insert()` |
| `mobile-dashboard` | `mobile-dashboard` | Multiple entity queries → multiple Supabase queries; `hasVidaPlus` logic stays (queries `purchases` table) |
| `mobile-favorite-toggle` | `mobile-favorite-toggle` | Toggle logic on `favorites` table |
| `vida-chat-gate` | `vida-chat-gate` | Creates agent conversation — **see Phase 7** (no Supabase agent equivalent) |
| `vida-chat-send` | `vida-chat-send` | Relays message to agent — **see Phase 7** |
| `appointment-concierge` | `appointment-concierge` | `InvokeLLM` → direct OpenAI/Anthropic API call |
| `body-weather-forecast` | `body-weather-forecast` | Same LLM replacement |
| `vida-differential` | `vida-differential` | Same LLM replacement |
| `experiment-results` | `experiment-results` | Same LLM replacement |
| `check-payment-status` | `check-payment-status` | Wix API calls stay; writes to `purchases` table |
| `create-checkout` | `create-checkout` | Wix checkout creation stays; reads product config |
| `payments-webhook` | `payments-webhook` | JWT verification + `purchases` table update + `profiles.membership` update |
| `send-reminders` | `send-reminders` | `SendEmail` → Resend/SendGrid API; `SendPushNotification` → APNs directly |
| `send-appointment-reminders` | `send-appointment-reminders` | Same email + push replacement |
| `send-appointment-snapshot` | `send-appointment-snapshot` | Same email replacement |
| `send-weekly-newsletter` | `send-weekly-newsletter` | Same email replacement + Mailchimp sync |
| `post-daily-instagram` | `post-daily-instagram` | Instagram Graph API calls stay |
| `newsletter-signup` | `newsletter-signup` | `newsletter_signups` table + Mailchimp sync |
| `unsubscribe` | `unsubscribe` | Token verification + `newsletter_signups` update |
| `flag-community-content` | `flag-community-content` | `community_posts`/`community_replies` update |
| `add-google-calendar-event` | `add-google-calendar-event` | Google Calendar API calls stay; OAuth token from connector |
| `instagram-insights` | `instagram-insights` | Instagram Graph API calls stay |

#### 4.3 Shared modules

Base44 has `base44/shared/insights.ts` and `base44/shared/membership.ts`. These become Supabase Edge Function shared modules:

```
supabase/functions/_shared/
  insights.ts
  membership.ts
  cors.ts
```

#### 4.4 Auth in Edge Functions

```typescript
// Supabase Edge Function auth pattern
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_ANON_KEY')!,
  { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
);

const { data: { user } } = await supabase.auth.getUser();
if (!user) return new Response('Unauthorized', { status: 401 });

// For service-role operations (bypassing RLS):
const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);
```

---

### Phase 5: Frontend Migration

**Effort:** Large — ~40+ files use `base44.*` calls.

#### 5.1 Files using Base44 SDK

**Pages (data calls):**
- `DailySignals.jsx` — `base44.entities.DailyCheckin.*`
- `PatternMap.jsx` — `base44.entities.DailyCheckin.*`
- `Health.jsx` — `base44.entities.HealthResource.*`, `base44.entities.Favorite.*`
- `Community.jsx` — `base44.entities.CommunityPost.*`, `base44.entities.CommunityReply.*`, `base44.functions.invoke('flag-community-content')`
- `DoctorFinder.jsx` — `base44.entities.Doctor.*`, `base44.entities.Appointment.*`
- `DoctorPrep.jsx` — `base44.functions.invoke('appointment-concierge')`
- `VidaExperiments.jsx` — `base44.entities.Experiment.*`, `base44.entities.ExperimentLog.*`
- `VidaDifferential.jsx` — `base44.functions.invoke('vida-differential')`
- `BodyWeather.jsx` — `base44.functions.invoke('body-weather-forecast')`
- `Trends.jsx` — `base44.entities.DailyCheckin.*`
- `Welcome.jsx` — `base44.auth.updateMe()`, `base44.entities.DailyCheckin.create()`
- `Sasha.jsx` — `base44.functions.invoke('vida-chat-gate')`, `base44.functions.invoke('vida-chat-send')`, `base44.agents.*`
- `InstagramInsights.jsx` — `base44.functions.invoke('instagram-insights')`
- `Unsubscribe.jsx` — `base44.functions.invoke('unsubscribe')`
- `ThankYou.jsx` — `base44.functions.invoke('check-payment-status')`
- `GettingStarted.jsx` — navigation only
- `Library.jsx` / `DiseaseDetail.jsx` — `base44.entities.DiseaseReport.*`
- `Research.jsx` — `base44.entities.ResearchPaper.*`, `base44.entities.SubstackArticle.*`
- `Home.jsx` — newsletter form, `base44.functions.invoke('newsletter-signup')`

**Components (data calls):**
- `DailyCheckinForm.jsx` — `base44.entities.DailyCheckin.create()`
- `ReminderSettings.jsx` — `base44.auth.updateMe()`
- `MonthlyReportButton.jsx` — `base44.entities.DailyCheckin.*`
- `PracticeCorrelation.jsx` — reads checkins (passed as props, no direct calls)
- `TreatmentLog.jsx` — `base44.entities.Treatment.*`
- `doctors/BookingModal.jsx` — `base44.entities.Appointment.create()`
- `doctors/MyAppointments.jsx` — `base44.entities.Appointment.*`
- `doctors/GoogleCalendarSync.jsx` — `base44.functions.invoke('add-google-calendar-event')`
- `NewsletterForm.jsx` — `base44.functions.invoke('newsletter-signup')`
- `UpgradeButton.jsx` — `base44.functions.invoke('create-checkout')`
- `VidaPlusSection.jsx` — `base44.functions.invoke('create-checkout')`
- `health/HealthResourceCard.jsx` — favorite toggle
- `experiments/*` — `base44.entities.Experiment.*`, `base44.functions.invoke('experiment-results')`
- `vida-rewind/VidaRewind.jsx` — `base44.entities.DailyCheckin.*`

**Layout/Auth:**
- `AuthContext.jsx` — `base44.auth.*`, `base44.app.getPublicSettings()`
- `ProtectedRoute.jsx` — reads AuthContext
- `SiteHeader.jsx` — `base44.auth.logout()`, user display
- `SiteFooter.jsx` — static

#### 5.2 Migration approach

Use the Phase 2 wrapper (`supabaseEntities.js`) so most pages only change their import:

```javascript
// Before:
import { base44 } from '@/api/base44Client';
const items = await base44.entities.DailyCheckin.list('-checkin_date', 200);

// After:
import { db } from '@/lib/supabaseEntities';
const items = await db.DailyCheckin.list('-checkin_date', 200);
```

For function calls, create a similar wrapper:

```javascript
// src/lib/supabaseFunctions.js
export async function invokeFunction(name, payload) {
  const { data: { session } } = await supabase.auth.getSession();
  const res = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/${name}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${session?.access_token}`,
    },
    body: JSON.stringify(payload),
  });
  return { data: await res.json() };
}
```

---

### Phase 6: Integrations (LLM, Email, Image, Storage)

**Effort:** Medium — wire up external services.

Base44's Core integrations don't exist in Supabase. Each needs a replacement:

| Base44 Integration | Supabase Replacement | Setup needed |
|--------------------|---------------------|--------------|
| `InvokeLLM` | Direct API call to OpenAI / Anthropic / Google from Edge Function | Set `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` secret in Supabase |
| `SendEmail` | Resend (`resend.com`) or SendGrid from Edge Function | Set `RESEND_API_KEY` secret; verify sending domain |
| `GenerateImage` | OpenAI DALL-E or Stability AI from Edge Function | Uses same `OPENAI_API_KEY` |
| `TranscribeAudio` | OpenAI Whisper API from Edge Function | Uses same `OPENAI_API_KEY` |
| `GenerateSpeech` | OpenAI TTS or ElevenLabs from Edge Function | Set `ELEVENLABS_API_KEY` or use OpenAI |
| `GenerateVideo` | No direct equivalent — would need Veo/Runway API | Set `GOOGLE_VEO_API_KEY` (if available) |
| `UploadPublicFile` | Supabase Storage (public bucket) | Create `public-files` bucket |
| `UploadPrivateFile` | Supabase Storage (private bucket) | Create `private-files` bucket |
| `ExtractDataFromUploadedFile` | LLM with file input (Claude/Gemini) from Edge Function | Uses same LLM API key |
| `CreateFileSignedUrl` | Supabase Storage `createSignedUrl()` | Built into Supabase client |

**Secrets to set in Supabase:**
```
OPENAI_API_KEY (or ANTHROPIC_API_KEY)
RESEND_API_KEY
ELEVENLABS_API_KEY (optional, for TTS)
```

---

### Phase 7: Agent System (Vida AI Chat)

**Effort:** Medium — rebuild the agent as an Edge Function.

Base44's agent system (conversation creation, message streaming, tool calling) has no Supabase equivalent. We need to rebuild it:

#### 7.1 New tables

```sql
CREATE TABLE IF NOT EXISTS agent_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  agent_name text NOT NULL DEFAULT 'vida',
  messages jsonb DEFAULT '[]',
  metadata jsonb DEFAULT '{}',
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE agent_conversations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "conversations_owner" ON agent_conversations FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
```

#### 7.2 Edge Functions

- `vida-chat-gate` → verifies Vida+ + creates an `agent_conversations` row + returns it
- `vida-chat-send` → verifies Vida+ + appends user message + calls LLM API + appends assistant response + returns it

#### 7.3 Streaming

Base44 streams agent responses via realtime subscriptions. Supabase Edge Functions can stream via Server-Sent Events or return the full response. For simplicity, start with request/response (no streaming), then add SSE if needed.

#### 7.4 Tool access (Explainer entity)

The Vida agent reads from the `Explainer` entity. In the Edge Function, query the `explainers` table directly and include relevant content in the LLM prompt.

---

### Phase 8: Payments (Wix Webhook → Supabase)

**Effort:** Medium.

#### 8.1 What changes

- `payments-webhook` becomes a Supabase Edge Function at `https://YOUR-PROJECT.supabase.co/functions/v1/payments-webhook`
- The Wix webhook registration needs to point to this new URL
- The `Base44Purchase` entity → `purchases` table
- Membership grant: `profiles.membership = 'vida_plus'` instead of `User.membership`
- `create-checkout` becomes an Edge Function (same Wix API calls)
- `check-payment-status` becomes an Edge Function

#### 8.2 Webhook URL update

Re-register the Wix webhook to point to the Supabase Edge Function URL:
```
https://YOUR-PROJECT.supabase.co/functions/v1/payments-webhook
```

#### 8.3 JWT verification

The Wix webhook JWT verification (currently using `WIX_CHECKOUT_WEBHOOK_PUBLIC_KEY`) needs to work in the Edge Function environment. The public key stays in Supabase secrets.

---

### Phase 9: Scheduled Tasks

**Effort:** Medium.

Base44 workflows (scheduled triggers) become Supabase pg_cron jobs or external cron (GitHub Actions, Render Cron, etc.).

| Base44 workflow | Schedule | Supabase approach |
|----------------|----------|-------------------|
| `send-reminders` | Every 30 min | pg_cron calling an Edge Function via `net.http_post` |
| `send-appointment-reminders` | Daily 8 AM | pg_cron |
| `send-weekly-newsletter` | Weekly | pg_cron |
| `post-daily-instagram` | Daily | pg_cron |

**Supabase pg_cron setup:**
```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Schedule a function call every 30 minutes
SELECT cron.schedule(
  'send-reminders',
  '*/30 * * * *',
  $$SELECT net.http_post(
    url := 'https://YOUR-PROJECT.supabase.co/functions/v1/send-reminders',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || current_setting('app.service_role_key')),
    body := '{}'::jsonb
  )$$$
);
```

---

### Phase 10: Realtime + File Storage

**Effort:** Small.

#### 10.1 Realtime

Base44: `base44.entities.X.subscribe(callback)`
Supabase:
```javascript
const channel = supabase
  .channel('daily_checkins_changes')
  .on('postgres_changes', { event: '*', schema: 'public', table: 'daily_checkins', filter: `user_id=eq.${userId}` }, callback)
  .subscribe();
// Cleanup: supabase.removeChannel(channel);
```

Only a few components use realtime subscriptions (community posts/replies, possibly check-ins). Most pages use regular fetch on mount.

#### 10.2 File storage

- Public files (images, generated content) → Supabase Storage public bucket
- Private files (health snapshots, reports) → Supabase Storage private bucket with signed URLs
- Upload: `supabase.storage.from('bucket').upload(path, file)`
- Signed URL: `supabase.storage.from('bucket').createSignedUrl(path, 60)`

---

### Phase 11: iOS App Update

**Effort:** Medium — update the iOS guide + iOS app code.

The iOS app currently calls:
- `POST /api/auth/login` → becomes Supabase Auth (`POST /auth/v1/token`)
- `POST /api/functions/mobile-*` → becomes `POST /functions/v1/mobile-*` (Supabase Edge Functions)
- `GET /api/entities/*` → becomes `GET /rest/v1/*` (Supabase REST API)
- Auth token format changes (Base44 token → Supabase JWT)

**Update `src/IOS_COMPLETE_GUIDE.md`** with new endpoints, new auth flow, and new token format.

---

### Phase 12: Cutover + Decommission

**Effort:** Small — but critical.

1. **Dual-write window** (Phases 5-11): During migration, write to both Base44 and Supabase so no data is lost.
2. **Data migration**: Export Base44 entity data → import into Supabase tables (one-time script).
3. **Final cutover**: Switch frontend to Supabase-only, remove Base44 SDK, remove Base44 functions.
4. **Decommission**: Unpublish Base44 app, remove Base44 secrets.

---

## 4. Decisions Needed Before We Start

| # | Decision | Options | Impact |
|---|----------|---------|--------|
| 1 | **OTP vs email link** | A: Supabase native email link (simpler) / B: Configure Supabase for 6-digit OTP (matches current UX) | Changes Register.jsx flow |
| 2 | **LLM provider** | OpenAI / Anthropic / Google Gemini | Determines which API key to set; affects cost and quality |
| 3 | **Email provider** | Resend / SendGrid / Postmark | Determines which API key to set; affects deliverability |
| 4 | **Streaming chat** | A: Request/response (simpler, no streaming) / B: Server-Sent Events (matches current streaming UX) | Affects vida-chat-send complexity |
| 5 | **Scheduled tasks** | A: Supabase pg_cron / B: External cron (GitHub Actions, Render) | pg_cron is simpler but requires pg_net extension |
| 6 | **Dual-write or big-bang** | A: Dual-write during migration (safer, more work) / B: Big-bang cutover (riskier, less work) | Affects data safety during transition |
| 7 | **iOS app timing** | A: Update iOS app simultaneously / B: Keep iOS on Base44 until web is fully migrated | Affects whether we need backward-compatible endpoints |

---

## 5. Risk Summary

| Risk | Mitigation |
|------|------------|
| Data loss during migration | Dual-write window + data export/import script |
| iOS app breaks | Keep Base44 endpoints live until iOS is updated; coordinate release |
| Payment webhook fails | Test Wix webhook with new Supabase URL before cutover |
| LLM costs change | OpenAI/Anthropic pricing differs from Base44 credits — estimate before switch |
| Email deliverability | Verify sending domain with Resend/SendGrid before cutover |
| Realtime behavior differs | Supabase Realtime has different semantics — test community + check-in subscriptions |
| RLS misconfiguration | Test every entity's RLS policies with both user and admin tokens before cutover |

---

## 6. Estimated Effort by Phase

| Phase | Effort | Turns (approx) |
|-------|--------|----------------|
| 1. Database schema | Small | 1-2 |
| 2. Data access layer | Medium | 2-3 |
| 3. Authentication | Large | 3-4 |
| 4. Backend functions | Large | 5-8 |
| 5. Frontend migration | Large | 4-6 |
| 6. Integrations | Medium | 2-3 |
| 7. Agent system | Medium | 2-3 |
| 8. Payments | Medium | 2-3 |
| 9. Scheduled tasks | Medium | 1-2 |
| 10. Realtime + storage | Small | 1-2 |
| 11. iOS app update | Medium | 1-2 |
| 12. Cutover | Small | 1-2 |
| **Total** | | **~25-40 turns** |

---

## 7. Recommended Starting Point

Once you've reviewed this plan and answered the decisions in §4, I'll start with **Phase 1: Database schema** — updating the SQL file with the missing tables and columns, then you run it in your Supabase dashboard.

Before starting, please answer:
1. Which LLM provider do you want? (OpenAI / Anthropic / Google Gemini)
2. Which email provider? (Resend / SendGrid / Postmark)
3. OTP or email link for registration?
4. Dual-write or big-bang cutover?
5. Is the existing `supabase_schema.sql` already run in your Supabase project, or do we need to run it fresh?

---

*This is a planning document. No code has been changed yet. Review and let me know how you'd like to proceed.*