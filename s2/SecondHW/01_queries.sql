EXPLAIN (ANALYZE, BUFFERS)
SELECT ad_id, price, status_id
FROM service.ads
WHERE price > 2000000
  AND status_id IN (1, 2);

EXPLAIN (ANALYZE, BUFFERS)
SELECT ad_id, price
FROM service.ads
WHERE price < 50000;

EXPLAIN (ANALYZE, BUFFERS)
SELECT ad_id, price
FROM service.ads
WHERE price = 1000000;

EXPLAIN (ANALYZE, BUFFERS)
SELECT ad_id, header_text
FROM service.ads
WHERE header_text LIKE '%car #12%';

EXPLAIN (ANALYZE, BUFFERS)
SELECT ad_id, header_text
FROM service.ads
WHERE header_text LIKE 'Selling car #12%';
