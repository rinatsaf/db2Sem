# HW5 – WAL, дампы и сиды

Папка содержит сценарии для 5-го ДЗ: работа с WAL/LSN, сравнение до/после операций, анализ объёма WAL, дампы, сиды и задел под презентацию (до 1 апреля 2026).

## Предусловия
- Docker-контейнер `hw3_postgres` с БД `autoru_db` (как в прошлых ДЗ).
- PowerShell на хосте, `docker exec` доступен.
- В папке `s1` уже есть схема/данные; при необходимости прогоните `CreateNewTables.sql`.

## 0) Краткий конспект
- См. `00_wal_overview.md` — что такое WAL, зачем LSN.

## 1) Подготовить стенд
```powershell
cd c:\Users\Doom\Desktop\бд\db2Sem\s2\FifthHw
Get-Content -Raw .\01_setup_wal_lab.sql | docker exec -i hw3_postgres psql -U postgres -d autoru_db -v ON_ERROR_STOP=1
```
Создаст схему `wal_lab` и тестовые таблицы/индексы.

## 2) Сравнить LSN до/после INSERT
```powershell
Get-Content -Raw .\02_lsn_diff_insert.sql | docker exec -i hw3_postgres psql -U postgres -d autoru_db -v ON_ERROR_STOP=1
```
Что увидеть: `lsn_before`, `lsn_after_insert`, `wal_bytes_insert` (байты, которые записал INSERT).

## 3) LSN до/после COMMIT в одной транзакции
```powershell
Get-Content -Raw .\03_lsn_commit.sql | docker exec -i hw3_postgres psql -U postgres -d autoru_db -v ON_ERROR_STOP=1
```
Покажет вклад незакоммиченной записи и итог после `COMMIT`.

## 4) Оценка WAL после массовой операции
```powershell
Get-Content -Raw .\04_wal_size_mass.sql | docker exec -i hw3_postgres psql -U postgres -d autoru_db -v ON_ERROR_STOP=1
```
Выведет до/после LSN и `wal_bytes_bulk` для 5k строк. Можно менять переменную `bulk_rows`.

## 5) Дампы и восстановление
```powershell
mkdir -Force .\dumps
# полный дамп + восстановление в чистую БД
Get-Content -Raw .\scripts\11_drop_clone.sql | docker exec -i hw3_postgres psql -U postgres -d postgres -v ON_ERROR_STOP=1

 docker exec -i hw3_postgres pg_dump -U postgres -d autoru_db > .\dumps\autoru_full.sql
 docker exec -i hw3_postgres createdb -U postgres autoru_db_clone
 docker exec -i hw3_postgres psql -U postgres -d autoru_db_clone < .\dumps\autoru_full.sql
# только структура
 docker exec -i hw3_postgres pg_dump -U postgres -d autoru_db -s > .\dumps\autoru_schema.sql
# одна таблица (пример: service.users)
 docker exec -i hw3_postgres pg_dump -U postgres -d autoru_db -t service.users > .\dumps\autoru_service_users.sql
```

## 6) Сиды и тестовые данные (идемпотентно)
```powershell
Get-Content -Raw .\seeds\01_reference_codes.sql | docker exec -i hw3_postgres psql -U postgres -d autoru_db -v ON_ERROR_STOP=1
Get-Content -Raw .\seeds\02_users.sql | docker exec -i hw3_postgres psql -U postgres -d autoru_db -v ON_ERROR_STOP=1
```
Все INSERT используют `ON CONFLICT DO UPDATE/NOTHING`, можно гонять повторно без дублей. После прогонки выполните `SELECT * FROM service.users ORDER BY email;` для проверки.

## 7) Презентация
Черновик тезисов в `PRESENTATION.md`. Дедлайн для докладчиков — 1 апреля 2026 (включительно).

Полезно: все скрипты используют `ON_ERROR_STOP=1`, поэтому падают при первых проблемах — удобно для отладки.
