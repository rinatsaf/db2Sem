CREATE INDEX IF NOT EXISTS idx_ads_geo_point_gist
ON service.ads USING gist(geo_point);

CREATE INDEX IF NOT EXISTS idx_ads_search_tsv_gist
ON service.ads USING gist(search_tsv);

CREATE INDEX IF NOT EXISTS idx_vehicles_mileage_range_gist
ON service.vehicles USING gist(mileage_range);

CREATE INDEX IF NOT EXISTS idx_ads_description_trgm_gist
ON service.ads USING gist(description gist_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_ads_header_trgm_gist
ON service.ads USING gist(header_text gist_trgm_ops);

ANALYZE service.ads;
ANALYZE service.vehicles;
