-- Массовая вставка и оценка объёма WAL
\pset pager off
-- Можно переопределить при запуске: psql -v bulk_rows=20000 -f 04_wal_size_mass.sql
\set bulk_rows 5000

TRUNCATE wal_lab.bulk_demo;

SELECT pg_current_wal_lsn() AS lsn_before_bulk \gset

INSERT INTO wal_lab.bulk_demo(note)
SELECT 'bulk_row_' || gs
FROM generate_series(1, :bulk_rows) AS gs;

SELECT pg_current_wal_lsn() AS lsn_after_bulk \gset

SELECT CAST(:'bulk_rows' AS INTEGER) AS inserted_rows,
       :'lsn_before_bulk' AS lsn_before_bulk,
       :'lsn_after_bulk'  AS lsn_after_bulk,
       pg_wal_lsn_diff(:'lsn_after_bulk', :'lsn_before_bulk') AS wal_bytes_bulk,
       pg_wal_lsn_diff(:'lsn_after_bulk', :'lsn_before_bulk') / CAST(:'bulk_rows' AS NUMERIC) AS wal_bytes_per_row,
       pg_walfile_name(:'lsn_before_bulk') AS wal_file_before,
       pg_walfile_name(:'lsn_after_bulk')  AS wal_file_after;
