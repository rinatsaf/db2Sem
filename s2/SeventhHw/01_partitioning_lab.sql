\pset pager off
\echo ==== HW7 PARTITIONING LAB ====

DROP SCHEMA IF EXISTS hw7_partition CASCADE;
CREATE SCHEMA hw7_partition;

CREATE TABLE hw7_partition.ads_range (
    ad_id BIGINT GENERATED ALWAYS AS IDENTITY,
    seller_id INTEGER NOT NULL,
    status_code TEXT NOT NULL,
    price INTEGER NOT NULL,
    publication_date DATE NOT NULL,
    title TEXT NOT NULL,
    PRIMARY KEY (ad_id, publication_date)
) PARTITION BY RANGE (publication_date);

CREATE TABLE hw7_partition.ads_range_2025_01
    PARTITION OF hw7_partition.ads_range
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE hw7_partition.ads_range_2025_02
    PARTITION OF hw7_partition.ads_range
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

CREATE TABLE hw7_partition.ads_range_2025_03
    PARTITION OF hw7_partition.ads_range
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');

CREATE TABLE hw7_partition.ads_range_2025_04
    PARTITION OF hw7_partition.ads_range
    FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');

CREATE INDEX ON hw7_partition.ads_range_2025_01 (publication_date, seller_id);
CREATE INDEX ON hw7_partition.ads_range_2025_02 (publication_date, seller_id);
CREATE INDEX ON hw7_partition.ads_range_2025_03 (publication_date, seller_id);
CREATE INDEX ON hw7_partition.ads_range_2025_04 (publication_date, seller_id);

INSERT INTO hw7_partition.ads_range (seller_id, status_code, price, publication_date, title)
SELECT
    (gs % 200) + 1,
    (ARRAY['active', 'sold', 'in_processing'])[1 + (gs % 3)],
    500000 + gs * 10,
    DATE '2025-01-01' + ((gs - 1) % 120),
    'range ad #' || gs
FROM generate_series(1, 12000) AS gs;

CREATE TABLE hw7_partition.ads_list (
    ad_id BIGINT GENERATED ALWAYS AS IDENTITY,
    seller_id INTEGER NOT NULL,
    status_code TEXT NOT NULL,
    price INTEGER NOT NULL,
    publication_date DATE NOT NULL,
    title TEXT NOT NULL
) PARTITION BY LIST (status_code);

CREATE TABLE hw7_partition.ads_list_active
    PARTITION OF hw7_partition.ads_list
    FOR VALUES IN ('active');

CREATE TABLE hw7_partition.ads_list_sold
    PARTITION OF hw7_partition.ads_list
    FOR VALUES IN ('sold');

CREATE TABLE hw7_partition.ads_list_processing
    PARTITION OF hw7_partition.ads_list
    FOR VALUES IN ('in_processing');

CREATE INDEX ON hw7_partition.ads_list_active (seller_id);
CREATE INDEX ON hw7_partition.ads_list_sold (seller_id);
CREATE INDEX ON hw7_partition.ads_list_processing (seller_id);

INSERT INTO hw7_partition.ads_list (seller_id, status_code, price, publication_date, title)
SELECT
    (gs % 300) + 1,
    CASE
        WHEN gs % 3 = 0 THEN 'active'
        WHEN gs % 3 = 1 THEN 'sold'
        ELSE 'in_processing'
    END,
    700000 + gs * 5,
    DATE '2025-01-01' + (gs % 30),
    'list ad #' || gs
FROM generate_series(1, 9000) AS gs;

CREATE TABLE hw7_partition.ads_hash (
    ad_id BIGINT GENERATED ALWAYS AS IDENTITY,
    seller_id INTEGER NOT NULL,
    status_code TEXT NOT NULL,
    price INTEGER NOT NULL,
    publication_date DATE NOT NULL,
    title TEXT NOT NULL
) PARTITION BY HASH (seller_id);

CREATE TABLE hw7_partition.ads_hash_p0
    PARTITION OF hw7_partition.ads_hash
    FOR VALUES WITH (MODULUS 4, REMAINDER 0);

CREATE TABLE hw7_partition.ads_hash_p1
    PARTITION OF hw7_partition.ads_hash
    FOR VALUES WITH (MODULUS 4, REMAINDER 1);

CREATE TABLE hw7_partition.ads_hash_p2
    PARTITION OF hw7_partition.ads_hash
    FOR VALUES WITH (MODULUS 4, REMAINDER 2);

CREATE TABLE hw7_partition.ads_hash_p3
    PARTITION OF hw7_partition.ads_hash
    FOR VALUES WITH (MODULUS 4, REMAINDER 3);

CREATE INDEX ON hw7_partition.ads_hash_p0 (seller_id);
CREATE INDEX ON hw7_partition.ads_hash_p1 (seller_id);
CREATE INDEX ON hw7_partition.ads_hash_p2 (seller_id);
CREATE INDEX ON hw7_partition.ads_hash_p3 (seller_id);

INSERT INTO hw7_partition.ads_hash (seller_id, status_code, price, publication_date, title)
SELECT
    (gs % 500) + 1,
    (ARRAY['active', 'sold'])[1 + (gs % 2)],
    900000 + gs,
    DATE '2025-02-01' + (gs % 20),
    'hash ad #' || gs
FROM generate_series(1, 10000) AS gs;

ANALYZE hw7_partition.ads_range;
ANALYZE hw7_partition.ads_list;
ANALYZE hw7_partition.ads_hash;

\echo
\echo ==== RANGE: one month ====
\echo Query: publication_date in [2025-03-01, 2025-04-01)
\echo Answer: pruning = yes; partitions in plan = 1; index = yes
EXPLAIN (ANALYZE, VERBOSE, COSTS OFF, SUMMARY OFF, BUFFERS)
SELECT ad_id, seller_id, price
FROM hw7_partition.ads_range
WHERE publication_date = DATE '2025-03-15'
  AND seller_id = 42;

\echo
\echo ==== LIST: status active ====
\echo Query: status_code = active and seller_id = 120
\echo Answer: pruning = yes; partitions in plan = 1; index = yes
EXPLAIN (ANALYZE, VERBOSE, COSTS OFF, SUMMARY OFF, BUFFERS)
SELECT ad_id, seller_id, price
FROM hw7_partition.ads_list
WHERE status_code = 'active'
  AND seller_id = 120;

\echo
\echo ==== HASH: seller equality ====
\echo Query: seller_id = 42
\echo Answer: pruning = yes; partitions in plan = 1; index = yes
EXPLAIN (ANALYZE, VERBOSE, COSTS OFF, SUMMARY OFF, BUFFERS)
SELECT ad_id, seller_id, price
FROM hw7_partition.ads_hash
WHERE seller_id = 42;

\echo
\echo ==== Partition trees ====
SELECT 'ads_range' AS table_name, * FROM pg_partition_tree('hw7_partition.ads_range');
SELECT 'ads_list' AS table_name, * FROM pg_partition_tree('hw7_partition.ads_list');
SELECT 'ads_hash' AS table_name, * FROM pg_partition_tree('hw7_partition.ads_hash');
