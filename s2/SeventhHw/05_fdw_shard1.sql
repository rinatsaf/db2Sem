\pset pager off
\echo ==== FDW SHARD1 SETUP ====

DROP SCHEMA IF EXISTS hw7_fdw CASCADE;
CREATE SCHEMA hw7_fdw;

CREATE TABLE hw7_fdw.ads_shard (
    ad_id BIGINT PRIMARY KEY,
    seller_id INTEGER NOT NULL,
    status_code TEXT NOT NULL,
    price INTEGER NOT NULL,
    publication_date DATE NOT NULL,
    CHECK (seller_id >= 1 AND seller_id < 500)
);

CREATE INDEX ads_shard_seller_idx ON hw7_fdw.ads_shard (seller_id);

INSERT INTO hw7_fdw.ads_shard(ad_id, seller_id, status_code, price, publication_date)
SELECT
    gs,
    gs,
    CASE WHEN gs % 2 = 0 THEN 'active' ELSE 'sold' END,
    100000 + gs,
    DATE '2025-01-01' + (gs % 20)
FROM generate_series(1, 499) AS gs
ON CONFLICT (ad_id) DO NOTHING;

ANALYZE hw7_fdw.ads_shard;

\echo
\echo Local plan on shard1: index usage expected
EXPLAIN (ANALYZE, VERBOSE, COSTS OFF, SUMMARY OFF, BUFFERS)
SELECT *
FROM hw7_fdw.ads_shard
WHERE seller_id = 150;
