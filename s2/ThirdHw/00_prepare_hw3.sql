-- Prepare extra columns required for GIN/GiST homework.
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

ALTER TABLE service.ads
  ADD COLUMN IF NOT EXISTS search_tsv tsvector GENERATED ALWAYS AS (
    to_tsvector('simple', coalesce(header_text, '') || ' ' || coalesce(description, ''))
  ) STORED;

ALTER TABLE service.ads
  ADD COLUMN IF NOT EXISTS geo_point point;

ALTER TABLE service.vehicles
  ADD COLUMN IF NOT EXISTS features text[] DEFAULT ARRAY[]::text[];

ALTER TABLE service.users
  ADD COLUMN IF NOT EXISTS profile_json jsonb DEFAULT '{}'::jsonb;

ALTER TABLE service.vehicles
  ADD COLUMN IF NOT EXISTS mileage_range int4range;

UPDATE service.ads
SET geo_point = point(55 + (ad_id % 10), 37 + ((ad_id % 10) * 0.1))
WHERE geo_point IS NULL;

UPDATE service.vehicles
SET features = CASE
  WHEN vehicle_id % 5 = 0 THEN ARRAY['abs','esp','heated_seats']
  WHEN vehicle_id % 5 = 1 THEN ARRAY['bluetooth','abs','camera']
  WHEN vehicle_id % 5 = 2 THEN ARRAY['cruise_control','esp','sensors']
  WHEN vehicle_id % 5 = 3 THEN ARRAY['bluetooth','navigation','autopilot']
  ELSE ARRAY['4wd','tow_bar','abs']
END
WHERE features IS NULL OR cardinality(features) = 0;

UPDATE service.users
SET profile_json = jsonb_build_object(
  'marketing', (user_id % 2 = 0),
  'telegram', '@user' || user_id,
  'verified', (user_id % 3 = 0)
)
WHERE profile_json IS NULL OR profile_json = '{}'::jsonb;

WITH mileage AS (
  SELECT vehicle_id, coalesce(max(mileage_km), 0) AS max_km
  FROM service.mileage_log
  GROUP BY vehicle_id
)
UPDATE service.vehicles v
SET mileage_range = int4range(
  greatest(0, coalesce(m.max_km, 0) - 10000),
  coalesce(m.max_km, 0) + 10000,
  '[]'
)
FROM mileage m
WHERE v.vehicle_id = m.vehicle_id
  AND v.mileage_range IS NULL;

UPDATE service.vehicles
SET mileage_range = int4range(0, 10000, '[]')
WHERE mileage_range IS NULL;

ANALYZE service.ads;
ANALYZE service.vehicles;
ANALYZE service.users;
