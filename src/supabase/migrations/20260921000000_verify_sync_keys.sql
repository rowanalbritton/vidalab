-- ============================================================
-- VIDA LAB — Phase 1: Verify/create sync_keys table
-- ============================================================
-- Safe to re-run. Creates sync_keys only if it does not exist.
-- Assumes security.is_admin() already exists (iOS schema).
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'sync_keys'
  ) THEN
    CREATE TABLE public.sync_keys (
      user_id     uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
      kdf         text        NOT NULL,
      salt        text        NOT NULL,
      iterations  integer     NOT NULL,
      wrapped_key text        NOT NULL,
      updated_at  timestamptz NOT NULL DEFAULT now()
    );

    ALTER TABLE public.sync_keys ENABLE ROW LEVEL SECURITY;

    CREATE POLICY "own key" ON public.sync_keys
      FOR ALL TO authenticated
      USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

    RAISE NOTICE 'Created public.sync_keys table';
  ELSE
    RAISE NOTICE 'public.sync_keys already exists — skipping';
  END IF;
END $$;