# Third Homework (11.03.2026)

Everything in this folder is enough to run HW3 locally.

## 1. Start monitoring stack

```powershell
cd s2\ThirdHw
docker compose up -d
```

Services:
- PostgreSQL: `localhost:5432`
- postgres-exporter: `localhost:9187/metrics`
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000` (`admin` / `admin`)

Grafana dashboard is provisioned automatically:
- `HW3 Postgres Monitoring`
- Contains required panels:
  - PostgreSQL version
  - Active sessions
  - SELECT graph
  - INSERT graph
  - DELETE graph
  - Average CPU Usage (`avg(rate(process_cpu_seconds_total{job="postgres_exporter",instance=~"$instance"}[5m]) * 1000)`)

## 2. Prepare DB schema/data

Run old schema/data scripts from homework #1, then run HW3 prep:

```powershell
psql -h localhost -U postgres -d autoru_db -f ..\..\s1\CreateNewTables.sql
psql -h localhost -U postgres -d autoru_db -f ..\..\s1\service_test_data.sql
psql -h localhost -U postgres -d autoru_db -f .\00_prepare_hw3.sql
```

## 3. GIN part

```powershell
psql -h localhost -U postgres -d autoru_db -f .\GinIndex.sql
psql -h localhost -U postgres -d autoru_db -f .\GinRequests.sql
```

`GinRequests.sql` has 5 query groups with operation comparison (index-friendly vs alternative).

## 4. GiST part

```powershell
psql -h localhost -U postgres -d autoru_db -f .\GistIndex.sql
psql -h localhost -U postgres -d autoru_db -f .\GistRequests.sql
```

`GistRequests.sql` has 5 query groups with operation comparison.

## 5. JOIN part

```powershell
psql -h localhost -U postgres -d autoru_db -f .\JoinRequests.sql
```

`JoinRequests.sql` contains 5 JOIN queries to inspect join results.

## 6. Optional load generation for Grafana graphs

```sql
-- SELECT load
SELECT count(*) FROM service.ads a CROSS JOIN service.vehicles v;

-- INSERT load
INSERT INTO service.mileage_log(vehicle_id, mileage_km)
SELECT vehicle_id, 100000 + floor(random() * 10000)::int
FROM service.vehicles;

-- DELETE load
DELETE FROM service.mileage_log
WHERE mileage_id IN (
  SELECT mileage_id
  FROM service.mileage_log
  ORDER BY mileage_id DESC
  LIMIT 3
);
```
