# VIDA LAB — Base44 → Supabase Migration Plan

> **Status:** Planning document — revised with production infrastructure context.
> **Goal:** Move the web app's backend, auth, and data layer from Base44 to the **existing** Supabase project that the iOS app already runs on. Dual-write, verify, then decommission Base44.

---

## 1. Current State — CORRECTED

### 1.1 The Supabase project is already live (iOS app)

The iOS app is running against this Supabase project **right now**. This is not a greenfield setup.

**Production tables (created outside version control, already serving iOS):**
- `profiles` — user data (id, email, full_name, role, membership, created_date, updated_date)
- `check_ins` — daily check-ins, **E2E encrypted**, `user_id` as text
- `doctor_preps` — doctor prep notes, **E2E encrypted**, `user_id` as text
- `experiments` — experiments, **E2E encrypted**, `user_id` as text
- `saved_articles` — saved/favorited articles, **E2E encrypted**, `user_id` as text
- `entitlements` — Vida+ membership records (`user_id` text, `status`, `expires_at`)
- `entitlement_log` — entitlement audit trail

**Production schema objects:**
- `security` schema with `is_admin()` and `is_vida_plus()` functions (security definer)
- `is_vida_plus()` checks the `entitlements` table for an active membership — NOT `profiles.membership`

**Migration files in repo (RLS policies only — no table creation DDL):**
- `src/supabase_rls_existing.sql` — RLS for iOS tables + `security.is_vida_plus()`
- Two others (not located in repo — may be local or in Supabase dashboard)
- `20260920120000_add_sync_keys_escrow.sql` — **written but unverified** (Supabase MCP not authorized this session)

**The `supabase_schema.sql` file in the repo is NOT the production schema.** It describes a different set of tables (`daily_checkins`, `favorites`, `doctors`, etc.) with uuid `user_id`s and no encryption. It was never applied. **Do not run it** — it would conflict with or drop production data.

### 1.2 What's on Base44 (web app only)

| Layer | What exists |
|-------|------------|
| **Entities** | DailyCheckin, Favorite, Experiment, ExperimentLog, Treatment, Appointment, CommunityPost, CommunityReply, Doctor, HealthResource, DiseaseReport, Explainer, SubstackArticle, ResearchPaper, NewsletterSignup, Base44Purchase, User |
| **Backend functions** | 22 functions (mobile-*, vida-chat-*, appointment-*, body-weather-forecast, vida-differential, experiment-results, check-payment-status, create-checkout, payments-webhook, send-*, post-daily-instagram, newsletter-signup, unsubscribe, flag-community-content, add-google-calendar-event, instagram-insights) |
| **Auth** | Email/password + OTP, Google OAuth, password reset |
| **Agents** | Vida AI chat agent (general LLM) |
| **Workflows** | 4 scheduled workflows |
| **Payments** | Wix/Base44 Payments (RevenueCat was rejected — not in use) |

### 1.3 Entity → production table mapping

| Base44 entity | Production table | Notes |
|---------------|-----------------|-------|
| DailyCheckin | `check_ins` | **E2E encrypted on iOS** — web needs same encryption or separate table (see §3.2) |
| Experiment | `experiments` | **E2E encrypted** — same question |
| Favorite | `saved_articles` | **E2E encrypted** — check if structure matches |
| Treatment | ❌ Does not exist | Need additive migration |
| Appointment | ❌ Does not exist | Need additive migration |
| Doctor | ❌ Does not exist | Need additive migration |
| HealthResource | ❌ Does not exist | Need additive migration |
| DiseaseReport | ❌ Does not exist | Need additive migration |
| Explainer | ❌ Does not exist | Need additive migration |
| SubstackArticle | ❌ Does not exist | Need additive migration |
| ResearchPaper | ❌ Does not exist | Need additive migration |
| NewsletterSignup | ❌ Does not exist | Need additive migration |
| CommunityPost | ❌ Does not exist | Need additive migration |
| CommunityReply | ❌ Does not exist | Need additive migration |
| Base44Purchase | ❌ Does not exist | Need additive migration (or use `entitlements` for membership, separate `purchases` for payment records) |
| User | `profiles` | Already exists |
| (membership) | `entitlements` | Use this, NOT `profiles.membership` |

