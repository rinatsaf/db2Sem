-- Session C: FOR KEY SHARE is weaker and is compatible with FOR NO KEY UPDATE,
-- but conflicts with FOR UPDATE. Start this while Session A is still open.
BEGIN;
SELECT *
FROM hw4.mvcc_lab
WHERE id = 3
FOR KEY SHARE;

COMMIT;
