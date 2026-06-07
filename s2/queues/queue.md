# 1 Лаг Очереди (время ожидания самой старой задачи)
#### Лаг в секундах (дробное число)
    SELECT 
        EXTRACT(EPOCH FROM (NOW() - MIN(created_at))) AS lag_seconds
    FROM tasks 
    WHERE status = 'Ready';
#### Лаг в формате "мм:сс" (человекочитаемый)
    SELECT 
        TO_CHAR(NOW() - MIN(created_at), 'MI:SS') AS lag_formatted
    FROM tasks 
    WHERE status = 'Ready';

#### Лаг + метаданные для отчёта
    SELECT 
        MIN(created_at) AS oldest_ready_task,
        NOW() AS current_time,
        NOW() - MIN(created_at) AS lag_interval,
        EXTRACT(EPOCH FROM (NOW() - MIN(created_at))) AS lag_seconds,
        COUNT(*) AS ready_queue_size
    FROM tasks 
    WHERE status = 'Ready';

## 2 Пропускная способность (задач в секунду)
#### Задач в секунду за последние 10 секунд (среднее)
    SELECT 
        COUNT(*)::FLOAT / 10 AS tasks_per_second
    FROM tasks 
    WHERE status = 'Completed' 
    AND created_at > NOW() - INTERVAL '10 seconds';
#### 3,7 так как некоторые задачи помечаются как неудачно обработанные из за ошибок bl

## 3 AUTOVacuum
### в init sql настроен 
#### При анализе отключил автоваккум подожадл 30 сек после чего на 30% ускорилось

