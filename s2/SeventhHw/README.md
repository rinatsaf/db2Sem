# HW7 – Репликация PostgreSQL

## 1. Архитектура

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Network                           │
│                                                             │
│  ┌──────────────┐    ┌──────────────┐                       │
│  │  hw7_primary │◄───│ hw7_replica  │  Physical streaming   │
│  │  (мастер)    │    │ (standby)    │  replication          │
│  │  порт 5440   │    │  порт 5441   │                       │
│  └──────┬───────┘    └──────────────┘                       │
│         │                                                   │
│         │ logical replication                                │
│         ▼                                                   │
│  ┌──────────────┐    ┌──────────────┐                       │
│  │logical_pub   │───►│ logical_sub  │  Logical replication  │
│  │(publisher)   │    │ (subscriber) │  PUBLICATION/SUB      │
│  │  порт 5442   │    │  порт 5443   │                       │
│  └──────────────┘    └──────────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

**3 инстанса PostgreSQL:** primary, replica (physical standby), logical_pub.

---

## 2-4. Physical streaming replication

### Настройка

В `docker-compose.yml`:
- `wal_level=logical`, `max_wal_senders=10` на primary
- Replica использует `pg_basebackup -h primary -D $PGDATA -Fp -Xs -R`
- `-R` создаёт `standby.signal` + `postgresql.auto.conf` с `primary_conninfo`

### Проверка

```powershell
# primary — не в recovery
docker exec -i hw7_primary psql -U postgres -c "SELECT pg_is_in_recovery();"
-- результат: f (false)

# replica — в recovery
docker exec -i hw7_replica psql -U postgres -c "SELECT pg_is_in_recovery();"
-- результат: t (true)
```

---

## 5-7. Проверка репликации данных

```powershell
# вставляем на primary
docker exec -i hw7_primary psql -U postgres -c "
  CREATE SCHEMA hw7;
  CREATE TABLE hw7.test_repl (id INT PRIMARY KEY, msg TEXT);
  INSERT INTO hw7.test_repl VALUES (1, 'hello from primary'), (2, 'row 2');
"

# проверяем на replica — данные есть
docker exec -i hw7_replica psql -U postgres -c "SELECT * FROM hw7.test_repl;"
-- id |        msg
----+--------------------
--  1 | hello from primary
--  2 | row 2

# вставляем ещё на primary
docker exec -i hw7_primary psql -U postgres -c "
  INSERT INTO hw7.test_repl VALUES (3, 'replicated row');
"

# проверяем на replica
docker exec -i hw7_replica psql -U postgres -c "SELECT * FROM hw7.test_repl ORDER BY id;"
-- id |        msg
----+--------------------
--  1 | hello from primary
--  2 | row 2
--  3 | replicated row
```

---

## 8. Вставка на реплике — ошибка

```powershell
docker exec -i hw7_replica psql -U postgres -c "
  INSERT INTO hw7.test_repl VALUES (99, 'try insert on replica');
"
-- ERROR:  cannot execute INSERT in a read-only transaction
```

Replica в режиме `hot_standby` — только чтение.

---

## 9-11. Replication lag

### Статус лага (до нагрузки)

```powershell
docker exec -i hw7_primary psql -U postgres -c "
  SELECT application_name, state, write_lag, flush_lag, replay_lag
  FROM pg_stat_replication;
"
-- application_name |   state   | write_lag | flush_lag  | replay_lag
-- walreceiver      | streaming | 0.000132s | 0.002269s  | 0.002368s
```

### Нагрузка INSERT (10 000 строк)

```powershell
docker exec -i hw7_primary psql -U postgres -c "
  INSERT INTO hw7.test_repl
  SELECT gs, 'load test row ' || gs
  FROM generate_series(10, 10009) gs;
"
-- INSERT 0 10000
```

### Lag после нагрузки

```powershell
docker exec -i hw7_primary psql -U postgres -c "
  SELECT application_name, state, write_lag, flush_lag, replay_lag,
         pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)) AS lag_bytes
  FROM pg_stat_replication;
"
-- walreceiver | streaming | 0.00019s | 0.001419s | 0.00142s | 0 bytes
```

### Подтверждение: все строки на replica

```powershell
docker exec -i hw7_replica psql -U postgres -Atc "SELECT count(*) FROM hw7.test_repl;"
-- 10003 (3 начальных + 10000 нагрузка)
```

Лаг минимальный (< 3ms) — в Docker-сети задержка практически отсутствует.

---

## 12-13. Logical replication (PUBLICATION/SUBSCRIPTION)

### Настройка

**Publisher (logical_pub):**
```powershell
docker exec -i hw7_logical_pub psql -U postgres -c "
  CREATE SCHEMA hw7_logical;
  CREATE TABLE hw7_logical.ads (id INT PRIMARY KEY, title TEXT, price INT);
  INSERT INTO hw7_logical.ads VALUES (1, 'First ad', 100), (2, 'Second ad', 200);
  CREATE PUBLICATION hw7_pub FOR TABLE hw7_logical.ads;
"
```

**Subscriber (logical_sub):**
```powershell
docker exec -i hw7_logical_sub psql -U postgres -c "
  CREATE SCHEMA hw7_logical;
  CREATE TABLE hw7_logical.ads (id INT PRIMARY KEY, title TEXT, price INT);
  CREATE SUBSCRIPTION hw7_sub
  CONNECTION 'host=<publisher_ip> port=5432 dbname=postgres user=postgres password=postgres'
  PUBLICATION hw7_pub WITH (copy_data = true, create_slot = true);
"
```

