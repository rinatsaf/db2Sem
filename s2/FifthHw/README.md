

## 1) WAL и LSN

### 1.1 Что такое WAL
**WAL (Write-Ahead Logging)** — журнал предзаписи PostgreSQL. Перед тем как изменить страницу данных на диске, сервер записывает изменение в WAL. Это гарантирует crash recovery: при сбое PostgreSQL перечитывает WAL и восстанавливает незавершённые транзакции.

**LSN (Log Sequence Number)** — позиция в WAL (64-битное число, отображается как `0/XX`). Каждая запись в WAL имеет уникальный LSN. Функция `pg_current_wal_lsn()` показывает текущую позицию записи.

Размер WAL-сегмента по умолчанию — 16 MB. Файлы WAL находятся в `pg_wal/`.

### 1.2 LSN до/после INSERT
```powershell
Get-Content -Raw .\02_lsn_diff_insert.sql | docker exec -i kr psql -U postgres -d autoru_db -v ON_ERROR_STOP=1
```
**Результат:**
```
 lsn_before | lsn_after_insert | wal_bytes_insert | wal_file
------------+------------------+------------------+----------
 0/1F646B38 | 0/1F646C90       |              344 | 00000001000000000000001F
```
Одиночный INSERT добавляет **344 байта** в WAL (строка с JSONB и текстовым полем).

### 1.3 WAL до/после COMMIT
```powershell
Get-Content -Raw .\03_lsn_commit.sql | docker exec -i kr psql -U postgres -d autoru_db -v ON_ERROR_STOP=1
```
**Результат:**
```
 lsn_before_tx | lsn_after_insert | lsn_after_commit | wal_bytes_inside_tx | wal_bytes_commit_only | wal_bytes_total
---------------+------------------+------------------+---------------------+-----------------------+-----------------
 0/1F646C90    | 0/1F646C90       | 0/1F646DE8       |                   0 |                   344 |             344
```
**Вывод:** WAL **не записывается** сразу при INSERT внутри транзакции — буферизируется и сбрасывается только при COMMIT. `wal_bytes_inside_tx = 0`, а `wal_bytes_commit_only = 344`.

### 1.4 Анализ WAL при массовой вставке
```powershell
Get-Content -Raw .\04_wal_size_mass.sql | docker exec -i kr psql -U postgres -d autoru_db -v ON_ERROR_STOP=1
```
**Результат (5000 строк):**
```
 inserted_rows | lsn_before_bulk | lsn_after_bulk | wal_bytes_bulk | wal_bytes_per_row | wal_file
---------------+-----------------+----------------+----------------+-------------------+----------
          5000 | 0/1F6476F8      | 0/1F6FE178     |         748160 |            149.63 | 00000001000000000000001F
```
- **748 KB** WAL на 5000 строк, ~**150 байт на строку**.
- Для настройки кол-ва строк: `psql -v bulk_rows=20000 -f 04_wal_size_mass.sql`

---

## 2) Дампы и восстановление

### 2.1 Полный дамп + накат в clone БД
```powershell
# дропнуть clone, если существует
Get-Content -Raw .\scripts\11_drop_clone.sql | docker exec -i kr psql -U postgres -d postgres -v ON_ERROR_STOP=1

# полный дамп
docker exec -i kr pg_dump -U postgres -d autoru_db > .\dumps\autoru_full.sql

# создать новую БД
docker exec -i kr createdb -U postgres autoru_db_clone

# восстановить
Get-Content .\dumps\autoru_full.sql | docker exec -i kr psql -U postgres -d autoru_db_clone -v ON_ERROR_STOP=1
```
Результат: все 18 таблиц и данные скопированы в `autoru_db_clone`.

### 2.2 Дамп только структуры
```powershell
docker exec -i kr pg_dump -U postgres -d autoru_db -s > .\dumps\autoru_schema.sql
```
Файл: `autoru_schema.sql` (~89 KB, только CREATE TABLE/INDEX без данных).

### 2.3 Дамп одной таблицы
```powershell
docker exec -i kr pg_dump -U postgres -d autoru_db -t service.users > .\dumps\autoru_service_users.sql
```
Файл: `autoru_service_users.sql` (~63 MB, структура + 250k строк таблицы users).

---

## 3) Сиды и тестовые данные (идемпотентно)

### 3.1 Референс-коды
```powershell
Get-Content -Raw .\seeds\01_reference_codes.sql | docker exec -i kr psql -U postgres -d autoru_db -v ON_ERROR_STOP=1
```
Добавляет справочники: `body_types`, `transmissions`, `fuel_types`, `ad_statuses`, `moderator_roles`.

### 3.2 Тестовые пользователи
```powershell
Get-Content -Raw .\seeds\02_users.sql | docker exec -i kr psql -U postgres -d autoru_db -v ON_ERROR_STOP=1
```
Добавляет 3 тестовых пользователя: Alice Doe, Bob Smith, Carol Jones.

### 3.3 Проверка идемпотентности
Все seed-ы используют `ON CONFLICT ... DO UPDATE`. Повторный прогон выдаёт `INSERT 0 N` (0 новых строк, только обновление существующих). Дубли отсутствуют:
```sql
SELECT email FROM service.users ORDER BY email;
-- alice@example.com
-- bob@example.com
-- carol@example.com
```

