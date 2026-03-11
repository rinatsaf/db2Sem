-- Session B: conflicting request against SHARE lock
BEGIN;
LOCK TABLE hw4.mvcc_lab IN ROW EXCLUSIVE MODE;

-- This lock request should wait until session A commits
SELECT now() AS lock_granted_at;
COMMIT;