### Данные реплицируются (live)

```powershell
# вставляем на publisher
docker exec -i hw7_logical_pub psql -U postgres -c "
  INSERT INTO hw7_logical.ads VALUES (3, 'Live replicated', 300), (4, 'Another one', 400);
"

# проверяем на subscriber
docker exec -i hw7_logical_sub psql -U postgres -c "SELECT * FROM hw7_logical.ads;"
-- id |      title      | price
----+-----------------+-------
--  1 | First ad        |   100
--  2 | Second ad       |   200
--  3 | Live replicated |   300
--  4 | Another one     |   400
```

---

## 14. DDL не реплицируется

```powershell
# добавляем колонку на publisher
docker exec -i hw7_logical_pub psql -U postgres -c "
  ALTER TABLE hw7_logical.ads ADD COLUMN description TEXT DEFAULT 'no desc';
  INSERT INTO hw7_logical.ads VALUES (5, 'Has description', 500, 'new column DDL');
"

# проверяем subscriber — колонки нет, DML-изменения пришли
docker exec -i hw7_logical_sub psql -U postgres -c "\d hw7_logical.ads"
-- Таблица "hw7_logical.ads"
-- id    | integer | not null
-- title | text    |
-- price | integer |
-- (колонки description НЕТ)

docker exec -i hw7_logical_sub psql -U postgres -c "SELECT * FROM hw7_logical.ads;"
-- id=5 пришёл, но только с id, title, price (без description)
```

---

## 15. REPLICA IDENTITY — таблица без PK

```powershell
# создаём таблицу БЕЗ PK на publisher
docker exec -i hw7_logical_pub psql -U postgres -c "
  CREATE TABLE hw7_logical.no_pk_table (id INT, data TEXT);
  INSERT INTO hw7_logical.no_pk_table VALUES (1, 'row1'), (2, 'row2');
  CREATE PUBLICATION hw7_pub_nopk FOR TABLE hw7_logical.no_pk_table;
"

# создаём такую же на subscriber
docker exec -i hw7_logical_sub psql -U postgres -c "
  CREATE TABLE hw7_logical.no_pk_table (id INT, data TEXT);
  CREATE SUBSCRIPTION hw7_sub_nopk
  CONNECTION 'host=<publisher_ip> port=5432 dbname=postgres user=postgres password=postgres'
  PUBLICATION hw7_pub_nopk WITH (copy_data = true, create_slot = true);
"

# UPDATE на таблице БЕЗ REPLICA IDENTITY — ошибка
docker exec -i hw7_logical_pub psql -U postgres -c "
  UPDATE hw7_logical.no_pk_table SET data = 'updated' WHERE id = 1;
"
-- ERROR:  cannot update table "no_pk_table"
-- because it does not have a replica identity and publishes updates

# решение: REPLICA IDENTITY FULL
docker exec -i hw7_logical_pub psql -U postgres -c "
  ALTER TABLE hw7_logical.no_pk_table REPLICA IDENTITY FULL;
  UPDATE hw7_logical.no_pk_table SET data = 'updated_via_full' WHERE id = 1;
"

# проверяем subscriber
docker exec -i hw7_logical_sub psql -U postgres -c "SELECT * FROM hw7_logical.no_pk_table;"
-- id |       data
----+------------------
--  2 | row2
--  1 | updated_via_full
```

---

## 16. Проверка отсутствия DDL

Показано в п. 14: `ALTER TABLE ADD COLUMN` на publisher **не применяется** на subscriber. Логическая репликация передаёт только DML (INSERT/UPDATE/DELETE), DDL нужно применять вручную на подписчике.

---

## 17. Replication status

```powershell
docker exec -i hw7_logical_sub psql -U postgres -c "
  SELECT subname, subenabled, subslotname, subpublications
  FROM pg_subscription;
"
--   subname    | subenabled | subslotname  | subpublications
-- hw7_sub      | t          | hw7_sub      | {hw7_pub}
-- hw7_sub_nopk | t          | hw7_sub_nopk | {hw7_pub_nopk}
```

---

## 18. pg_dump/pg_restore для logical replication

`pg_dump` используется для **первоначальной синхронизации** данных на subscriber:

```powershell
# дамп данных таблицы с publisher
docker exec -i hw7_logical_pub pg_dump -U postgres -d postgres -t hw7_logical.ads --data-only --column-inserts > dumps/hw7_ads_data.sql

# восстановление на subscriber (перед созданием subscription с copy_data = false)
# docker exec -i hw7_logical_sub psql -U postgres -d postgres < dumps/hw7_ads_data.sql
```

Также `pg_dump` может быть использован для:
- Копирования схемы на subscriber (чтобы subscriber имел все таблицы)
- Создания дампа для настройки нового subscriber с нуля
- `pg_dump --schema-only` для переноса DDL (поскольку DDL не реплицируется)

---

## Контейнеры

| Контейнер | Роль | Порт |
|---|---|---|
| `hw7_primary` | Master для physical replication | 5440 |
| `hw7_replica` | Standby (physical replication) | 5441 |
| `hw7_logical_pub` | Publisher (logical replication) | 5442 |
| `hw7_logical_sub` | Subscriber (logical replication) | 5443 |
