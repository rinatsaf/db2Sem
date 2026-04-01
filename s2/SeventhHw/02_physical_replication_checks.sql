\pset pager off
\echo ==== PHYSICAL REPLICATION CHECKS ====

SELECT current_user AS role_name;
SELECT inet_server_addr() AS server_addr, inet_server_port() AS server_port;
SELECT pg_is_in_recovery() AS is_replica;

\echo
\echo ==== partitioned roots ====
SELECT
    partrelid::regclass AS partitioned_table,
    partstrat,
    partnatts
FROM pg_partitioned_table
WHERE partrelid::regclass::text LIKE 'hw7_partition.%'
ORDER BY 1;

\echo
\echo ==== range tree ====
SELECT * FROM pg_partition_tree('hw7_partition.ads_range');

\echo
\echo ==== list tree ====
SELECT * FROM pg_partition_tree('hw7_partition.ads_list');

\echo
\echo ==== hash tree ====
SELECT * FROM pg_partition_tree('hw7_partition.ads_hash');

\echo
\echo ==== short conclusion ====
SELECT
'Physical replication replays WAL records, therefore catalog/table/partition metadata is copied as-is from primary to replica. Standby does not decide partition routing itself; it simply replays already recorded changes.' AS conclusion;
