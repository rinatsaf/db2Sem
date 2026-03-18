-- LSN до/после одиночного INSERT
\pset pager off
\echo '--- capture LSN before insert'
SELECT pg_current_wal_lsn() AS lsn_before \gset

INSERT INTO wal_lab.events(label, payload)
VALUES (
    'insert_demo_' || to_char(clock_timestamp(), 'YYYYMMDD_HH24MISSMS'),
    jsonb_build_object('ts', clock_timestamp())
);

\echo '--- capture LSN after insert'
SELECT pg_current_wal_lsn() AS lsn_after_insert \gset

\echo '--- summary'
SELECT :'lsn_before'      AS lsn_before,
       :'lsn_after_insert' AS lsn_after_insert,
       pg_wal_lsn_diff(:'lsn_after_insert', :'lsn_before') AS wal_bytes_insert,
       pg_walfile_name(:'lsn_before') AS wal_file_before,
       pg_walfile_name(:'lsn_after_insert') AS wal_file_after;
