-- ============================================================
-- Eagle Eats — Supabase (Postgres) Schema
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- 1. Dining Halls (static reference table)
CREATE TABLE IF NOT EXISTS dining_halls (
    id            TEXT PRIMARY KEY,            -- e.g. "bruceteria"
    location_id   INTEGER NOT NULL UNIQUE,     -- UNT site locationID (10, 15, 20, 25, 31)
    name          TEXT NOT NULL,
    subtitle      TEXT,
    description   TEXT,
    location_text TEXT,                        -- human address
    latitude      DOUBLE PRECISION,
    longitude     DOUBLE PRECISION,
    gradient_start TEXT,
    gradient_end   TEXT,
    icon_name     TEXT,
    hours_text    TEXT,
    weekday_open  INTEGER DEFAULT 0,          -- minutes from midnight
    weekday_close INTEGER DEFAULT 0,
    weekend_open  INTEGER DEFAULT 0,
    weekend_close INTEGER DEFAULT 0,
    tags          TEXT[] DEFAULT '{}',
    created_at    TIMESTAMPTZ DEFAULT now()
);

-- Seed the 5 UNT dining halls
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
    id            TEXT PRIMARY KEY,            -- "{hall_id}-{recipe_id}"
    hall_id       TEXT NOT NULL REFERENCES dining_halls(id),
    recipe_id     TEXT NOT NULL,
    name          TEXT NOT NULL,
    description   TEXT DEFAULT '',
    category      TEXT DEFAULT 'Entrées',
    station       TEXT DEFAULT '',
    meal_periods  TEXT[] NOT NULL DEFAULT '{}', -- e.g. {"Breakfast","Lunch"}
    dietary_tags  JSONB DEFAULT '[]',           -- [{id, label, color, icon}]
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
    allergens     TEXT[] DEFAULT '{}',             -- e.g. {"Milk","Eggs","Wheat"}
    ingredients   TEXT DEFAULT '',                 -- full ingredient list from label
    fetched_at    TIMESTAMPTZ DEFAULT now()
);

-- Migration for existing tables (safe to re-run):
-- ALTER TABLE nutrition_info ADD COLUMN IF NOT EXISTS allergens TEXT[] DEFAULT '{}';
-- ALTER TABLE nutrition_info ADD COLUMN IF NOT EXISTS ingredients TEXT DEFAULT '';

-- 4. App Users (linked to UNT identity from portal SSO)
CREATE TABLE IF NOT EXISTS app_users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    unt_display_name TEXT,
    unt_identifier   TEXT UNIQUE,              -- EID / NetID if extractable
    device_id     TEXT,                        -- anonymous device fingerprint
    created_at    TIMESTAMPTZ DEFAULT now(),
    last_seen_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_users_identifier ON app_users(unt_identifier);

-- 5. Scrape Log (track Lambda runs for debugging)
CREATE TABLE IF NOT EXISTS scrape_log (
    id            BIGSERIAL PRIMARY KEY,
    scrape_date   DATE NOT NULL,
    halls_scraped INTEGER DEFAULT 0,
    items_scraped INTEGER DEFAULT 0,
    nutrition_fetched INTEGER DEFAULT 0,
    duration_ms   INTEGER DEFAULT 0,
    status        TEXT DEFAULT 'success',      -- success | partial | failed
    error_message TEXT,
    created_at    TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- Row Level Security (RLS)
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE dining_halls  ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_items    ENABLE ROW LEVEL SECURITY;
ALTER TABLE nutrition_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_users     ENABLE ROW LEVEL SECURITY;
ALTER TABLE scrape_log    ENABLE ROW LEVEL SECURITY;

-- Public read access for menu data (anon key can read)
CREATE POLICY "Public read dining_halls"  ON dining_halls  FOR SELECT USING (true);
CREATE POLICY "Public read menu_items"    ON menu_items    FOR SELECT USING (true);
CREATE POLICY "Public read nutrition_info" ON nutrition_info FOR SELECT USING (true);

-- Only service_role (Lambda) can write menu data
CREATE POLICY "Service write dining_halls"  ON dining_halls  FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Service write menu_items"    ON menu_items    FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Service write nutrition_info" ON nutrition_info FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Service write scrape_log"    ON scrape_log    FOR ALL USING (true) WITH CHECK (true);

-- Users can only see their own row
CREATE POLICY "Users read own data" ON app_users FOR SELECT USING (true);
CREATE POLICY "Service write app_users" ON app_users FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- Helper: Delete old menu data (keep 7 days)
-- Called by Lambda after each scrape
-- ============================================================
CREATE OR REPLACE FUNCTION cleanup_old_menus()
RETURNS void AS $$
BEGIN
    DELETE FROM menu_items WHERE menu_date < CURRENT_DATE - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
