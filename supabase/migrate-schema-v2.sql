-- ============================================================
-- GRIDFEED SCHEMA MIGRATION V2
-- Date: 2026-04-11
-- Non-destructive. Safe to run multiple times.
-- Run in Supabase SQL Editor for project jrkptskwmdtbcucmqwft
-- ============================================================

-- ==================== EXTENSIONS ====================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- PART 1 — 12 MISSING TABLES
-- ============================================================

-- 1. strategy
CREATE TABLE IF NOT EXISTS strategy (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  race_id         uuid REFERENCES races(id) ON DELETE CASCADE,
  session_key     int,
  driver_number   int NOT NULL,
  stint_number    int,
  compound        text,
  tyre_age        int,
  lap_start       int,
  lap_end         int,
  is_current      boolean DEFAULT false,
  fetched_at      timestamptz DEFAULT now(),
  created_at      timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_strategy_race_driver ON strategy(race_id, driver_number);

-- 2. race_control
CREATE TABLE IF NOT EXISTS race_control (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  race_id         uuid REFERENCES races(id) ON DELETE CASCADE,
  session_key     int,
  date            timestamptz,
  lap_number      int,
  category        text,
  flag            text,
  scope           text,
  sector          int,
  driver_number   int,
  message         text NOT NULL,
  fetched_at      timestamptz DEFAULT now(),
  created_at      timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_race_control_race_date ON race_control(race_id, created_at DESC);

-- 3. weather_data
CREATE TABLE IF NOT EXISTS weather_data (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  race_id         uuid REFERENCES races(id) ON DELETE CASCADE,
  session_key     int,
  air_temp        numeric,
  track_temp      numeric,
  humidity        numeric,
  pressure        numeric,
  rainfall        boolean DEFAULT false,
  wind_direction  int,
  wind_speed      numeric,
  fetched_at      timestamptz DEFAULT now(),
  created_at      timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_weather_race_fetched ON weather_data(race_id, fetched_at DESC);

-- 4. car_locations
CREATE TABLE IF NOT EXISTS car_locations (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  race_id         uuid REFERENCES races(id) ON DELETE CASCADE,
  session_key     int,
  driver_number   int NOT NULL,
  x               int,
  y               int,
  z               int,
  date            timestamptz,
  fetched_at      timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_car_loc_session ON car_locations(session_key, driver_number, date DESC);

-- 5. tweets
CREATE TABLE IF NOT EXISTS tweets (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  article_id      uuid REFERENCES articles(id) ON DELETE SET NULL,
  tweet_text      text NOT NULL,
  status          text DEFAULT 'pending',
  tweet_id        text,
  tweet_type      text,
  scheduled_post_at timestamptz,
  posted_at       timestamptz,
  error_detail    text,
  created_at      timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_tweets_status ON tweets(status, created_at DESC);

-- 6. push_subscriptions
CREATE TABLE IF NOT EXISTS push_subscriptions (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  endpoint        text NOT NULL UNIQUE,
  keys_p256dh     text,
  keys_auth       text,
  p256dh          text,
  auth            text,
  user_agent      text,
  device_label    text DEFAULT 'Admin Phone',
  created_at      timestamptz DEFAULT now()
);

-- 7. topic_signatures
CREATE TABLE IF NOT EXISTS topic_signatures (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  signature       text NOT NULL UNIQUE,
  first_seen_title text,
  article_generated boolean DEFAULT false,
  created_at      timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_topic_sig ON topic_signatures(signature);

-- 8. monitor_state
CREATE TABLE IF NOT EXISTS monitor_state (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  key             text UNIQUE,
  source_name     text UNIQUE,
  value           jsonb,
  last_seen_url   text,
  last_seen_date  timestamptz,
  updated_at      timestamptz DEFAULT now()
);

-- 9. content_hashes
CREATE TABLE IF NOT EXISTS content_hashes (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  hash            text NOT NULL UNIQUE,
  type            text,
  source          text,
  article_id      uuid REFERENCES articles(id) ON DELETE CASCADE,
  created_at      timestamptz DEFAULT now()
);

-- 10. historical_performance
CREATE TABLE IF NOT EXISTS historical_performance (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_name     text NOT NULL,
  circuit         text NOT NULL,
  season          int,
  race_name       text,
  team_name       text,
  position        int,
  finish_position int,
  grid_position   int,
  points          numeric,
  points_scored   int,
  laps_completed  int,
  status          text,
  avg_lap_time    numeric,
  fastest_lap     boolean,
  pit_stops       int,
  avg_pit_time    numeric,
  tyre_strategy   text,
  championship_position_after int,
  session_key     text,
  created_at      timestamptz DEFAULT now()
);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_hist_perf_unique') THEN
    CREATE UNIQUE INDEX idx_hist_perf_unique ON historical_performance(driver_name, circuit, season) WHERE season IS NOT NULL;
  END IF;
EXCEPTION WHEN others THEN NULL;
END $$;

-- 11. circuit_performance
CREATE TABLE IF NOT EXISTS circuit_performance (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  circuit         text NOT NULL,
  season          int,
  driver_name     text,
  team_name       text,
  winner_name     text,
  pole_name       text,
  fastest_lap     text,
  finish_position int,
  grid_position   int,
  dnf             boolean DEFAULT false,
  safety_cars     int,
  rain            boolean DEFAULT false,
  overtakes       int,
  created_at      timestamptz DEFAULT now()
);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_circuit_perf_unique') THEN
    CREATE UNIQUE INDEX idx_circuit_perf_unique ON circuit_performance(circuit, season) WHERE winner_name IS NOT NULL;
  END IF;
EXCEPTION WHEN others THEN NULL;
END $$;

-- 12. overtakes
CREATE TABLE IF NOT EXISTS overtakes (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  race_id         uuid REFERENCES races(id) ON DELETE CASCADE,
  session_key     int,
  date            timestamptz,
  overtaking_driver_number int,
  overtaken_driver_number  int,
  position        int,
  created_at      timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_overtakes_race ON overtakes(race_id);

-- ============================================================
-- PART 2 — ALTER EXISTING TABLES
-- ============================================================

-- A. leaderboard — add missing columns
ALTER TABLE leaderboard ADD COLUMN IF NOT EXISTS driver_number int;
ALTER TABLE leaderboard ADD COLUMN IF NOT EXISTS compound text;
ALTER TABLE leaderboard ADD COLUMN IF NOT EXISTS stint_number int;
ALTER TABLE leaderboard ADD COLUMN IF NOT EXISTS session_key text;
ALTER TABLE leaderboard ADD COLUMN IF NOT EXISTS time_str text;

-- B. content_drafts — fix defaults + add missing columns
ALTER TABLE content_drafts ALTER COLUMN generation_model SET DEFAULT 'GridFeed Pipeline';
ALTER TABLE content_drafts ADD COLUMN IF NOT EXISTS scheduled_publish_at timestamptz;
ALTER TABLE content_drafts ADD COLUMN IF NOT EXISTS priority_score int;

-- C. articles — author constraint
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'only_gridfeed_content') THEN
    ALTER TABLE articles ADD CONSTRAINT only_gridfeed_content
      CHECK (author IN ('GridFeed Staff', 'GridFeed'));
  END IF;
EXCEPTION WHEN others THEN NULL;
END $$;

-- D. tweets — add missing columns
ALTER TABLE tweets ADD COLUMN IF NOT EXISTS tweet_type text;
ALTER TABLE tweets ADD COLUMN IF NOT EXISTS scheduled_post_at timestamptz;

-- ============================================================
-- PART 3 — FIX RACES SEED DATA
-- ============================================================

-- Cancel Bahrain and Saudi
UPDATE races SET round = NULL, status = 'cancelled'
WHERE name = 'Bahrain Grand Prix' AND season = 2026;

UPDATE races SET round = NULL, status = 'cancelled'
WHERE name = 'Saudi Arabian Grand Prix' AND season = 2026;

-- Fix completed races
UPDATE races SET round = 1, status = 'completed',
  winner_name = 'George Russell', winner_team = 'Mercedes',
  race_date = '2026-03-08 05:00:00+00'
WHERE name = 'Australian Grand Prix' AND season = 2026;

UPDATE races SET round = 2, status = 'completed',
  winner_name = 'Kimi Antonelli', winner_team = 'Mercedes',
  race_date = '2026-03-15 07:00:00+00'
WHERE name = 'Chinese Grand Prix' AND season = 2026;

UPDATE races SET round = 3, status = 'completed',
  winner_name = 'Kimi Antonelli', winner_team = 'Mercedes',
  race_date = '2026-03-29 06:00:00+00'
WHERE name = 'Japanese Grand Prix' AND season = 2026;

-- Fix upcoming races
UPDATE races SET round = 4, race_date = '2026-05-03 20:00:00+00'
WHERE name = 'Miami Grand Prix' AND season = 2026;

UPDATE races SET round = 5 WHERE name = 'Canadian Grand Prix' AND season = 2026;
UPDATE races SET round = 6 WHERE name = 'Monaco Grand Prix' AND season = 2026;

-- Handle Barcelona-Catalunya / Spanish GP for round 7
UPDATE races SET round = 7
WHERE name IN ('Spanish Grand Prix', 'Barcelona Grand Prix', 'Barcelona-Catalunya GP')
AND season = 2026 AND (round IS NULL OR round != 14);

UPDATE races SET round = 8, status = 'upcoming'
WHERE name = 'Austrian Grand Prix' AND season = 2026;

UPDATE races SET round = 9, status = 'upcoming'
WHERE name = 'British Grand Prix' AND season = 2026;

UPDATE races SET round = 10 WHERE name = 'Belgian Grand Prix' AND season = 2026;
UPDATE races SET round = 11 WHERE name = 'Hungarian Grand Prix' AND season = 2026;
UPDATE races SET round = 12 WHERE name = 'Dutch Grand Prix' AND season = 2026;
UPDATE races SET round = 13 WHERE name = 'Italian Grand Prix' AND season = 2026;

-- Madrid as round 14 (new circuit)
INSERT INTO races (name, circuit, country, race_date, season, round, status)
VALUES ('Spanish Grand Prix', 'Madrid Street Circuit', 'Spain', '2026-09-13 13:00:00+00', 2026, 14, 'upcoming')
ON CONFLICT DO NOTHING;

UPDATE races SET round = 15 WHERE name = 'Azerbaijan Grand Prix' AND season = 2026;
UPDATE races SET round = 16 WHERE name = 'Singapore Grand Prix' AND season = 2026;
UPDATE races SET round = 17 WHERE name = 'United States Grand Prix' AND season = 2026;
UPDATE races SET round = 18 WHERE name = 'Mexico City Grand Prix' AND season = 2026;
UPDATE races SET round = 19 WHERE name ILIKE '%Paulo%' AND season = 2026;
UPDATE races SET round = 20 WHERE name = 'Las Vegas Grand Prix' AND season = 2026;
UPDATE races SET round = 21 WHERE name = 'Qatar Grand Prix' AND season = 2026;
UPDATE races SET round = 22 WHERE name = 'Abu Dhabi Grand Prix' AND season = 2026;

-- ============================================================
-- PART 4 — FIX DRIVER FACTS SEED
-- ============================================================

UPDATE driver_facts SET
  fact_text = 'Entering 2026 after losing the title to Norris in 2025. Red Bull pace has dropped significantly. Verstappen P9 with 12pts after 3 races.'
WHERE driver_name = 'Max Verstappen' AND category = 'form' AND season = 2026;

INSERT INTO driver_facts (driver_name, category, fact_text, season) VALUES
  ('Kimi Antonelli', 'background', 'Mercedes breakthrough star. Championship leader after 3 races with 72pts. Youngest driver to lead the standings. Back-to-back wins in China and Japan.', 2026),
  ('Kimi Antonelli', 'form', 'Current form: P2-P1-P1 in first three races. 9 points clear of teammate Russell. The defining early-season story of 2026.', 2026),
  ('Oliver Bearman', 'background', 'Haas full-time from 2025. Consistent points scorer. P7 in championship with 17pts after 3 races.', 2026),
  ('Pierre Gasly', 'background', 'Alpine lead driver. Steady top-6 finisher in 2026. P8 in standings with 15pts.', 2026),
  ('Liam Lawson', 'background', 'Racing Bulls driver. P10 with 10pts. Regular Q2 and points finisher in 2026.', 2026),
  ('Isack Hadjar', 'background', 'Red Bull second driver alongside Verstappen for 2026. Rookie season in a struggling car.', 2026),
  ('Arvid Lindblad', 'background', 'Racing Bulls rookie for 2026. Youngest driver on the grid.', 2026),
  ('Gabriel Bortoleto', 'background', 'Audi driver for 2026. Came through the F2 ranks.', 2026),
  ('Sergio Perez', 'background', 'Moved to Cadillac F1 for 2026 as the 11th team enters.', 2026),
  ('Valtteri Bottas', 'background', 'Cadillac F1 alongside Perez. Returned to the grid with the new 11th team for 2026.', 2026),
  ('Lando Norris', 'background', '2025 World Champion with McLaren. First title after breakthrough 2024. Defending his crown in 2026.', 2026)
ON CONFLICT DO NOTHING;

-- ============================================================
-- PART 5 — RLS POLICIES FOR ALL NEW TABLES
-- ============================================================

-- Public read tables
DO $$ BEGIN
  ALTER TABLE strategy ENABLE ROW LEVEL SECURITY;
  ALTER TABLE race_control ENABLE ROW LEVEL SECURITY;
  ALTER TABLE weather_data ENABLE ROW LEVEL SECURITY;
  ALTER TABLE car_locations ENABLE ROW LEVEL SECURITY;
  ALTER TABLE overtakes ENABLE ROW LEVEL SECURITY;
  ALTER TABLE historical_performance ENABLE ROW LEVEL SECURITY;
  ALTER TABLE circuit_performance ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "Public read strategy" ON strategy FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Public read race_control" ON race_control FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Public read weather_data" ON weather_data FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Public read car_locations" ON car_locations FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Public read overtakes" ON overtakes FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Public read historical_performance" ON historical_performance FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Public read circuit_performance" ON circuit_performance FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Service write policies for public tables
DO $$ BEGIN
  CREATE POLICY "Service write strategy" ON strategy FOR INSERT WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Service write race_control" ON race_control FOR INSERT WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Service write weather_data" ON weather_data FOR INSERT WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Service write car_locations" ON car_locations FOR INSERT WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Service write overtakes" ON overtakes FOR INSERT WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Service write historical_performance" ON historical_performance FOR INSERT WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Service write circuit_performance" ON circuit_performance FOR INSERT WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Service delete policies
DO $$ BEGIN
  CREATE POLICY "Service delete strategy" ON strategy FOR DELETE USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Service delete weather_data" ON weather_data FOR DELETE USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Service delete car_locations" ON car_locations FOR DELETE USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Service-only tables (no public read)
DO $$ BEGIN
  ALTER TABLE tweets ENABLE ROW LEVEL SECURITY;
  ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;
  ALTER TABLE topic_signatures ENABLE ROW LEVEL SECURITY;
  ALTER TABLE monitor_state ENABLE ROW LEVEL SECURITY;
  ALTER TABLE content_hashes ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "Service full tweets" ON tweets FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Service full push_subscriptions" ON push_subscriptions FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Service full topic_signatures" ON topic_signatures FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Service full monitor_state" ON monitor_state FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Service full content_hashes" ON content_hashes FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- PART 6 — SEED BETTING RECORD IF EMPTY
-- ============================================================

INSERT INTO betting_record (season, wins, losses, pushes, roi)
VALUES (2026, 0, 0, 0, 0)
ON CONFLICT DO NOTHING;

-- ============================================================
-- PART 7 — UPDATED_AT TRIGGER FOR MONITOR_STATE
-- ============================================================

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_monitor_state_updated_at'
  ) THEN
    CREATE TRIGGER trg_monitor_state_updated_at
      BEFORE UPDATE ON monitor_state
      FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  END IF;
EXCEPTION WHEN others THEN NULL;
END $$;

-- ============================================================
-- VERIFICATION — list all tables
-- ============================================================

SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
