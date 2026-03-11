-- Session A (deadlock)
BEGIN;
UPDATE hw4.mvcc_lab SET amount = amount + 1 WHERE id = 1;

-- give session B time to lock row id=2
SELECT pg_sleep(3);

-- this will wait on session B
UPDATE hw4.mvcc_lab SET amount = amount + 1 WHERE id = 2;

COMMIT;
