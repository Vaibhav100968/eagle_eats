-- ============================================================
-- Eagle Eats — RLS Security Fix (run on EXISTING Supabase project)
-- Supabase Dashboard → SQL Editor → New Query → Run
--
-- Fixes: removes policies that accidentally granted anon write access.
-- Safe to re-run (uses DROP POLICY IF EXISTS).
-- ============================================================

-- 1. Drop all legacy / insecure policies
DROP POLICY IF EXISTS "Public read dining_halls"   ON dining_halls;
DROP POLICY IF EXISTS "Public read menu_items"     ON menu_items;
DROP POLICY IF EXISTS "Public read nutrition_info" ON nutrition_info;
DROP POLICY IF EXISTS "Service write dining_halls"   ON dining_halls;
DROP POLICY IF EXISTS "Service write menu_items"     ON menu_items;
DROP POLICY IF EXISTS "Service write nutrition_info" ON nutrition_info;
DROP POLICY IF EXISTS "Service write scrape_log"     ON scrape_log;
DROP POLICY IF EXISTS "Users read own data"          ON app_users;
DROP POLICY IF EXISTS "Service write app_users"      ON app_users;
DROP POLICY IF EXISTS "Public read check_ins"        ON check_ins;
DROP POLICY IF EXISTS "Public insert check_ins"      ON check_ins;

-- Drop new policy names too (so this script is idempotent)
DROP POLICY IF EXISTS "anon_read_dining_halls"   ON dining_halls;
DROP POLICY IF EXISTS "anon_read_menu_items"     ON menu_items;
DROP POLICY IF EXISTS "anon_read_nutrition_info" ON nutrition_info;
DROP POLICY IF EXISTS "anon_read_check_ins"      ON check_ins;
DROP POLICY IF EXISTS "anon_insert_check_ins"    ON check_ins;

-- 2. Ensure RLS is enabled
ALTER TABLE dining_halls   ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_items     ENABLE ROW LEVEL SECURITY;
ALTER TABLE nutrition_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_users      ENABLE ROW LEVEL SECURITY;
ALTER TABLE scrape_log     ENABLE ROW LEVEL SECURITY;
ALTER TABLE check_ins      ENABLE ROW LEVEL SECURITY;

-- 3. Tighten check_ins constraints (ignore if already applied)
ALTER TABLE check_ins DROP CONSTRAINT IF EXISTS check_ins_user_name_len;
ALTER TABLE check_ins DROP CONSTRAINT IF EXISTS check_ins_id_len;
ALTER TABLE check_ins DROP CONSTRAINT IF EXISTS check_ins_meal_period;

ALTER TABLE check_ins
    ADD CONSTRAINT check_ins_user_name_len
        CHECK (char_length(user_name) BETWEEN 1 AND 40);

ALTER TABLE check_ins
    ADD CONSTRAINT check_ins_id_len
        CHECK (char_length(id) BETWEEN 8 AND 64);

ALTER TABLE check_ins
    ADD CONSTRAINT check_ins_meal_period
        CHECK (meal_period IN ('Breakfast', 'Lunch', 'Dinner'));

CREATE UNIQUE INDEX IF NOT EXISTS idx_check_ins_daily_unique
    ON check_ins (hall_id, user_name, checked_in_date);

-- 4. Secure policies — anon/authenticated read menu + check-ins only
CREATE POLICY "anon_read_dining_halls"
    ON dining_halls FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "anon_read_menu_items"
    ON menu_items FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "anon_read_nutrition_info"
    ON nutrition_info FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "anon_read_check_ins"
    ON check_ins FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "anon_insert_check_ins"
    ON check_ins FOR INSERT TO anon, authenticated
    WITH CHECK (
        char_length(user_name) BETWEEN 1 AND 40
        AND char_length(id) BETWEEN 8 AND 64
        AND meal_period IN ('Breakfast', 'Lunch', 'Dinner')
        AND checked_in_date = CURRENT_DATE
        AND hall_id IN (SELECT id FROM dining_halls)
        AND hall_name = (SELECT name FROM dining_halls WHERE id = hall_id)
    );

-- app_users + scrape_log: no anon policies → access denied (Lambda uses service_role)

-- 6. App events (guest/auth analytics)
CREATE TABLE IF NOT EXISTS app_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         TEXT NOT NULL,
    user_type       TEXT NOT NULL CHECK (user_type IN ('guest', 'auth')),
    event_type      TEXT NOT NULL,
    metadata        JSONB NOT NULL DEFAULT '{}'::jsonb,
    guest_id        TEXT,
    linked_user_id  TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT app_events_user_id_len CHECK (char_length(user_id) BETWEEN 8 AND 128),
    CONSTRAINT app_events_event_type_len CHECK (char_length(event_type) BETWEEN 1 AND 64),
    CONSTRAINT app_events_guest_id_format CHECK (guest_id IS NULL OR guest_id LIKE 'guest_%')
);

CREATE INDEX IF NOT EXISTS idx_app_events_user_id    ON app_events(user_id);
CREATE INDEX IF NOT EXISTS idx_app_events_guest_id   ON app_events(guest_id);
CREATE INDEX IF NOT EXISTS idx_app_events_created_at ON app_events(created_at DESC);

ALTER TABLE app_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_insert_app_events" ON app_events;

CREATE POLICY "anon_insert_app_events"
    ON app_events FOR INSERT TO anon, authenticated
    WITH CHECK (
        char_length(user_id) BETWEEN 8 AND 128
        AND user_type IN ('guest', 'auth')
        AND char_length(event_type) BETWEEN 1 AND 64
        AND (guest_id IS NULL OR guest_id LIKE 'guest_%')
    );

CREATE OR REPLACE FUNCTION link_guest_to_auth(p_guest_id TEXT, p_auth_id TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    IF p_guest_id IS NULL OR p_auth_id IS NULL THEN RETURN 0; END IF;
    IF char_length(p_guest_id) < 8 OR char_length(p_auth_id) < 8 THEN RETURN 0; END IF;
    IF p_guest_id NOT LIKE 'guest_%' THEN RETURN 0; END IF;
    UPDATE app_events SET linked_user_id = p_auth_id
    WHERE user_id = p_guest_id AND user_type = 'guest' AND linked_user_id IS NULL;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$;

REVOKE ALL ON FUNCTION link_guest_to_auth(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION link_guest_to_auth(TEXT, TEXT) TO anon, authenticated;

-- 5. Lock down maintenance RPC to service_role only
CREATE OR REPLACE FUNCTION cleanup_old_checkins()
RETURNS void AS $$
BEGIN
    DELETE FROM check_ins WHERE checked_in_date < CURRENT_DATE - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION cleanup_old_menus()
RETURNS void AS $$
BEGIN
    DELETE FROM menu_items WHERE menu_date < CURRENT_DATE - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION cleanup_old_checkins() FROM PUBLIC;
REVOKE ALL ON FUNCTION cleanup_old_menus() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION cleanup_old_checkins() TO service_role;
GRANT EXECUTE ON FUNCTION cleanup_old_menus() TO service_role;

-- ============================================================
-- Done. Verify in Supabase → Authentication → Policies
-- ============================================================
