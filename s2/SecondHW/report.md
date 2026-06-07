# Отчёт по индексам PostgreSQL (B-tree vs Hash)

## Данные и окружение
- Таблица: `service.ads`, 250 000 строк
- PostgreSQL 16 (Debian), Docker-контейнер
- Замеры: `EXPLAIN (ANALYZE, BUFFERS)` — реальные результаты с запуска

---

## Набор запросов (5 шт.)
1. `price > 2000000 AND status_id IN (1,2)`  — покрывает `>` и `IN`
2. `price < 50000` — покрывает `<`
3. `price = 1000000` — покрывает `=`
4. `header_text LIKE '%car #12%'` — покрывает `%LIKE`
5. `header_text LIKE 'Selling car #12%'` — покрывает `LIKE%`

---

## Индексы
### B-tree
- `btree(price)` — диапазоны и равенство
- **ДОП (составной):** `btree(status_id, price)` — запросы вида `status_id IN (...) AND price > ...`
- `btree(header_text text_pattern_ops)` — ускоряет `LIKE 'prefix%'`

### Hash
- `hash(price)` — ускоряет в основном `price = ...` (равенство)

---

## Результаты без индексов

Все 5 запросов работают через `Seq Scan` (или `Parallel Seq Scan`).

### Q1: `price > 2000000 AND status_id IN (1,2)`
```
Seq Scan on ads  (cost=0.00..10912.00 rows=83394 width=12)
                 (actual time=0.007..31.705 rows=83175 loops=1)
  Filter: ((price > 2000000) AND (status_id = ANY ('{1,2}'::integer[])))
  Rows Removed by Filter: 166825
  Buffers: shared hit=7162
  Planning Time: 0.524 ms
  Execution Time: 34.004 ms
```

- 7162 страницы (56 MB) прочитано из кеша
- 166825 строк отфильтровано, 83175 подошло

### Q2: `price < 50000`
```
Gather  (cost=1000.00..9903.98 rows=4399 width=8)
        (actual time=0.314..16.855 rows=4261 loops=1)
  Workers Planned: 2
  Workers Launched: 2
  Buffers: shared hit=7162
  ->  Parallel Seq Scan  (cost=0.00..8464.08 rows=1833 width=8)
                         (actual time=0.023..9.862 rows=1420 loops=3)
        Filter: (price < 50000)
        Rows Removed by Filter: 81913
  Planning Time: 0.053 ms
  Execution Time: 17.008 ms
```

- Parallel Seq Scan с 2 воркерами, но всё равно читает всю таблицу

### Q3: `price = 1000000`
```
Gather  (cost=1000.00..9464.18 rows=1 width=8)
        (actual time=12.545..14.721 rows=0 loops=1)
  Workers Planned: 2
  Workers Launched: 2
  Buffers: shared hit=7162
  ->  Parallel Seq Scan  (cost=0.00..8464.08 rows=1 width=8)
                         (actual time=10.031..10.032 rows=0 loops=3)
        Filter: (price = 1000000)
        Rows Removed by Filter: 83333
  Planning Time: 0.048 ms
  Execution Time: 14.745 ms
```

- Parallel Seq Scan, 0 строк найдено (цены ровно 1000000 нет в данных)

### Q4: `LIKE '%car #12%'`
```
Seq Scan on ads  (cost=0.00..10287.00 rows=12626 width=23)
                 (actual time=0.022..32.344 rows=11111 loops=1)
  Filter: ((header_text)::text ~~ '%car #12%'::text)
  Rows Removed by Filter: 238889
  Buffers: shared hit=7162
  Planning Time: 0.211 ms
  Execution Time: 32.638 ms
```
- 11111 строк подошло, 238889 отфильтровано

