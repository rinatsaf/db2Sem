-- Session A: strong row lock
BEGIN;
SELECT *
FROM hw4.mvcc_lab
WHERE id = 3
FOR UPDATE;

SELECT pg_sleep(30);
COMMIT;
