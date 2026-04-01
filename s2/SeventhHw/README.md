# HW7 - partitioning, replication, logical replication, FDW sharding

Папка содержит самостоятельный стенд под 7 ДЗ:
- `RANGE / LIST / HASH` секционирование с `EXPLAIN`.
- проверка секционирования на физической реплике.
- логическая репликация и `publish_via_partition_root = on / off`.
- шардирование через `postgres_fdw`: 2 shard + 1 router.

## Что внутри
- `docker-compose.yml` - поднимает 7 контейнеров:
  - `hw7_primary`
  - `hw7_replica`
  - `hw7_logical_pub`
  - `hw7_logical_sub`
  - `hw7_shard1`
  - `hw7_shard2`
  - `hw7_router`
- `scripts/init-replica.sh` - старт standby через `pg_basebackup`.
- `01_partitioning_lab.sql` - RANGE / LIST / HASH, данные, индексы, `EXPLAIN`, ответы.
- `02_physical_replication_checks.sql` - проверки на primary/replica и короткий вывод по физической репликации.
- `03_logical_publisher.sql` - publisher для `publish_via_partition_root = off / on`.
- `04_logical_subscriber.sql` - subscriber и запросы для проверки результата.
- `05_fdw_shard1.sql` - подготовка первого шарда.
- `06_fdw_shard2.sql` - подготовка второго шарда.
- `07_fdw_router.sql` - router на `postgres_fdw` и планы запросов.

## Важно
- В этой среде Docker сейчас недоступен, поэтому файлы подготовлены, но контейнеры отсюда не были подняты.
- Перед стартом стенда лучше сделать чистый запуск:

```powershell
cd c:\Users\Doom\Desktop\бд\db2Sem\s2\SeventhHw
docker compose down -v
docker compose up -d
```

## 1) Секционирование RANGE / LIST / HASH

Запуск:

```powershell
Get-Content -Raw .\01_partitioning_lab.sql | docker exec -i hw7_primary psql -U postgres -d postgres -v ON_ERROR_STOP=1
```

Что смотреть:
- Для `RANGE`: запрос по одному месяцу, ожидается `partition pruning`, 1 партиция, локальный индекс используется.
- Для `LIST`: запрос по `status_code = 'active'`, ожидается `partition pruning`, 1 партиция, локальный индекс используется.
- Для `HASH`: запрос по `seller_id = 42`, ожидается `partition pruning`, 1 hash-партиция, локальный индекс используется.

В самом SQL уже есть:
- запрос;
- `EXPLAIN (ANALYZE, VERBOSE, COSTS OFF, SUMMARY OFF, BUFFERS)`;
- короткий ответ по `pruning / partitions / index`.

## 2) Секционирование и физическая репликация

Проверки:

```powershell
Get-Content -Raw .\02_physical_replication_checks.sql | docker exec -i hw7_primary psql -U postgres -d postgres -v ON_ERROR_STOP=1
Get-Content -Raw .\02_physical_replication_checks.sql | docker exec -i hw7_replica psql -U postgres -d postgres -v ON_ERROR_STOP=1
```

Что должно получиться:
- дерево секций на `hw7_partition.ads_range`, `ads_list`, `ads_hash` видно и на primary, и на replica;
- на replica `pg_is_in_recovery()` должно вернуть `true`.

Короткий ответ на вопрос "почему репликация не знает про секции":
- физическая репликация передает WAL и воспроизводит низкоуровневые изменения страниц/каталога;
- standby не "маршрутизирует" строки по секциям самостоятельно;
- все решения о том, в какую секцию попадет строка, уже приняты на primary и зафиксированы в WAL.

## 3) Логическая репликация и `publish_via_partition_root`

Publisher:

```powershell
Get-Content -Raw .\03_logical_publisher.sql | docker exec -i hw7_logical_pub psql -U postgres -d postgres -v ON_ERROR_STOP=1
```

Subscriber:

```powershell
Get-Content -Raw .\04_logical_subscriber.sql | docker exec -i hw7_logical_sub psql -U postgres -d postgres -v ON_ERROR_STOP=1
```

Проверка:
- `publish_via_partition_root = off`:
  - изменения публикуются от имени leaf-partitions;
  - удобнее, когда у subscriber такая же partition-структура.
- `publish_via_partition_root = on`:
  - изменения публикуются от имени root table;
  - удобно реплицировать в таблицу без той же самой структуры секций.

После запуска можно вставить строки на publisher:

```powershell
docker exec -i hw7_logical_pub psql -U postgres -d postgres -c "INSERT INTO hw7_logical.ads_pub_off_root(seller_id,status_code,price,publication_date) VALUES (1,'active',100000,DATE '2025-01-10'), (2,'sold',90000,DATE '2025-01-11');"
docker exec -i hw7_logical_pub psql -U postgres -d postgres -c "INSERT INTO hw7_logical.ads_pub_on_root(seller_id,status_code,price,publication_date) VALUES (10,'active',200000,DATE '2025-02-01'), (20,'sold',150000,DATE '2025-02-02');"
```

Потом проверить subscriber:

```powershell
docker exec -i hw7_logical_sub psql -U postgres -d postgres -c "TABLE hw7_logical.ads_pub_off_root;"
docker exec -i hw7_logical_sub psql -U postgres -d postgres -c "TABLE hw7_logical.ads_pub_on_root;"
```

## 4) Шардирование через `postgres_fdw`

Подготовка shard1, shard2 и router:

```powershell
docker exec -i hw7_shard1 psql -U postgres -d postgres -f /workspace/05_fdw_shard1.sql
docker exec -i hw7_shard2 psql -U postgres -d postgres -f /workspace/06_fdw_shard2.sql
docker exec -i hw7_router psql -U postgres -d postgres -f /workspace/07_fdw_router.sql
```

Что смотреть:
- простой запрос на все данные:
  - в плане будут участвовать оба шарда;
  - обычно это `Append`/`Foreign Scan` по двум foreign partitions.
- простой запрос на один shard:
  - `WHERE seller_id = 150` пойдет только в shard1;
  - `WHERE seller_id = 650` пойдет только в shard2;
  - за счет partition pruning router обращается к одной foreign partition.

## Источники
- PostgreSQL docs, `CREATE PUBLICATION`: `publish_via_partition_root` и поведение partitioned tables
  - https://www.postgresql.org/docs/16/sql-createpublication.html
- PostgreSQL docs, logical replication publication
  - https://www.postgresql.org/docs/current/logical-replication-publication.html
- PostgreSQL docs, streaming replication protocol
  - https://www.postgresql.org/docs/current/protocol-replication.html
- PostgreSQL docs, `postgres_fdw`
  - https://www.postgresql.org/docs/current/postgres-fdw.html
