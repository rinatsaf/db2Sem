CREATE SCHEMA IF NOT EXISTS hw4;

CREATE EXTENSION IF NOT EXISTS pageinspect;

DROP TABLE IF EXISTS hw4.mvcc_lab;
CREATE TABLE hw4.mvcc_lab (
    id BIGSERIAL PRIMARY KEY,
    note TEXT NOT NULL,
    amount INTEGER NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
) WITH (fillfactor = 100);

INSERT INTO hw4.mvcc_lab (note, amount)
VALUES
  ('row-1', 100),
  ('row-2', 200),
  ('row-3', 300);

ANALYZE hw4.mvcc_lab;
