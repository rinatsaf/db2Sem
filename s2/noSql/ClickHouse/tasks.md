# 1 задание 
## Запустить докер ну запустил допустим

# 2 задание 
## Создание таблицы
    CREATE DATABASE IF NOT EXISTS homework;

    USE homework;

    CREATE TABLE IF NOT EXISTS trips
    (
        trip_id UInt32,
        start_time DateTime,
        end_time DateTime,
        distance_km Float32,
        city String
    )
    ENGINE = MergeTree
    ORDER BY trip_id;

# 3 задание 
## Вставить 1 миллион строк
    INSERT INTO trips
    SELECT
        number + 1 AS trip_id,
        now() - rand() % 2592000 AS start_time,
        start_time + rand() % 7200 AS end_time,
        round(randUniform(1, 50), 2) AS distance_km,
        ['Moscow', 'London', 'Berlin', 'Paris', 'Tokyo'][rand() % 5 + 1] AS city
    FROM numbers(1000000);

# 4 задание 
## Аналитический запрос
    SELECT
        city,
        round(avg(distance_km), 2) AS avg_distance,
        count() AS trip_count,
        max(dateDiff('second', start_time, end_time)) AS max_duration_sec
    FROM trips
    GROUP BY city
    ORDER BY city;