### Q5: `LIKE 'Selling car #12%'`
```
Seq Scan on ads  (cost=0.00..10287.00 rows=12626 width=23)
                 (actual time=0.023..31.441 rows=11111 loops=1)
  Filter: ((header_text)::text ~~ 'Selling car #12%'::text)
  Rows Removed by Filter: 238889
  Buffers: shared hit=7162
  Planning Time: 0.162 ms
  Execution Time: 31.757 ms
```

**Итог без индексов:**
| Запрос | Тип сканирования | Execution Time | Buffers |
|---|---|---|---|
| Q1 (`>` + `IN`) | Seq Scan | 34.0 ms | hit=7162 |
| Q2 (`<`) | Parallel Seq Scan | 17.0 ms | hit=7162 |
| Q3 (`=`) | Parallel Seq Scan | 14.7 ms | hit=7162 |
| Q4 (`%LIKE`) | Seq Scan | 32.6 ms | hit=7162 |
| Q5 (`LIKE%`) | Seq Scan | 31.8 ms | hit=7162 |

---

## Сравнение: B-tree vs без индекса

### Планы запросов с B-tree

**Q1:** `price > 2000000 AND status_id IN (1,2)`
```
Bitmap Heap Scan on ads  (cost=1564.35..9980.41 rows=83604 width=12)
                         (actual time=6.060..33.214 rows=83175 loops=1)
  Recheck Cond: (price > 2000000)
  Filter: (status_id = ANY ('{1,2}'::integer[]))
  Heap Blocks: exact=7162
  Buffers: shared hit=7162 read=228
  ->  Bitmap Index Scan on idx_ads_price_btree
        (cost=0.00..1543.45 rows=83604 width=0)
        (actual time=4.981..4.983 rows=83175 loops=1)
      Index Cond: (price > 2000000)
      Buffers: shared read=228
  Execution Time: 35.532 ms
```
- `Seq Scan` → `Bitmap Index Scan + Bitmap Heap Scan`
- Время ~ то же (35.5 vs 34 ms), т.к. `price > 2000000` охватывает 33% таблицы (83175 строк)
- **Составной индекс `idx_ads_status_price_btree` не был использован** — планировщик счёл фильтр по `status_id IN (1,2)` недостаточно селективным

**Q2:** `price < 50000`
```
Bitmap Heap Scan on ads  (cost=75.45..6437.95 rows=4004 width=8)
                         (actual time=0.780..4.426 rows=4261 loops=1)
  Recheck Cond: (price < 50000)
  Heap Blocks: exact=3221
  Buffers: shared hit=3222 read=13
  ->  Bitmap Index Scan on idx_ads_price_btree
        (cost=0.00..74.45 rows=4004 width=0)
        (actual time=0.445..0.446 rows=4261 loops=1)
      Index Cond: (price < 50000)
      Buffers: shared hit=1 read=13
  Execution Time: 4.580 ms
```
- Всего 14 страниц индекса (13 read + 1 hit) и 3221 heap block вместо 7162
- **×3.7 быстрее** (4.6 ms vs 17.0 ms)

**Q3:** `price = 1000000`
```
Index Scan using idx_ads_price_btree on ads
  (cost=0.42..8.44 rows=1 width=8)
  (actual time=0.025..0.025 rows=0 loops=1)
  Index Cond: (price = 1000000)
  Buffers: shared hit=2 read=1
  Execution Time: 0.037 ms
```
- `Index Scan` — прямой поиск по B-tree, всего 3 страницы вместо 7162
- **×400 быстрее** (0.037 ms vs 14.7 ms)

**Q4:** `LIKE '%car #12%'`
```
Seq Scan on ads  (cost=0.00..10287.00 rows=10101 width=23)
                 (actual time=0.021..33.475 rows=11111 loops=1)
  Filter: ((header_text)::text ~~ '%car #12%'::text)
  Rows Removed by Filter: 238889
  Buffers: shared hit=7162
  Execution Time: 33.773 ms
```
- Без изменений: `Seq Scan` — B-tree не помогает при ведущем `%`

