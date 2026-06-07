CREATE SCHEMA IF NOT EXISTS olap;

-- dim_date: calendar dimension (natural key YYYYMMDD)
CREATE TABLE olap.dim_date (
    date_key     INT PRIMARY KEY,
    full_date    DATE NOT NULL UNIQUE,
    year         INT NOT NULL,
    quarter      INT NOT NULL,
    month        INT NOT NULL,
    day_of_month INT NOT NULL,
    day_of_week  INT NOT NULL,
    day_name     VARCHAR(10) NOT NULL,
    is_weekend   BOOLEAN NOT NULL
);

-- dim_unit: organizational category (faculty, department, ...)
CREATE TABLE olap.dim_unit (
    unit_key BIGSERIAL PRIMARY KEY,
    unit_id  BIGINT NOT NULL UNIQUE,
    name     VARCHAR(255) NOT NULL,
    type     VARCHAR(50) NOT NULL,
    status   VARCHAR(20) NOT NULL
);

-- dim_user: students and staff
CREATE TABLE olap.dim_user (
    user_key        BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL UNIQUE,
    full_name       VARCHAR(255) NOT NULL,
    status          VARCHAR(20) NOT NULL,
    unit_id         BIGINT,
    student_number  VARCHAR(50)
);

-- dim_flow: course / stream as product
CREATE TABLE olap.dim_flow (
    flow_key     BIGSERIAL PRIMARY KEY,
    flow_id      BIGINT NOT NULL UNIQUE,
    code         VARCHAR(50) NOT NULL,
    title        VARCHAR(255) NOT NULL,
    modality     VARCHAR(20),
    cohort_year  INT,
    status       VARCHAR(20) NOT NULL,
    unit_id      BIGINT
);

-- fact_enrollment: grain = one enrollment row
CREATE TABLE olap.fact_enrollment (
    enrollment_id    BIGINT PRIMARY KEY,
    enroll_date_key  INT NOT NULL REFERENCES olap.dim_date (date_key),
    drop_date_key    INT REFERENCES olap.dim_date (date_key),
    user_key         BIGINT NOT NULL REFERENCES olap.dim_user (user_key),
    flow_key         BIGINT NOT NULL REFERENCES olap.dim_flow (flow_key),
    unit_key         BIGINT NOT NULL REFERENCES olap.dim_unit (unit_key),
    attendance_pct   NUMERIC(5, 2),
    current_score    NUMERIC(6, 2),
    is_dropped       INT NOT NULL DEFAULT 0,
    is_completed     INT NOT NULL DEFAULT 0,
    enrollment_cnt   INT NOT NULL DEFAULT 1,
    status           VARCHAR(20) NOT NULL
);

CREATE INDEX idx_fact_enrollment_enroll_date ON olap.fact_enrollment (enroll_date_key);
CREATE INDEX idx_fact_enrollment_user ON olap.fact_enrollment (user_key);
CREATE INDEX idx_fact_enrollment_flow ON olap.fact_enrollment (flow_key);
CREATE INDEX idx_fact_enrollment_unit ON olap.fact_enrollment (unit_key);
CREATE INDEX idx_fact_enrollment_status ON olap.fact_enrollment (status);

GRANT USAGE ON SCHEMA olap TO app, readonly, developer;

GRANT SELECT ON ALL TABLES IN SCHEMA olap TO app, readonly, developer;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA olap TO app, developer;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA olap TO app, developer;

ALTER DEFAULT PRIVILEGES IN SCHEMA olap
    GRANT SELECT ON TABLES TO app, readonly, developer;

ALTER DEFAULT PRIVILEGES IN SCHEMA olap
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app, developer;

ALTER DEFAULT PRIVILEGES IN SCHEMA olap
    GRANT USAGE, SELECT ON SEQUENCES TO app, developer;
