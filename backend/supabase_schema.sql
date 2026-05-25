-- ============================================================
-- Eagle Eats — Supabase (Postgres) Schema
-- Run this in: Supabase Dashboard → SQL Editor → New Query
--
-- Security model:
--   • anon (iOS app): READ menu tables + check_ins; INSERT check_ins only
--   • service_role (Lambda): full access (bypasses RLS — no write policies needed)
--   • app_users, scrape_log: no anon/authenticated access
-- ============================================================

-- 1. Dining Halls (static reference table)
CREATE TABLE IF NOT EXISTS dining_halls (
    id            TEXT PRIMARY KEY,
    location_id   INTEGER NOT NULL UNIQUE,
    name          TEXT NOT NULL,
    subtitle      TEXT,
    description   TEXT,
    location_text TEXT,
    latitude      DOUBLE PRECISION,
    longitude     DOUBLE PRECISION,
    gradient_start TEXT,
    gradient_end   TEXT,
    icon_name     TEXT,
    hours_text    TEXT,
    weekday_open  INTEGER DEFAULT 0,
    weekday_close INTEGER DEFAULT 0,
    weekend_open  INTEGER DEFAULT 0,
    weekend_close INTEGER DEFAULT 0,
    tags          TEXT[] DEFAULT '{}',
    created_at    TIMESTAMPTZ DEFAULT now()
);

INSERT INTO dining_halls (id, location_id, name, subtitle, description, location_text, latitude, longitude, gradient_start, gradient_end, icon_name, hours_text, weekday_open, weekday_close, weekend_open, weekend_close, tags)
VALUES
    ('mean-greens',  10, 'Mean Greens Café', '100% Vegan', 'America''s first all-vegan university dining hall.', 'Maple Hall, 902 Avenue C', 33.20850, -97.15120, '00853E', '003D1F', 'leaf.circle.fill', 'Mon–Thu 7 AM – 8 PM', 420, 1200, 0, 0, ARRAY['Vegan','Plant-Based','Sustainable']),
    ('champs',       15, 'Champs', 'Sports Nutrition', 'Performance-focused dining near Apogee Stadium.', 'Victory Hall, 1379 S Bonnie Brae', 33.21530, -97.15330, '1A5276', '003D1F', 'figure.run', 'Mon–Thu 7 AM – 8 PM', 420, 1200, 0, 0, ARRAY['High Protein','Athletic','Performance']),
    ('bruceteria',   20, 'Bruceteria', 'All-You-Care-To-Eat', 'The heart of residential dining at UNT.', 'Bruce Hall, 1624 Chestnut St', 33.21040, -97.15180, '00853E', '005227', 'fork.knife', 'Mon–Fri 7 AM – 4:30 PM', 420, 990, 0, 0, ARRAY['All-You-Can-Eat','Global Cuisine','Made-to-Order']),
    ('kitchen-west', 25, 'Kitchen West', 'Allergen-Free Zone', 'Texas'' first Certified Free From™ Big 9 Allergens.', 'West Hall, 320 N Texas Blvd', 33.21120, -97.15690, '7D3C98', '512E58', 'leaf.fill', 'Mon–Thu 11 AM – 7 PM', 660, 1140, 0, 0, ARRAY['Allergen-Free','Top-9 Free','Safe Dining']),
    ('eagle-landing', 31, 'Eagle Landing', 'Residential Dining', 'Comfort food classics alongside global options.', 'Eagle Landing, 1416 Maple', 33.20910, -97.15450, '27AE60', '1E8449', 'house.fill', 'Mon–Thu 10 AM – 9 PM', 600, 1260, 600, 1260, ARRAY['Comfort Food','Diverse Menu','Residential'])
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    location_id = EXCLUDED.location_id;

