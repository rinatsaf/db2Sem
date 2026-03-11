-- GiST #1: point inside circle
EXPLAIN (ANALYZE, BUFFERS)
SELECT ad_id, header_text, geo_point
FROM service.ads
WHERE geo_point <@ circle(point(58, 40), 5);

-- Compare with manual distance check
EXPLAIN (ANALYZE, BUFFERS)
SELECT ad_id, header_text, geo_point
FROM service.ads
WHERE (power((geo_point)[0] - 58, 2) + power((geo_point)[1] - 40, 2)) <= 25;

-- GiST #2: point inside box
EXPLAIN (ANALYZE, BUFFERS)
SELECT ad_id, geo_point
FROM service.ads
WHERE geo_point <@ box(point(60, 42), point(56, 38));

-- Compare with BETWEEN on coordinates
EXPLAIN (ANALYZE, BUFFERS)
SELECT ad_id, geo_point
FROM service.ads
WHERE (geo_point)[0] BETWEEN 56 AND 60
  AND (geo_point)[1] BETWEEN 38 AND 42;

-- GiST #3: full text with GiST index
EXPLAIN (ANALYZE, BUFFERS)
SELECT ad_id, header_text
FROM service.ads
WHERE search_tsv @@ to_tsquery('simple', 'owner | urgent');

-- Compare with trigram match by text
EXPLAIN (ANALYZE, BUFFERS)
SELECT ad_id, header_text
FROM service.ads
WHERE description ILIKE '%owner%' OR description ILIKE '%urgent%';

-- GiST #4: range overlap
EXPLAIN (ANALYZE, BUFFERS)
SELECT vehicle_id, brand, mileage_range
FROM service.vehicles
WHERE mileage_range && int4range(30000, 90000, '[]');

-- Compare with scalar interval check
EXPLAIN (ANALYZE, BUFFERS)
SELECT v.vehicle_id, v.brand, ml.mileage_km
FROM service.vehicles v
JOIN service.mileage_log ml ON ml.vehicle_id = v.vehicle_id
WHERE ml.mileage_km BETWEEN 30000 AND 90000;

-- GiST #5: trigram distance (KNN)
EXPLAIN (ANALYZE, BUFFERS)
SELECT ad_id, header_text
FROM service.ads
ORDER BY header_text <-> 'toyota camry'
LIMIT 5;

-- Compare with regular sort after filter
EXPLAIN (ANALYZE, BUFFERS)
SELECT ad_id, header_text
FROM service.ads
WHERE header_text ILIKE '%toyota%'
ORDER BY ad_id
LIMIT 5;