---

## 2. Decisions — RESOLVED

| # | Decision | Resolution |
|---|----------|-----------|
| 1 | **Registration flow** | ✅ Password auth primary. Drop 6-digit OTP (Base44's mechanism). Can offer magic link as secondary, but **every account needs a password** — iOS uses `auth.signUp(email:password:)` and a magic-link-only user can't sign in on iOS. |
| 2 | **LLM provider** | ✅ Anthropic — but **only for non-health tasks** (summarizing, support triage, content drafting). **NOT for symptom/health questions.** See §7. |
| 3 | **Email provider** | ✅ Resend |
| 4 | **Cutover style** | ✅ Dual-write. iOS is live against Supabase now — big-bang means a window where web writes somewhere iOS can't see, and encrypted tables make reconciliation painful. Dual-write, verify, then stop writing to Base44. |
| 5 | **Schema approach** | ✅ Additive migrations against the existing production project. Do NOT run a fresh schema. |
| 6 | **Payments** | ✅ Not using RevenueCat (rejected). Currently Wix/Base44 Payments. Migrate webhook to Supabase Edge Function. Use `entitlements` table for membership grant. |

### Resolved (round 2)

| # | Question | Resolution |
|---|----------|-----------|
| A | **E2E encryption on shared tables** | ✅ Shared tables are **not** encrypted and must not be. E2E encryption requires a key only the owner holds; a shared table needs other members to read it, so any key would have to be distributed to everyone — obfuscation, not encryption. **What protects shared tables is the schema, not cryptography.** The community board uses explicit column selection (`select("id,display_name,title,body,category,status,flagged,created_at")`) with a grant that omits `author_id`. A bare `select(*)` includes `author_id` and fails the grant. The client physically cannot deanonymize a post — the linkage exists only server-side for moderation. **The web app must mirror this exactly: never `select('*')` on community tables, keep `author_id` out of the anon grant.** Rule: anything a second person reads is plaintext behind RLS; anything only the owner reads is ciphertext. Don't bridge them. |
| B | **`sync_keys` migration** | ✅ Cannot verify from here (Supabase MCP not authorized this session). The app requires it — `VidaSyncService` hits `sync_keys` in four places. If missing, `wrappedKey()` silently returns nil and the app shows "Off" (silent failure by design — "it says Off" is not proof the table exists). **Action needed:** check `information_schema.tables` in the dashboard, or authorize MCP via `/mcp`. If missing, run the DDL in §3.1.5 below. |
| C | **Curated Q&A library** | ✅ Already exists — 17 entries in `Models/AskVidaLibrary.swift` (328 lines). Not generative. Each entry is a `VidaAnswer` struct: `id`, `question`, `shortAnswer`, `detail[]`, `articleID` (links to citation-bearing article), `trackSuggestion`, `keywords[]`, `relevance`. **Two properties the web app must preserve:** (1) No answer is offered without sources — suggested questions are filtered on `!article.citations.isEmpty` ("offering a question whose answer has no sources is a promise Vida can't keep"). (2) `relevance` suggests, never restricts — someone asking a question outright gets the best answer regardless of sex (matters for anyone reading about a partner or child). **The web app should read this same library, not build a second one** — two divergent sets of health claims is a liability. |
| D | **`vida-differential`** | ✅ **Should NOT be ported.** I read the code — it uses an LLM to generate a ranked list of candidate conditions (endometriosis, PCOS, thyroid, autoimmune, dysautonomia/POTS, ADHD, iron deficiency) with match strength, tests to request, specialists to see, and red flags. Despite "not a diagnosis" disclaimers, this is a differential diagnosis. It directly contradicts the iOS `AskGuardrails` refusal path, the onboarding promise ("Vida will never tell you what you have"), and the app's medical-disclaimer posture. **The feature is removed from the web app during migration.** The `/vida-differential` page will be removed or replaced with a wellness-patterns-only view. |

---

## 3. Migration Strategy — REVISED

### Principles

1. **Additive only** — never run fresh schema. Write migrations that add tables/columns/policies to the existing production database.
2. **Dual-write** — during transition, the web app writes to both Base44 and Supabase. Verify data parity, then stop writing to Base44.
3. **iOS stays live** — the iOS app is running against this Supabase project now. No changes that break iOS endpoints.
4. **No LLM for health questions** — the web Ask Vida must match the iOS safety model (curated answers, scripted guardrails). Anthropic only for non-health tasks.
5. **Password auth required** — every account has a password. Magic link optional as secondary.

### Phase Order

```
Phase 1: Additive schema migrations (new tables for web-only entities)
    ↓
Phase 2: Data access layer (Supabase client wrapper)
    ↓
Phase 3: Authentication (Supabase Auth — password primary)
    ↓
Phase 4: Backend functions → Supabase Edge Functions
    ↓
Phase 5: Frontend migration (dual-write: Base44 + Supabase)
    ↓
Phase 6: Integrations (Anthropic for non-health, Resend for email)
    ↓
Phase 7: Ask Vida — curated library, NO general LLM for symptoms
    ↓
Phase 8: Payments (Wix webhook → Supabase Edge Function, entitlements table)
    ↓
Phase 9: Scheduled tasks (pg_cron)
    ↓
Phase 10: Realtime + file storage
    ↓
Phase 11: Verify dual-write parity, then cutover + decommission Base44
```

---

## 4. Phase Details — REVISED

### Phase 1: Additive Schema Migrations

**Approach:** Write additive SQL migrations against the existing production database. Each migration is a new file in `supabase/migrations/` with a timestamp prefix. You run them via Supabase CLI or dashboard.

**Do NOT run `supabase_schema.sql`** — it creates tables that conflict with production.

#### 1.1 New tables needed (web-only entities not in iOS schema)

```sql
-- Migration: 20260921000001_add_web_tables.sql

-- Treatments (user-owned)
CREATE TABLE IF NOT EXISTS treatments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  type text CHECK (type IN ('medication','supplement','therapy','lifestyle','procedure','other')) DEFAULT 'medication',
  start_date date,
  end_date date,
  dosage text,
  effectiveness int CHECK (effectiveness BETWEEN 1 AND 5) DEFAULT 3,
  side_effects text,
  notes text,
  status text CHECK (status IN ('current','past','discontinued')) DEFAULT 'past',
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

-- Doctors (public read, admin write)
CREATE TABLE IF NOT EXISTS doctors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  practice_name text NOT NULL,
  specialty text NOT NULL,
  category text,
  phone text, email text, address text, city text, state text, zip_code text, website text,
  accepting_new_patients boolean DEFAULT true,
  notes text,
  sort_order numeric DEFAULT 0,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

-- Appointments (user-owned)
CREATE TABLE IF NOT EXISTS appointments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  doctor_id text NOT NULL,
  doctor_name text NOT NULL,
  practice_name text, specialty text,
  appointment_date date NOT NULL,
  appointment_time text NOT NULL,
  reason text,
  status text CHECK (status IN ('requested','confirmed','cancelled','completed')) DEFAULT 'requested',
  notes text,
  snapshot_sent boolean DEFAULT false,
  reminder_sent boolean DEFAULT false,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

-- Health resources (public read, admin write)
CREATE TABLE IF NOT EXISTS health_resources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  category text CHECK (category IN ('recipe','exercise','meditation','supplement','habit')),
  subcategory text,
  description text NOT NULL,
  content text NOT NULL,
  duration_minutes numeric,
  difficulty text DEFAULT 'easy',
  tags text[] DEFAULT '{}',
  citations text,
  is_public boolean DEFAULT true,
  sort_order numeric DEFAULT 0,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

-- Disease reports (public read, admin write)
CREATE TABLE IF NOT EXISTS disease_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  category text,
  summary text NOT NULL,
  overview text NOT NULL,
  symptoms text, diagnosis text, treatments text, resources text,
  doctors_guide text, advocacy_guide text, conquer_plan text,
  is_public boolean DEFAULT true,
  sort_order numeric DEFAULT 0,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

-- Explainers (public read, admin write)
CREATE TABLE IF NOT EXISTS explainers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  subtitle text,
  category text,
  content text NOT NULL,
  read_time_minutes int,
  image_url text,
  is_public boolean DEFAULT true,
  is_vida_plus boolean DEFAULT false,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

-- Substack articles (public read, admin write)
CREATE TABLE IF NOT EXISTS substack_articles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  link text NOT NULL,
  description text,
  pub_date text,
  sort_order numeric DEFAULT 0,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

-- Research papers (public read, admin write)
CREATE TABLE IF NOT EXISTS research_papers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  program text,
  year text,
  abstract text NOT NULL,
  file_url text,
  sort_order numeric DEFAULT 0,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

-- Newsletter signups (public insert, admin read/update/delete)
CREATE TABLE IF NOT EXISTS newsletter_signups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  source text DEFAULT 'site',
  status text CHECK (status IN ('subscribed','unsubscribed')) DEFAULT 'subscribed',
  unsubscribe_reason text,
  unsubscribe_token text,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

-- Community posts (authenticated read active, admin all)
CREATE TABLE IF NOT EXISTS community_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  title text NOT NULL,
  content text NOT NULL,
  category text DEFAULT 'general',
  display_name text DEFAULT 'Anonymous',
  status text CHECK (status IN ('active','hidden')) DEFAULT 'active',
  flagged boolean DEFAULT false,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

-- Community replies (authenticated read active, admin all)
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

-- Purchases (payment records — separate from entitlements)
CREATE TABLE IF NOT EXISTS purchases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  checkout_session_id text NOT NULL,
  status text CHECK (status IN ('pending','paid','canceled')) DEFAULT 'pending',
  order_id text,
  buyer_email text,
  product_id text, product_name text,
  quantity numeric DEFAULT 1,
  amount text, currency text,
  subscription_id text,
  paid_at timestamptz,
  canceled_at timestamptz,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

-- Experiment logs (user-owned)
CREATE TABLE IF NOT EXISTS experiment_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  experiment_id text NOT NULL,
  log_date date NOT NULL,
  adhered boolean DEFAULT true,
  notes text,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);
```

#### 1.2 RLS policies for new tables

All user-owned tables: `USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)`
All public-read tables: `SELECT USING (is_public = true OR security.is_admin())` + admin write
Community tables: active visible to authenticated, hidden admin-only, creator can insert, admin can update/delete

#### 1.3 Profile fields

```sql
-- Migration: 20260921000002_add_profile_fields.sql
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS gender text,
  ADD COLUMN IF NOT EXISTS health_concerns text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS last_rewind_date date,
  ADD COLUMN IF NOT EXISTS reminder_enabled boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS reminder_time text DEFAULT '20:00',
  ADD COLUMN IF NOT EXISTS content_updates boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS cycle_tracking_enabled boolean DEFAULT true;
```

#### 1.4 E2E encryption model (RESOLVED)

Shared tables are **not** encrypted. Owner-only tables (`check_ins`, `experiments`, `saved_articles`) are E2E encrypted — the web app will use the same encrypted tables with web-side crypto (matching iOS key derivation via `sync_keys`). Community tables are plaintext behind RLS with explicit column selection.

**For the web app:**
- `check_ins` / `experiments` / `saved_articles` → same encrypted tables, web frontend handles encryption/decryption using `sync_keys` (KDF + salt + iterations + wrapped_key). This matches iOS `VidaSyncService`.
- `community_posts` / `community_replies` → plaintext, but **never `select('*')`** — always explicit column list omitting `user_id` (the author linkage). The anon RLS grant omits `user_id` from the selectable columns.

#### 1.5 sync_keys table (verify before depending on it)

```sql
-- Migration: 20260921000000_verify_sync_keys.sql
-- Check if sync_keys exists; create if missing.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'sync_keys'
  ) THEN
    CREATE TABLE public.sync_keys (
      user_id     uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
      kdf         text        NOT NULL,
      salt        text        NOT NULL,
      iterations  integer     NOT NULL,
      wrapped_key text        NOT NULL,
      updated_at  timestamptz NOT NULL DEFAULT now()
    );
    ALTER TABLE public.sync_keys ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "own key" ON public.sync_keys
      FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;
```

**Action needed before Phase 2:** Verify `sync_keys` exists in the production database (check `information_schema.tables` in dashboard). If the escrow migration (`20260920120000`) was already applied, this is a no-op. If not, run the DDL above.

---

### Phase 3: Authentication — Password Primary

**Key rule:** Every account needs a password. iOS uses `auth.signUp(email:password:)` and `auth.signIn(email:password:)`. A magic-link-only user has no password and can't sign in on iOS.

#### 3.1 Registration flow (revised)

```
User enters email + password
  → supabase.auth.signUp({ email, password })
  → Supabase sends confirmation email (link, not OTP)
  → User clicks link → confirmed
  → User signs in with email + password
```

- **No 6-digit OTP step** — that was Base44's mechanism. Supabase's email confirmation link replaces it.
- **Password is required** at sign-up time.
- **Magic link** can be offered as an *additional* sign-in option on the Login page, but sign-up always requires a password.
- **Password reset** uses `supabase.auth.resetPasswordForEmail()` — replaces Base44's `resetPasswordRequest`.

#### 3.2 Files to change

| File | Current | New |
|------|---------|-----|
| `src/lib/AuthContext.jsx` | `base44.auth.me()`, `base44.auth.logout()` | `supabase.auth.getSession()`, `supabase.auth.onAuthStateChange()`, `supabase.auth.signOut()` |
| `src/pages/Login.jsx` | `base44.auth.loginViaEmailPassword()` | `supabase.auth.signInWithPassword()` + optional magic link |
| `src/pages/Register.jsx` | `base44.auth.register()` + OTP → verifyOtp → token | `supabase.auth.signUp({ email, password })` — no OTP step |
| `src/pages/ForgotPassword.jsx` | `base44.auth.resetPasswordRequest()` | `supabase.auth.resetPasswordForEmail()` |
| `src/pages/ResetPassword.jsx` | `base44.auth.resetPassword()` | `supabase.auth.updateUser({ password })` |
| `src/components/ProtectedRoute.jsx` | Reads AuthContext | Same — AuthContext now reads from Supabase |
| `src/components/GoogleIcon.jsx` | `base44.auth.loginWithProvider('google')` | `supabase.auth.signInWithOAuth({ provider: 'google' })` |

#### 3.3 Profile data

`supabase.auth.getUser()` returns the auth user. Custom fields (gender, health_concerns, etc.) live in `profiles` — fetch separately:

```javascript
async function getCurrentUser() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;
  const { data: profile } = await supabase.from('profiles').select('*').eq('id', user.id).single();
  return { ...user, ...profile };
}
```

Membership: check `security.is_vida_plus()` or query `entitlements` table — NOT `profiles.membership`.

---

### Phase 6: Integrations — Anthropic (non-health only) + Resend

| Base44 Integration | Replacement | Constraint |
|--------------------|-------------|------------|
| `InvokeLLM` | Anthropic API (Claude) from Edge Function | **Non-health tasks only** — summarizing, support triage, content drafting. Never symptom/diagnosis questions. |
| `SendEmail` | Resend API from Edge Function | Set `RESEND_API_KEY` in Supabase secrets |
| `GenerateImage` | OpenAI DALL-E or Stability AI | Set `OPENAI_API_KEY` (if used) |
| `TranscribeAudio` | OpenAI Whisper | Same key |
| `GenerateSpeech` | OpenAI TTS or ElevenLabs | Optional |
| `UploadPublicFile` | Supabase Storage (public bucket) | Create bucket |
| `UploadPrivateFile` | Supabase Storage (private bucket) | Create bucket |
| `CreateFileSignedUrl` | Supabase Storage `createSignedUrl()` | Built in |

**Secrets to set in Supabase:**
```
ANTHROPIC_API_KEY
RESEND_API_KEY
```

**Functions that use LLM (must be scoped to non-health only):**
- `appointment-concierge` — drafts appointment prep notes (non-diagnostic) ✅
- `body-weather-forecast` — analyzes check-in patterns (wellness observations, not diagnosis) ⚠️ review prompt to ensure it never names conditions
- `experiment-results` — summarizes experiment data ✅

**Functions that will NOT be ported:**
- `vida-differential` — **removed.** It uses an LLM to generate a ranked list of candidate conditions (endometriosis, PCOS, thyroid, autoimmune, POTS, ADHD, iron deficiency) with match strength, tests to request, specialists to see, and red flags. Despite "not a diagnosis" disclaimers, this is a differential diagnosis. It contradicts the iOS `AskGuardrails` refusal path, the onboarding promise ("Vida will never tell you what you have"), and the app's medical-disclaimer posture. The `/vida-differential` page is removed from the web app.

**Functions that must NOT use LLM:**
- `vida-chat-gate` / `vida-chat-send` — see Phase 7

---

### Phase 7: Ask Vida — Curated Library, NO General LLM (MAJOR REWRITE)

**The problem:** The iOS Ask Vida deliberately has no LLM. It answers from a curated library of cited answers, and AskGuardrails refuses diagnosis and medication questions with scripted text. The web version currently puts a general LLM in front of health questions. This contradicts the app's core safety promise — the web version becomes the weakest link, regulatory-wise.

**The fix:** Rebuild web Ask Vida to match the iOS model.

#### 7.1 Architecture

```
User asks a question
  → AskGuardrails classifier (rule-based, NOT LLM):
      Is this a symptom/diagnosis/medication question?
        YES → Return scripted refusal text (same as iOS)
        NO  → Continue
  → Search curated answer library (explainers table + curated_qa table)
  → Return best match with citations
  → If no match → Return "I don't have a curated answer for that yet"
```

**No general LLM in the health Q&A path.** Anthropic is used only for:
- Summarizing user's own check-in data (wellness observations, not diagnosis)
- Support triage (categorizing a user's question for routing)
- Content drafting (helping write doctor prep notes from check-in data)

#### 7.2 Curated library — read the existing one, don't build a second

The iOS app has 17 curated entries in `Models/AskVidaLibrary.swift` (328 lines). Each entry is a `VidaAnswer`:
- `id`, `question`, `shortAnswer`, `detail[]`, `articleID` (links to citation-bearing article), `trackSuggestion`, `keywords[]`, `relevance`

**Two rules the web app must preserve:**
1. **No answer without sources** — suggested questions are filtered on `!article.citations.isEmpty`. An answer with no citations is a promise Vida can't keep.
2. **`relevance` suggests, never restricts** — someone asking a question outright gets the best answer regardless of sex (matters for anyone reading about a partner or child).

**Approach:** Port the 17 entries from `AskVidaLibrary.swift` into a `curated_qa` table (one-time migration), then both web and iOS read from the same table. Do not build a second library — two divergent sets of health claims is a liability.

```sql
-- Migration: 20260921000003_add_ask_vida_tables.sql

-- Curated Q&A library (mirrors iOS AskVidaLibrary.swift)
CREATE TABLE IF NOT EXISTS curated_qa (
  id text PRIMARY KEY,                    -- matches VidaAnswer.id
  question text NOT NULL,
  short_answer text NOT NULL,
  detail jsonb DEFAULT '[]',             -- array of strings
  article_id text,                       -- links to citation-bearing article/explainer
  track_suggestion text,                 -- SignalCategory
  keywords jsonb DEFAULT '[]',           -- array of strings
  relevance text DEFAULT 'anyone',       -- anyone | female | male (suggests, never restricts)
  is_active boolean DEFAULT true,
  sort_order numeric DEFAULT 0,
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

-- RLS: public read (active entries), admin write
ALTER TABLE curated_qa ENABLE ROW LEVEL SECURITY;
CREATE POLICY "curated_qa_public_read" ON curated_qa FOR SELECT
  USING (is_active = true OR security.is_admin());
CREATE POLICY "curated_qa_admin_write" ON curated_qa FOR ALL
  USING (security.is_admin()) WITH CHECK (security.is_admin());

-- Agent conversations (for non-health chat only)
CREATE TABLE IF NOT EXISTS agent_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  agent_name text DEFAULT 'vida',
  messages jsonb DEFAULT '[]',
  metadata jsonb DEFAULT '{}',
  created_date timestamptz DEFAULT now(),
  updated_date timestamptz DEFAULT now()
);

ALTER TABLE agent_conversations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "conversations_owner" ON agent_conversations FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
```

#### 7.3 Edge Functions

- `vida-chat-gate` → verifies Vida+ (via `security.is_vida_plus()`) + creates conversation row
- `vida-chat-send` → runs AskGuardrails (rule-based) → if health/diagnosis/medication question, returns scripted refusal → if non-health, searches `curated_qa` table → returns answer with citations → if no match, returns "I don't have a curated answer for that yet"

#### 7.4 AskGuardrails (rule-based, no LLM) — mirror iOS exactly

The iOS `AskGuardrails.swift` classifies every question before any answer is generated. Three of four outcomes are refusals:

1. **Diagnosis path** — matches "do i have", "could i have", "diagnose", "is it cancer", "what's wrong with me" → returns: *"Vida can't tell you what you have — Naming a condition takes an examination, usually tests, and a clinician who can weigh everything together."*
2. **Medication/dosing path** — matches "should i take", "what dose", "can i mix" → returns scripted refusal about medication decisions.
3. **Emergency path** — overrides everything, with distinct wording for mental-health crises (988, Samaritans).
4. **OK path** — question passes guardrails, proceeds to curated library search.

The web app must implement the same classifier with the same keyword lists and the same refusal text. No LLM in this path.

---

### Phase 8: Payments — Wix Webhook → Supabase Edge Function

**Not using RevenueCat** (rejected). Currently Wix/Base44 Payments.

#### 8.1 What changes

- `payments-webhook` → Supabase Edge Function at `https://YOUR-PROJECT.supabase.co/functions/v1/payments-webhook`
- Wix webhook registration points to the new URL
- Payment records → `purchases` table (new, additive)
- **Membership grant** → `entitlements` table (insert/update row with `status='active'`, `expires_at`), NOT `profiles.membership`
- `create-checkout` → Edge Function (same Wix API calls)
- `check-payment-status` → Edge Function

#### 8.2 Membership check

Use `security.is_vida_plus()` (already exists in production) — checks `entitlements` table. This replaces `hasVidaPlus()` which queried `Base44Purchase`.

---

## 5. All Questions Resolved — Ready to Start

All four blocking questions are answered (see §2 "Resolved (round 2)"). Summary:

- **E2E encryption**: Shared tables stay plaintext behind RLS with explicit column selection (never `select('*')`, `user_id`/`author_id` omitted from anon grants). Owner-only tables (`check_ins`, `experiments`, `saved_articles`) are E2E encrypted — web app uses same encrypted tables with web-side crypto via `sync_keys`.
- **`sync_keys`**: Verify it exists in the dashboard before Phase 2. DDL provided in §3.1.5 if missing.
- **Curated Q&A library**: Port the 17 entries from `AskVidaLibrary.swift` into `curated_qa` table. Don't build a second library.
- **`vida-differential`**: Not ported. Feature removed from web app.

---

## 6. Recommended Starting Point

I'll start with **Phase 1: Additive schema migrations** — writing the SQL migration files for the new web-only tables, designed to run safely against your live production database.

The `supabase_schema.sql` file in the repo will be **deleted** — it does not reflect production and running it would risk data loss.

**Before I write Phase 1 migrations, one action item for you:** verify `sync_keys` exists in your Supabase dashboard (check `information_schema.tables`). If it's missing, the DDL in §3.1.5 needs to be run first.

---

*All blocking questions resolved. Ready to begin Phase 1 on your go-ahead.*