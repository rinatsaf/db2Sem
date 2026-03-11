-- Session B: will conflict with Session A FOR UPDATE
BEGIN;
SELECT *
FROM hw4.mvcc_lab
WHERE id = 3
FOR NO KEY UPDATE;

COMMIT;