-- 2. Menu Items (scraped daily by Lambda)
CREATE TABLE IF NOT EXISTS menu_items (
    id            TEXT PRIMARY KEY,
    hall_id       TEXT NOT NULL REFERENCES dining_halls(id),
    recipe_id     TEXT NOT NULL,
    name          TEXT NOT NULL,
    description   TEXT DEFAULT '',
    category      TEXT DEFAULT 'Entrées',
    station       TEXT DEFAULT '',
    meal_periods  TEXT[] NOT NULL DEFAULT '{}',
    dietary_tags  JSONB DEFAULT '[]',
    menu_date     DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_menu_items_hall_date ON menu_items(hall_id, menu_date);
CREATE INDEX IF NOT EXISTS idx_menu_items_date ON menu_items(menu_date);
CREATE INDEX IF NOT EXISTS idx_menu_items_recipe ON menu_items(recipe_id);

-- 3. Nutrition Info (scraped per recipe, cached long-term)
CREATE TABLE IF NOT EXISTS nutrition_info (
    recipe_id     TEXT PRIMARY KEY,
    calories      DOUBLE PRECISION DEFAULT 0,
    protein       DOUBLE PRECISION DEFAULT 0,
    carbohydrates DOUBLE PRECISION DEFAULT 0,
    fat           DOUBLE PRECISION DEFAULT 0,
    fiber         DOUBLE PRECISION,
    sugar         DOUBLE PRECISION,
    sodium        DOUBLE PRECISION,
    serving_size  TEXT,
    allergens     TEXT[] DEFAULT '{}',
    ingredients   TEXT DEFAULT '',
    fetched_at    TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE nutrition_info ADD COLUMN IF NOT EXISTS allergens TEXT[] DEFAULT '{}';
ALTER TABLE nutrition_info ADD COLUMN IF NOT EXISTS ingredients TEXT DEFAULT '';

-- 4. App Users (server-side only — not used by iOS anon client today)
CREATE TABLE IF NOT EXISTS app_users (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    unt_display_name TEXT,
    unt_identifier   TEXT UNIQUE,
    device_id        TEXT,
    created_at       TIMESTAMPTZ DEFAULT now(),
    last_seen_at     TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_users_identifier ON app_users(unt_identifier);

-- 5. Scrape Log (Lambda / service_role only)
CREATE TABLE IF NOT EXISTS scrape_log (
    id                BIGSERIAL PRIMARY KEY,
    scrape_date       DATE NOT NULL,
    halls_scraped     INTEGER DEFAULT 0,
    items_scraped     INTEGER DEFAULT 0,
    nutrition_fetched INTEGER DEFAULT 0,
    duration_ms       INTEGER DEFAULT 0,
    status            TEXT DEFAULT 'success',
    error_message     TEXT,
    created_at        TIMESTAMPTZ DEFAULT now()
);

-- 6. Check-ins (anon read + validated insert)
CREATE TABLE IF NOT EXISTS check_ins (
    id              TEXT PRIMARY KEY,
    hall_id         TEXT NOT NULL REFERENCES dining_halls(id),
    hall_name       TEXT NOT NULL,
    meal_period     TEXT NOT NULL,
    user_name       TEXT NOT NULL DEFAULT 'Eagle',
    checked_in_date DATE NOT NULL DEFAULT CURRENT_DATE,
    checked_in_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_ins_user_name_len CHECK (char_length(user_name) BETWEEN 1 AND 40),
    CONSTRAINT check_ins_id_len CHECK (char_length(id) BETWEEN 8 AND 64),
    CONSTRAINT check_ins_meal_period CHECK (meal_period IN ('Breakfast', 'Lunch', 'Dinner'))
);

CREATE INDEX IF NOT EXISTS idx_check_ins_date ON check_ins(checked_in_date);
CREATE UNIQUE INDEX IF NOT EXISTS idx_check_ins_daily_unique
    ON check_ins (hall_id, user_name, checked_in_date);

-- ============================================================
-- Row Level Security (RLS)
-- ============================================================

ALTER TABLE dining_halls   ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_items     ENABLE ROW LEVEL SECURITY;
ALTER TABLE nutrition_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_users      ENABLE ROW LEVEL SECURITY;
ALTER TABLE scrape_log     ENABLE ROW LEVEL SECURITY;
ALTER TABLE check_ins      ENABLE ROW LEVEL SECURITY;

-- Drop legacy insecure policies (safe if re-running on existing DB)
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

-- anon + authenticated: read-only menu data
CREATE POLICY "anon_read_dining_halls"
    ON dining_halls FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "anon_read_menu_items"
    ON menu_items FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "anon_read_nutrition_info"
    ON nutrition_info FOR SELECT TO anon, authenticated USING (true);

-- anon + authenticated: read check-ins, insert with validation
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

-- app_users + scrape_log: no policies for anon/authenticated → denied by default
-- service_role bypasses RLS for Lambda writes

-- ============================================================
-- Maintenance functions (service_role only via RPC)
-- ============================================================

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
