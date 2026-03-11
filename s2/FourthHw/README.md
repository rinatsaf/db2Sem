# HW4 - MVCC, xmin/xmax/ctid/t_infomask, locks and deadlocks

Папка содержит полностью воспроизводимые сценарии для 4 ДЗ.

## 0) Подготовка

Запускать в 2-3 разных psql-сессиях к одной БД (например `autoru_db`).

```powershell
cd c:\Users\Doom\Desktop\бд\db2Sem\s2\FourthHw
Get-Content -Raw .\01_setup.sql | docker exec -i hw3_postgres psql -U postgres -d autoru_db -v ON_ERROR_STOP=1
```

## 1) Обновление данных и xmin/xmax/ctid/t_infomask

1. Выполнить:
```powershell
Get-Content -Raw .\02_mvcc_single_tx.sql | docker exec -i hw3_postgres psql -U postgres -d autoru_db -v ON_ERROR_STOP=1
```
2. Выполнить:
```powershell
Get-Content -Raw .\03_t_infomask_decode.sql | docker exec -i hw3_postgres psql -U postgres -d autoru_db -v ON_ERROR_STOP=1
```

Что увидеть:
- `ctid` меняется после `UPDATE` (новая версия кортежа).
- у старой версии `xmax` становится XID обновляющей транзакции.
- `t_infomask`/`t_infomask2` меняются по состоянию tuple.
- расшифровка через `heap_tuple_infomask_flags(...)` показывает смысл битов.

## 2) Те же параметры в разных транзакциях

Открыть 2 сессии.

Сессия A:
- выполнить `04_mvcc_tx_a.sql`

Сессия B:
- выполнить `05_mvcc_tx_b.sql`

Что увидеть:
- до COMMIT A, сессия B видит старую версию строки;
- после COMMIT A, сессия B видит новую версию (`ctid`/`xmin` другие).

## 3) Смоделировать дедлок

Открыть 2 сессии и выполнить:
- сессия A: `06_deadlock_tx_a.sql`
- сессия B: `07_deadlock_tx_b.sql`

Ожидаемо: одна транзакция будет прервана с ошибкой `deadlock detected`.

## 4) Явные блокировки (table-level и row-level)

### 4.1 Табличные блокировки

Открыть 2 сессии:
- сессия A: `08_table_lock_tx_a.sql`
- сессия B: `09_table_lock_tx_b.sql`

Далее в любой сессии:
```powershell
Get-Content -Raw .\10_locks_observe.sql | docker exec -i hw3_postgres psql -U postgres -d autoru_db -v ON_ERROR_STOP=1
```

### 4.2 Блокировки строк и конфликты

Открыть 3 сессии:
- A: `11_row_lock_tx_a.sql`
- B: `12_row_lock_tx_b.sql`
- C: `13_row_lock_tx_c.sql`

Сценарий показывает конфликты для `FOR UPDATE`, `FOR NO KEY UPDATE`, `FOR SHARE`, `FOR KEY SHARE`.

## 5) Очистка данных

```powershell
Get-Content -Raw .\99_cleanup.sql | docker exec -i hw3_postgres psql -U postgres -d autoru_db -v ON_ERROR_STOP=1
```

## Коротко про t_infomask

`t_infomask` и `t_infomask2` — битовые поля заголовка heap tuple, где хранится служебная MVCC-информация: состояние видимости tuple, признак блокировки, наличие HOT update, статус XMIN/XMAX и т.п.

В скрипте `03_t_infomask_decode.sql` это декодируется через встроенную функцию `heap_tuple_infomask_flags` (расширение `pageinspect`).

## Источник по явным блокировкам

- https://postgrespro.ru/docs/postgrespro/current/explicit-locking
