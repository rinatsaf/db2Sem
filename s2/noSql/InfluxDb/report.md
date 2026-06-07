## 0) Настроить docker-compose, получить токен, открыть UI

```
docker compose exec influxdb3-core influxdb3 create token --admin
```
token: apiv3_P_8n5b40i-Rue48sIQbTkTglpB3EzwV6Vx7d_AG4GlC7i0THt_NJumakakshgXvcjYnhwsO7cZzFLKtxPuWkTQ

```
curl -X GET "http://localhost:8181/health" \
  -H "Authorization: Bearer apiv3_P_8n5b40i-Rue48sIQbTkTglpB3EzwV6Vx7d_AG4GlC7i0THt_NJumakakshgXvcjYnhwsO7cZzFLKtxPuWkTQ"
```

![Запущено успешно](screenshots/healthcheck.png)

UI: http://localhost:8888

Конфигурация:
- Название: homework
- Путь: http://influxdb3-core:8181
- Токен: выше

![ui](screenshots/ui.png)

## Запросы

1) Создать bucket mydb
Через UI (http://localhost:8888) или curl

![alt text](screenshots/create_db.png)

2) Вставить несколько записей
 - Measurement: temperature
 - Теги: location (room1, room2)
 - Поля: value (число)

```
curl -X POST "http://localhost:8181/api/v3/write_lp?db=mydb" \
  -H "Authorization: Bearer apiv3_P_8n5b40i-Rue48sIQbTkTglpB3EzwV6Vx7d_AG4GlC7i0THt_NJumakakshgXvcjYnhwsO7cZzFLKtxPuWkTQ" \
  -d "temperature,location=room1 value=23.5"
```

![insert](screenshots/insert.png)

```
curl -X POST "http://localhost:8181/api/v3/query_sql" \
  -H "Authorization: Bearer apiv3_P_8n5b40i-Rue48sIQbTkTglpB3EzwV6Vx7d_AG4GlC7i0THt_NJumakakshgXvcjYnhwsO7cZzFLKtxPuWkTQ" \
  -H "Content-Type: application/json" \
  -d '{
    "db": "mydb",
    "q": "SELECT * FROM temperature LIMIT 5"
  }'
```

![проверка вставки](screenshots/query1.png)

3) Выбрать все данные за последние 5 минут

```
curl -X POST "http://localhost:8181/api/v3/query_sql" \
  -H "Authorization: Bearer apiv3_P_8n5b40i-Rue48sIQbTkTglpB3EzwV6Vx7d_AG4GlC7i0THt_NJumakakshgXvcjYnhwsO7cZzFLKtxPuWkTQ" \
  -H "Content-Type: application/json" \
  -d '{
    "db": "mydb",
    "q": "SELECT * FROM temperature WHERE time >= now() - INTERVAL '\''5 minutes'\'' ORDER BY time DESC"
  }'
```

![alt text](screenshots/query2_before.png)

Ждём пять минут

![alt text](screenshots/query2_after.png)

## 5) Сгруппировать SELECT по тегу location (например, среднее значение по комнатам)

Сначала добавить больше данных

```
curl -X POST "http://localhost:8181/api/v3/write_lp?db=mydb" \
  -H "Authorization: Bearer apiv3_P_8n5b40i-Rue48sIQbTkTglpB3EzwV6Vx7d_AG4GlC7i0THt_NJumakakshgXvcjYnhwsO7cZzFLKtxPuWkTQ" \
  --data-raw "temperature,location=room1 value=24.1
temperature,location=room2 value=21.8
temperature,location=room1 value=23.9
temperature,location=room2 value=22.3
temperature,location=room1 value=25.0"
```

Теперь сам запрос:

```
curl -X POST "http://localhost:8181/api/v3/query_sql" \
  -H "Authorization: Bearer apiv3_P_8n5b40i-Rue48sIQbTkTglpB3EzwV6Vx7d_AG4GlC7i0THt_NJumakakshgXvcjYnhwsO7cZzFLKtxPuWkTQ" \
  -H "Content-Type: application/json" \
  -d '{
    "db": "mydb",
    "q": "SELECT location, AVG(value) AS avg_temp, COUNT(value) AS readings FROM temperature WHERE time >= now() - INTERVAL '\''1 hour'\'' GROUP BY location ORDER BY avg_temp DESC"
  }'
```

![alt text](screenshots/query3.png)

В UI:

![alt text](screenshots/query3_ui.png)