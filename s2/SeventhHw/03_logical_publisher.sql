\pset pager off
\echo ==== LOGICAL PUBLISHER SETUP ====

DROP SCHEMA IF EXISTS hw7_logical CASCADE;
CREATE SCHEMA hw7_logical;

CREATE TABLE hw7_logical.ads_pub_off_root (
    ad_id BIGINT GENERATED ALWAYS AS IDENTITY,
    seller_id INTEGER NOT NULL,
    status_code TEXT NOT NULL,
    price INTEGER NOT NULL,
    publication_date DATE NOT NULL,
    PRIMARY KEY (ad_id, status_code)
) PARTITION BY LIST (status_code);

CREATE TABLE hw7_logical.ads_pub_off_active
    PARTITION OF hw7_logical.ads_pub_off_root
    FOR VALUES IN ('active');

CREATE TABLE hw7_logical.ads_pub_off_sold
    PARTITION OF hw7_logical.ads_pub_off_root
    FOR VALUES IN ('sold');

ALTER TABLE hw7_logical.ads_pub_off_root REPLICA IDENTITY FULL;
ALTER TABLE hw7_logical.ads_pub_off_active REPLICA IDENTITY FULL;
ALTER TABLE hw7_logical.ads_pub_off_sold REPLICA IDENTITY FULL;

CREATE TABLE hw7_logical.ads_pub_on_root (
    ad_id BIGINT GENERATED ALWAYS AS IDENTITY,
    seller_id INTEGER NOT NULL,
    status_code TEXT NOT NULL,
    price INTEGER NOT NULL,
    publication_date DATE NOT NULL
) PARTITION BY LIST (status_code);

CREATE TABLE hw7_logical.ads_pub_on_active
    PARTITION OF hw7_logical.ads_pub_on_root
    FOR VALUES IN ('active');

CREATE TABLE hw7_logical.ads_pub_on_sold
    PARTITION OF hw7_logical.ads_pub_on_root
    FOR VALUES IN ('sold');

ALTER TABLE hw7_logical.ads_pub_on_root REPLICA IDENTITY FULL;
ALTER TABLE hw7_logical.ads_pub_on_active REPLICA IDENTITY FULL;
ALTER TABLE hw7_logical.ads_pub_on_sold REPLICA IDENTITY FULL;

DROP PUBLICATION IF EXISTS hw7_pub_off;
CREATE PUBLICATION hw7_pub_off
    FOR TABLE hw7_logical.ads_pub_off_root
    WITH (publish_via_partition_root = false);

DROP PUBLICATION IF EXISTS hw7_pub_on;
CREATE PUBLICATION hw7_pub_on
    FOR TABLE hw7_logical.ads_pub_on_root
    WITH (publish_via_partition_root = true);

\echo
\echo ==== publisher summary ====
SELECT pubname, puballtables, pubviaroot
FROM pg_publication
WHERE pubname IN ('hw7_pub_off', 'hw7_pub_on')
ORDER BY pubname;

SELECT
'publish_via_partition_root = false publishes changes using leaf partition identity; true publishes them using root table identity.' AS conclusion;
