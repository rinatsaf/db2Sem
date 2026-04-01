\pset pager off
\echo ==== LOGICAL SUBSCRIBER SETUP ====

DROP SCHEMA IF EXISTS hw7_logical CASCADE;
CREATE SCHEMA hw7_logical;

CREATE TABLE hw7_logical.ads_pub_off_root (
    ad_id BIGINT NOT NULL,
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

CREATE TABLE hw7_logical.ads_pub_on_root (
    ad_id BIGINT PRIMARY KEY,
    seller_id INTEGER NOT NULL,
    status_code TEXT NOT NULL,
    price INTEGER NOT NULL,
    publication_date DATE NOT NULL
);

DROP SUBSCRIPTION IF EXISTS hw7_sub_off;
CREATE SUBSCRIPTION hw7_sub_off
CONNECTION 'host=logical_pub port=5432 dbname=postgres user=postgres password=postgres'
PUBLICATION hw7_pub_off
WITH (copy_data = false, create_slot = true, slot_name = 'hw7_sub_off_slot', enabled = true);

DROP SUBSCRIPTION IF EXISTS hw7_sub_on;
CREATE SUBSCRIPTION hw7_sub_on
CONNECTION 'host=logical_pub port=5432 dbname=postgres user=postgres password=postgres'
PUBLICATION hw7_pub_on
WITH (copy_data = false, create_slot = true, slot_name = 'hw7_sub_on_slot', enabled = true);

\echo
\echo ==== subscriber summary ====
SELECT subname, subenabled, subslotname
FROM pg_subscription
WHERE subname IN ('hw7_sub_off', 'hw7_sub_on')
ORDER BY subname;

SELECT
'OFF: subscriber should keep the same leaf partition names. ON: subscriber can store data in a regular table with the root table name.' AS conclusion;
