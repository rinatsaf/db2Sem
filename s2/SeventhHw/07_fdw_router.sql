\pset pager off
\echo ==== FDW ROUTER SETUP ====

CREATE EXTENSION IF NOT EXISTS postgres_fdw;

DROP SCHEMA IF EXISTS hw7_fdw CASCADE;
CREATE SCHEMA hw7_fdw;

DROP SERVER IF EXISTS hw7_shard1_srv CASCADE;
CREATE SERVER hw7_shard1_srv
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'shard1', port '5432', dbname 'postgres', use_remote_estimate 'true');

DROP SERVER IF EXISTS hw7_shard2_srv CASCADE;
CREATE SERVER hw7_shard2_srv
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'shard2', port '5432', dbname 'postgres', use_remote_estimate 'true');

CREATE USER MAPPING IF NOT EXISTS FOR postgres
SERVER hw7_shard1_srv
OPTIONS (user 'postgres', password 'postgres');

CREATE USER MAPPING IF NOT EXISTS FOR postgres
SERVER hw7_shard2_srv
OPTIONS (user 'postgres', password 'postgres');

CREATE TABLE hw7_fdw.ads_router (
    ad_id BIGINT NOT NULL,
    seller_id INTEGER NOT NULL,
    status_code TEXT NOT NULL,
    price INTEGER NOT NULL,
    publication_date DATE NOT NULL
) PARTITION BY RANGE (seller_id);

CREATE FOREIGN TABLE hw7_fdw.ads_shard1
    PARTITION OF hw7_fdw.ads_router
    FOR VALUES FROM (1) TO (500)
    SERVER hw7_shard1_srv
    OPTIONS (schema_name 'hw7_fdw', table_name 'ads_shard');

CREATE FOREIGN TABLE hw7_fdw.ads_shard2
    PARTITION OF hw7_fdw.ads_router
    FOR VALUES FROM (500) TO (1000)
    SERVER hw7_shard2_srv
    OPTIONS (schema_name 'hw7_fdw', table_name 'ads_shard');

\echo
\echo ==== QUERY 1: all data ====
\echo Expected: both shards participate in the plan
EXPLAIN (VERBOSE, COSTS OFF)
SELECT count(*)
FROM hw7_fdw.ads_router;

\echo
\echo ==== QUERY 2: one shard ====
\echo Expected: partition pruning, only shard1 participates
EXPLAIN (VERBOSE, COSTS OFF)
SELECT *
FROM hw7_fdw.ads_router
WHERE seller_id = 150;

\echo
\echo ==== QUERY 3: one shard ====
\echo Expected: partition pruning, only shard2 participates
EXPLAIN (VERBOSE, COSTS OFF)
SELECT *
FROM hw7_fdw.ads_router
WHERE seller_id = 650;
