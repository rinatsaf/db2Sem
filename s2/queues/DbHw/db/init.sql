-- 1. Основная таблица очереди
CREATE TABLE IF NOT EXISTS tasks (
                                     id SERIAL PRIMARY KEY,
                                     payload TEXT NOT NULL,
                                     priority INT NOT NULL DEFAULT 0 CHECK (priority >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'Ready' CHECK (status IN ('Ready', 'Running', 'Completed', 'Failed')),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    scheduled_at TIMESTAMP NOT NULL DEFAULT NOW(),
    attempts INT NOT NULL DEFAULT 0,
    last_error TEXT
    );

-- 2. Оптимизированный Partial Index
-- Порядок колонок строго соответствует ORDER BY в запросе консьюмера.
-- WHERE status = 'Ready' делает индекс компактным и ускоряет выборку в 5-10x.
CREATE INDEX IF NOT EXISTS idx_tasks_ready
    ON tasks (status, scheduled_at, priority DESC, created_at ASC)
    WHERE status = 'Ready';

-- 3. Агрессивный autovacuum 
-- Запускает очистку после ~100 изменённых строк, минимизируя раздувание таблицы.
ALTER TABLE tasks SET (
    autovacuum_vacuum_scale_factor = 0,
    autovacuum_vacuum_threshold = 100,
    autovacuum_analyze_scale_factor = 0,
    autovacuum_analyze_threshold = 100,
    autovacuum_vacuum_cost_delay = 5,
    autovacuum_vacuum_cost_limit = 400
    );

-- 4. Триггер для LISTEN/NOTIFY (замена polling)
CREATE OR REPLACE FUNCTION notify_task_insert() RETURNS trigger AS $$
BEGIN
    PERFORM pg_notify('task_added', NEW.id::text);
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS task_insert_notify ON tasks;
CREATE TRIGGER task_insert_notify
    AFTER INSERT ON tasks
    FOR EACH ROW EXECUTE FUNCTION notify_task_insert();

-- ============================================================
-- УТИЛИТЫ ДЛЯ МОНИТОРИНГА
-- ============================================================
-- А) Лаг очереди (секунды ожидания самой старой Ready задачи):
-- SELECT EXTRACT(EPOCH FROM (NOW() - MIN(created_at))) AS lag_sec FROM tasks WHERE status = 'Ready';

-- Б) Пропускная способность (задач/сек за последние 10 сек):
-- SELECT COUNT(*) / 10.0 AS tps FROM tasks WHERE status = 'Completed' AND created_at > NOW() - INTERVAL '10 seconds';

-- В) Сравнение приоритетов (демонстрация выполнения критических задач первыми):
-- SELECT id, priority, created_at, status FROM tasks ORDER BY priority DESC, created_at ASC;

-- Г) Ручной VACUUM (для демонстрации влияния bloat на время выборки):
-- VACUUM ANALYZE tasks;