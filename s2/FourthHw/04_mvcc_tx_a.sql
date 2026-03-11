-- Session A
BEGIN;
UPDATE hw4.mvcc_lab
SET amount = amount + 100
WHERE id = 2;

SELECT 'A_before_commit' AS marker, id, amount, xmin, xmax, ctid
FROM hw4.mvcc_lab
WHERE id = 2;

-- keep tx open for Session B checks
SELECT pg_sleep(20);

COMMIT;

SELECT 'A_after_commit' AS marker, id, amount, xmin, xmax, ctid
FROM hw4.mvcc_lab
WHERE id = 2;