**Q5:** `LIKE 'Selling car #12%'`
```
Bitmap Heap Scan on ads  (cost=301.96..7964.11 rows=10101 width=23)
                         (actual time=0.696..2.676 rows=11111 loops=1)
  Filter: ((header_text)::text ~~ 'Selling car #12%'::text)
  Heap Blocks: exact=354
  Buffers: shared hit=354 read=58
  ->  Bitmap Index Scan on idx_ads_header_prefix_btree
        (cost=0.00..299.43 rows=9901 width=0)
        (actual time=0.660..0.660 rows=11111 loops=1)
      Index Cond: ((header_text)::text ~>=~ 'Selling car #12'::text
               AND (header_text)::text ~<~ 'Selling car #13'::text)
      Buffers: shared read=58
  Execution Time: 3.039 ms
```
- B-tree с `text_pattern_ops` преобразовал `LIKE 'prefix%'` в диапазонное условие
- 58 страниц индекса + 354 таблицы (против 7162)
- **×10 быстрее** (3.0 ms vs 31.8 ms)

### Итоговая таблица B-tree
| Запрос | План без индекса | План с B-tree | Без индекса | B-tree | Разница |
|---|---|---|---:|---:|---|
| Q1 (`>` + `IN`) | Seq Scan | Bitmap Index Scan | 34.0 ms | 35.5 ms | ~1× |
| Q2 (`<`) | Parallel Seq Scan | Bitmap Index Scan | 17.0 ms | 4.6 ms | **×3.7** |
| Q3 (`=`) | Parallel Seq Scan | Index Scan | 14.7 ms | 0.037 ms | **×400** |
| Q4 (`%LIKE`) | Seq Scan | Seq Scan | 32.6 ms | 33.8 ms | ~1× |
| Q5 (`LIKE%`) | Seq Scan | Bitmap Index Scan | 31.8 ms | 3.0 ms | **×10** |

**Сравнение BUFFERS:**
| Запрос | Без индекса | B-tree |
|---|---|---|
| Q1 | hit=7162 | hit=7162 read=228 |
| Q2 | hit=7162 | hit=3222 read=13 |
| Q3 | hit=7162 | hit=2 read=1 |
| Q5 | hit=7162 | hit=354 read=58 |

---

## Сравнение: Hash vs без индекса

### Планы запросов с Hash

**Q1:** `price > 2000000 AND status_id IN (1,2)`
```
Seq Scan on ads  (cost=0.00..10912.00 rows=83209 width=12)
                 (actual time=0.021..35.584 rows=83175 loops=1)
  Filter: ((price > 2000000) AND (status_id = ANY ('{1,2}'::integer[])))
  Rows Removed by Filter: 166825
  Buffers: shared hit=7162
  Execution Time: 37.755 ms
```
- `Seq Scan` — hash не поддерживает `>`, бесполезен

**Q2:** `price < 50000`
```
Gather  (cost=1000.00..9910.18 rows=4461 width=8)
        (actual time=0.404..17.022 rows=4261 loops=1)
  Workers Planned: 2
  Workers Launched: 2
  Buffers: shared hit=7162
  ->  Parallel Seq Scan  (cost=0.00..8464.08 rows=1859 width=8)
                         (actual time=0.020..10.507 rows=1420 loops=3)
        Filter: (price < 50000)
        Rows Removed by Filter: 81913
  Execution Time: 17.205 ms
```
- `Parallel Seq Scan` — hash не поддерживает `<`

**Q3:** `price = 1000000`
```
Index Scan using idx_ads_price_hash on ads
  (cost=0.00..8.02 rows=1 width=8)
  (actual time=0.032..0.032 rows=0 loops=1)
  Index Cond: (price = 1000000)
  Buffers: shared hit=2
  Execution Time: 0.054 ms
```
- `Index Scan` по hash — 2 страницы (hit=2), 0.054 ms
- **×270 быстрее** (0.054 ms vs 14.7 ms)
- B-tree был чуть быстрее (0.037 ms) за счёт меньших накладных расходов

