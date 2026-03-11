CREATE INDEX IF NOT EXISTS idx_ads_search_tsv_gin
ON service.ads USING gin(search_tsv);

CREATE INDEX IF NOT EXISTS idx_vehicles_features_gin
ON service.vehicles USING gin(features);

CREATE INDEX IF NOT EXISTS idx_users_profile_json_gin
ON service.users USING gin(profile_json jsonb_path_ops);

CREATE INDEX IF NOT EXISTS idx_ads_header_trgm_gin
ON service.ads USING gin(header_text gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_ads_description_trgm_gin
ON service.ads USING gin(description gin_trgm_ops);

ANALYZE service.ads;
ANALYZE service.vehicles;
ANALYZE service.users;
