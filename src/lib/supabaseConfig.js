// ============================================================
// SUPABASE CONFIG — Paste your public credentials here
// ============================================================
// Find these in: Supabase Dashboard → Project Settings → API
// Never paste actual key values in comments — use Base44 secrets.
//
// The service role key is NOT here — it's stored securely as a
// Base44 secret (SUPABASE_SERVICE_ROLE_KEY) for backend functions only.
// ============================================================

// The anon key is public by design — Supabase security comes from RLS policies,
// not from hiding this key. The service role key is NEVER included here.
export const SUPABASE_URL = "https://lhorsiwwnqzkvunuazry.supabase.co";
export const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxob3JzaXd3bnF6a3Z1bnVhenJ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk2NDg5ODgsImV4cCI6MjEwNTIyNDk4OH0.ZcPki4QByp8CyaVLpMoKnispwtgjfXq3Jijd4h38C7o";
// Turn on after deploying the Supabase Edge Functions (see
// supabase/functions/PORTING_STATUS.md). While off, every function call keeps
// going to Base44, so the site works the same before and after this change.
export const SUPABASE_FUNCTIONS_LIVE = false;
