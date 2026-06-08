-- ============================================================
-- Mean Eats — Guest & Auth Event Tracking (app_events)
-- Run in: Supabase Dashboard → SQL Editor → New Query
--
-- FIRST-TIME SETUP — no DROP / DELETE / TRUNCATE.
-- Safe to run: creates a NEW table only; does not touch
-- dining_halls, menu_items, nutrition_info, or check_ins.
-- ============================================================

-- 1. Events table (new — no existing data affected)
CREATE TABLE IF NOT EXISTS app_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         TEXT NOT NULL,
    user_type       TEXT NOT NULL CHECK (user_type IN ('guest', 'auth')),
    event_type      TEXT NOT NULL,
    metadata        JSONB NOT NULL DEFAULT '{}'::jsonb,
    guest_id        TEXT,
    linked_user_id  TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT app_events_user_id_len
        CHECK (char_length(user_id) BETWEEN 8 AND 128),
    CONSTRAINT app_events_event_type_len
        CHECK (char_length(event_type) BETWEEN 1 AND 64),
    CONSTRAINT app_events_guest_id_format
        CHECK (guest_id IS NULL OR guest_id LIKE 'guest_%')
);

CREATE INDEX IF NOT EXISTS idx_app_events_user_id      ON app_events(user_id);
CREATE INDEX IF NOT EXISTS idx_app_events_user_type    ON app_events(user_type);
CREATE INDEX IF NOT EXISTS idx_app_events_event_type   ON app_events(event_type);
CREATE INDEX IF NOT EXISTS idx_app_events_guest_id     ON app_events(guest_id);
CREATE INDEX IF NOT EXISTS idx_app_events_linked_user  ON app_events(linked_user_id);
CREATE INDEX IF NOT EXISTS idx_app_events_created_at   ON app_events(created_at DESC);

-- 2. RLS — insert-only telemetry from mobile app (anon key)
ALTER TABLE app_events ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename  = 'app_events'
          AND policyname = 'anon_insert_app_events'
    ) THEN
        CREATE POLICY "anon_insert_app_events"
            ON app_events FOR INSERT TO anon, authenticated
            WITH CHECK (
                char_length(user_id) BETWEEN 8 AND 128
                AND user_type IN ('guest', 'auth')
                AND char_length(event_type) BETWEEN 1 AND 64
                AND (guest_id IS NULL OR guest_id LIKE 'guest_%')
            );
    END IF;
END $$;

-- 3. Link guest history when user upgrades to authenticated
CREATE OR REPLACE FUNCTION link_guest_to_auth(p_guest_id TEXT, p_auth_id TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    IF p_guest_id IS NULL OR p_auth_id IS NULL THEN
        RETURN 0;
    END IF;
    IF char_length(p_guest_id) < 8 OR char_length(p_auth_id) < 8 THEN
        RETURN 0;
    END IF;
    IF p_guest_id NOT LIKE 'guest_%' THEN
        RETURN 0;
    END IF;

    UPDATE app_events
    SET linked_user_id = p_auth_id
    WHERE user_id = p_guest_id
      AND user_type = 'guest'
      AND linked_user_id IS NULL;

    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$;

REVOKE ALL ON FUNCTION link_guest_to_auth(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION link_guest_to_auth(TEXT, TEXT) TO anon, authenticated;

-- ============================================================
-- Verify (optional — run separately after the migration)
-- ============================================================
-- SELECT COUNT(*) FROM app_events;
-- SELECT policyname FROM pg_policies WHERE tablename = 'app_events';
