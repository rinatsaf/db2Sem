CREATE DATABASE IF NOT EXISTS lms;

CREATE TABLE IF NOT EXISTS lms.raw_fact_enrollment
(
    enrollment_id   UInt64,
    enroll_date       Date,
    flow_code         String,
    flow_title        String,
    unit_name         String,
    modality          Nullable(String),
    status            String,
    attendance_pct    Nullable(Float64),
    current_score     Nullable(Float64),
    is_dropped        UInt8,
    is_completed      UInt8,
    enrollment_cnt    UInt8,
    loaded_at         DateTime DEFAULT now()
)
ENGINE = MergeTree()
ORDER BY (enroll_date, enrollment_id);

CREATE TABLE IF NOT EXISTS lms.raw_dim_flow
(
    flow_id      UInt64,
    code         String,
    title        String,
    modality     Nullable(String),
    cohort_year  Nullable(Int32),
    status       String,
    unit_id      Nullable(UInt64),
    loaded_at    DateTime DEFAULT now()
)
ENGINE = MergeTree()
ORDER BY flow_id;

CREATE TABLE IF NOT EXISTS lms.raw_dim_unit
(
    unit_id   UInt64,
    name      String,
    type      String,
    status    String,
    loaded_at DateTime DEFAULT now()
)
ENGINE = MergeTree()
ORDER BY unit_id;
