-- ============================================================
-- VIDA LAB — Phase 1: Verify/create sync_keys table
-- ============================================================
-- The iOS VidaSyncService depends on this table for E2E encryption
-- key escrow. If the 20260920120000 migration was already applied,
-- this is a no-op. If not, it creates the table.
--
-- IMPORTANT: Before the web app depends on sync_keys, verify this
-- table exists by checking information_schema.tables in the dashboard.
-- If wrappedKey() silently returns nil, the app shows "Off" — which
-- looks the same as a genuinely-off account.
-- ============================================================

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

    RAISE NOTICE 'Created public.sync_keys table';
  ELSE
    RAISE NOTICE 'public.sync_keys already exists — skipping';
  END IF;
END $$;