-- Session B
-- Run this while session A is sleeping (before A commit)
SELECT 'B_while_A_open' AS marker, id, amount, xmin, xmax, ctid
FROM hw4.mvcc_lab
WHERE id = 2;

-- Wait until A commits, then run again
SELECT pg_sleep(22);

SELECT 'B_after_A_commit' AS marker, id, amount, xmin, xmax, ctid
FROM hw4.mvcc_lab
WHERE id = 2;
