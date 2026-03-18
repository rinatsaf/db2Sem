-- Отключаем сессии и удаляем клон, чтобы восстановление было идемпотентным
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'autoru_db_clone' AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS autoru_db_clone;
