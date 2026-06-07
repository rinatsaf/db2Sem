SELECT pg_current_wal_lsn();

SELECT pg_wal_lsn_diff(
               pg_current_wal_lsn(),
               '5/141CC1A0'
       );

BEGIN;

SELECT pg_current_wal_lsn() as before_insert;

INSERT INTO role (code, name, status)
VALUES ('teacher', 'Teacher', 'ACTIVE');

SELECT pg_current_wal_lsn() as after_insert;

COMMIT;

SELECT pg_current_wal_lsn() as after_commit;

SELECT pg_wal_lsn_diff(
               '5/141CC8E0',
               '5/141CC6A8'
       );

SELECT pg_current_wal_lsn() as before_mass_insert;

INSERT INTO "user" (full_name, email, status)
SELECT
    'User ' || i,
    'user' || i || '@test2.com',
    'ACTIVE'
FROM generate_series(1, 10000) i;

SELECT pg_current_wal_lsn() as after_mass_insert;

SELECT pg_wal_lsn_diff('5/17E8F4E0', '5/166C1968');