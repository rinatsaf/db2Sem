-- Подготовка стенда для WAL-демонстраций
DROP SCHEMA IF EXISTS wal_lab CASCADE;
CREATE SCHEMA wal_lab;

CREATE TABLE wal_lab.events (
    id BIGSERIAL PRIMARY KEY,
    label TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    payload JSONB DEFAULT '{}'::jsonb
);
CREATE UNIQUE INDEX wal_events_label_uidx ON wal_lab.events(label);

CREATE TABLE wal_lab.bulk_demo (
    id BIGSERIAL PRIMARY KEY,
    note TEXT NOT NULL
);

-- Базовые данные, чтобы было видно рост LSN
INSERT INTO wal_lab.events(label, payload)
VALUES
    ('bootstrap', '{"msg":"initial row"}'),
    ('checkpoint_hint', '{"msg":"useful to see wal growth"}');
