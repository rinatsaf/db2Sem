-- GIN #1: full text operator @@ (index-friendly)
EXPLAIN (ANALYZE, BUFFERS)
SELECT ad_id, header_text
FROM service.ads
WHERE search_tsv @@ plainto_tsquery('simple', 'toyota');

-- Compare with non-index string search
EXPLAIN (ANALYZE, BUFFERS)
SELECT ad_id, header_text
FROM service.ads
WHERE lower(header_text) LIKE '%toyota%';

-- GIN #2: array overlap operator &&
EXPLAIN (ANALYZE, BUFFERS)
SELECT vehicle_id, brand, model, features
FROM service.vehicles
WHERE features && ARRAY['bluetooth', 'abs'];

-- Compare with unnest-based filter
EXPLAIN (ANALYZE, BUFFERS)
SELECT v.vehicle_id, v.brand, v.model, v.features
FROM service.vehicles v
WHERE EXISTS (
  SELECT 1
  FROM unnest(v.features) f
  WHERE f IN ('bluetooth', 'abs')
);

-- GIN #3: JSONB containment @>
EXPLAIN (ANALYZE, BUFFERS)
SELECT user_id, full_name, profile_json
FROM service.users
WHERE profile_json @> '{"marketing": true}';

-- Compare with expression extraction
EXPLAIN (ANALYZE, BUFFERS)
SELECT user_id, full_name, profile_json
FROM service.users
WHERE (profile_json ->> 'marketing')::boolean = true;

-- GIN #4: trigram similarity operator %
SET pg_trgm.similarity_threshold = 0.2;
EXPLAIN (ANALYZE, BUFFERS)
SELECT ad_id, header_text
FROM service.ads
WHERE header_text % 'tesla model';

-- Compare with wildcard ILIKE
EXPLAIN (ANALYZE, BUFFERS)
SELECT ad_id, header_text
FROM service.ads
WHERE header_text ILIKE '%tesla%model%';

-- GIN #5: array contains @>
EXPLAIN (ANALYZE, BUFFERS)
SELECT vehicle_id, brand, model, features
FROM service.vehicles
WHERE features @> ARRAY['abs', 'esp'];

-- Compare with chained ANY
EXPLAIN (ANALYZE, BUFFERS)
SELECT vehicle_id, brand, model, features
FROM service.vehicles
WHERE 'abs' = ANY(features)
  AND 'esp' = ANY(features);
