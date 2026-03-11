-- Session A: table lock holder
BEGIN;
LOCK TABLE hw4.mvcc_lab IN SHARE MODE;

-- keep transaction open
SELECT pg_sleep(30);

COMMIT;
