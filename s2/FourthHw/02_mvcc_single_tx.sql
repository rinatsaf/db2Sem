-- 1) Initial tuple headers
SELECT id, note, amount, xmin, xmax, ctid
FROM hw4.mvcc_lab
WHERE id = 1;

-- 2) Update row in one transaction
BEGIN;
UPDATE hw4.mvcc_lab
SET amount = amount + 10,
    updated_at = now()
WHERE id = 1;

-- 3) Check headers after UPDATE, before COMMIT
SELECT id, note, amount, xmin, xmax, ctid
FROM hw4.mvcc_lab
WHERE id = 1;

COMMIT;

-- 4) Check headers after COMMIT
SELECT id, note, amount, xmin, xmax, ctid
FROM hw4.mvcc_lab
WHERE id = 1;
