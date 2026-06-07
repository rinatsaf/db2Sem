-- Populate unit codes for ETL join (fill_data creates units without code)
-- Use UNIT{id} without LPAD to avoid LPAD('100',2) -> '10' collisions
UPDATE unit
SET code = 'UNIT' || id::text
WHERE code IS NULL;

CREATE TABLE IF NOT EXISTS etl_load_log (
    id          BIGSERIAL PRIMARY KEY,
    dag_run_id  TEXT NOT NULL,
    source_name TEXT NOT NULL,
    rows_loaded INT NOT NULL,
    loaded_at   TIMESTAMPTZ DEFAULT now(),
    UNIQUE (dag_run_id, source_name)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON etl_load_log TO app, developer;
GRANT SELECT ON etl_load_log TO readonly;
GRANT USAGE, SELECT ON SEQUENCE etl_load_log_id_seq TO app, developer;
