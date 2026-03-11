# Explicit Locking - short notes

Источник: https://postgrespro.ru/docs/postgrespro/current/explicit-locking

## Table-level lock modes (основные)

- `ACCESS SHARE`: обычный `SELECT`.
- `ROW SHARE`: `SELECT ... FOR UPDATE/SHARE`.
- `ROW EXCLUSIVE`: `INSERT/UPDATE/DELETE`.
- `SHARE UPDATE EXCLUSIVE`: `VACUUM` (без FULL), `ANALYZE`, `CREATE INDEX CONCURRENTLY`.
- `SHARE`: `CREATE INDEX`.
- `SHARE ROW EXCLUSIVE`: `CREATE TRIGGER` и некоторые `ALTER TABLE`.
- `EXCLUSIVE`: блокирует почти все, кроме `ACCESS SHARE`.
- `ACCESS EXCLUSIVE`: самый строгий (`TRUNCATE`, `DROP`, `VACUUM FULL`, много `ALTER TABLE`).

Ключевая идея: чем “сильнее” режим, тем с большим числом режимов он конфликтует.

## Row-level lock modes

- `FOR KEY SHARE`
- `FOR SHARE`
- `FOR NO KEY UPDATE`
- `FOR UPDATE`

Практически:
- `FOR UPDATE` — самый строгий строковый lock.
- `FOR NO KEY UPDATE` слабее `FOR UPDATE`.
- `FOR SHARE` и `FOR KEY SHARE` — для чтения с защитой от части изменений.

Конфликты воспроизводятся скриптами:
- `11_row_lock_tx_a.sql`
- `12_row_lock_tx_b.sql`
- `13_row_lock_tx_c.sql`
