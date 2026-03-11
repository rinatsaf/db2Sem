# Deadlock expected result

Сценарий:
- Session A берет lock на `id=1`, потом пытается `id=2`.
- Session B берет lock на `id=2`, потом пытается `id=1`.

Итог:
- Postgres обнаруживает цикл ожиданий.
- Одну из транзакций аварийно завершает с ошибкой `deadlock detected`.
- Вторая транзакция после этого продолжает выполнение (если не отменена вручную).

Типичный фрагмент ошибки:

```text
ERROR: deadlock detected
DETAIL: Process ... waits for ...; blocked by process ...
HINT: See server log for query details.
```

Проверка блокировок во время сценария:
- выполнить `10_locks_observe.sql`
- посмотреть `pg_locks`, `pg_stat_activity`, `pg_blocking_pids(...)`