**Q4:** `LIKE '%car #12%'`
```
Seq Scan on ads  (cost=0.00..10287.00 rows=12626 width=23)
                 (actual time=0.010..30.410 rows=11111 loops=1)
  Filter: ((header_text)::text ~~ '%car #12%'::text)
  Rows Removed by Filter: 238889
  Buffers: shared hit=7162
  Execution Time: 30.707 ms
```
- Без изменений: `Seq Scan`

**Q5:** `LIKE 'Selling car #12%'`
```
Seq Scan on ads  (cost=0.00..10287.00 rows=12626 width=23)
                 (actual time=0.009..30.440 rows=11111 loops=1)
  Filter: ((header_text)::text ~~ 'Selling car #12%'::text)
  Rows Removed by Filter: 238889
  Buffers: shared hit=7162
  Execution Time: 30.735 ms
```
- Без изменений: `Seq Scan` — hash не подходит для LIKE

### Итоговая таблица Hash
| Запрос | План без индекса | План с Hash | Без индекса | Hash | Разница |
|---|---|---|---:|---:|---|
| Q1 (`>` + `IN`) | Seq Scan | Seq Scan | 34.0 ms | 37.8 ms | ~1× |
| Q2 (`<`) | Parallel Seq Scan | Parallel Seq Scan | 17.0 ms | 17.2 ms | ~1× |
| Q3 (`=`) | Parallel Seq Scan | **Index Scan** | 14.7 ms | **0.054 ms** | **×270** |
| Q4 (`%LIKE`) | Seq Scan | Seq Scan | 32.6 ms | 30.7 ms | ~1× |
| Q5 (`LIKE%`) | Seq Scan | Seq Scan | 31.8 ms | 30.7 ms | ~1× |

**Вывод:** Hash-индекс ускоряет только `=`. Для диапазонов (`>`, `<`) и LIKE бесполезен. B-tree чуть быстрее Hash на равенстве (0.037 vs 0.054 ms) за счёт лучшей кластеризации.

---

## ДОП: составной индекс (status_id, price)

Был создан составной B-tree индекс `idx_ads_status_price_btree` на `(status_id, price)`.

**Результат:** Планировщик **не использовал** его для Q1. Вместо этого был выбран `idx_ads_price_btree`. Причина: условие `status_id IN (1,2)` покрывает 2 из 3 возможных статусов — фильтр недостаточно селективен, и планировщик решил, что проверка `status_id` после чтения из индекса по цене дешевле.

Это демонстрирует, что составной индекс эффективен, когда **первое поле** в индексе хорошо фильтрует данные (например, `status_id = 3` для одного конкретного статуса). Для `IN (1,2)` с двумя значениями из трёх выигрыш минимален.

---

## Итоговые выводы

1. **Без индексов** — `Seq Scan` на всех запросах, время 15–35 ms.
2. **B-tree** универсален: ускоряет `=`, диапазоны (`>`/`<`) и `LIKE 'prefix%'` (с `text_pattern_ops`).
3. **Hash** ускоряет только `=` (0.054 ms), но не применим к диапазонам (остаётся Seq Scan).
4. **LIKE '%...%'** не ускоряется ни B-tree, ни Hash (нужен GIN + pg_trgm).
5. **Составной индекс** не всегда выбирается планировщиком — его эффективность зависит от селективности первого поля.
6. **BUFFERS**: B-tree радикально снижает количество читаемых страниц для селективных запросов (с 7162 до 2–354), Hash — только для равенства (до 2 страниц).

---

## Приложение: файлы
- `00_setup_optional.sql` — VACUUM ANALYZE
- `02_drop_hw_indexes.sql` — удаление индексов
- `03_create_btree_indexes.sql` — создание B-tree + составного
- `04_create_hash_index.sql` — создание Hash
- `01_queries.sql` — 5 тестовых запросов с EXPLAIN (ANALYZE, BUFFERS)
