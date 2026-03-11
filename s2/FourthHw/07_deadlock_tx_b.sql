-- Session B (deadlock)
BEGIN;
UPDATE hw4.mvcc_lab SET amount = amount + 1 WHERE id = 2;

-- give session A time to request row id=2
SELECT pg_sleep(3);

-- this creates deadlock cycle with session A
UPDATE hw4.mvcc_lab SET amount = amount + 1 WHERE id = 1;

COMMIT;
