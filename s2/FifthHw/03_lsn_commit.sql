-- LSN до/после COMMIT в одной транзакции
\pset pager off
\echo '--- open transaction'
BEGIN;
SELECT pg_current_wal_lsn() AS lsn_before_tx \gset

INSERT INTO wal_lab.events(label, payload)
VALUES (
    'commit_demo_' || to_char(clock_timestamp(), 'YYYYMMDD_HH24MISSMS'),
    jsonb_build_object('ts', clock_timestamp())
);

\echo '--- still inside tx, after INSERT'
SELECT pg_current_wal_lsn() AS lsn_after_insert \gset

\echo '--- commit'
COMMIT;
SELECT pg_current_wal_lsn() AS lsn_after_commit \gset

\echo '--- summary'
SELECT :'lsn_before_tx'      AS lsn_before_tx,
       :'lsn_after_insert'   AS lsn_after_insert,
       :'lsn_after_commit'   AS lsn_after_commit,
       pg_wal_lsn_diff(:'lsn_after_insert', :'lsn_before_tx') AS wal_bytes_inside_tx,
       pg_wal_lsn_diff(:'lsn_after_commit', :'lsn_after_insert') AS wal_bytes_commit_only,
       pg_wal_lsn_diff(:'lsn_after_commit', :'lsn_before_tx') AS wal_bytes_total;
