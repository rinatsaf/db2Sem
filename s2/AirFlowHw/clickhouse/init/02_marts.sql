CREATE TABLE IF NOT EXISTS lms.mart_enrollment_daily
(
    enroll_date      Date,
    enrollments      UInt64,
    avg_score        Nullable(Float64),
    avg_attendance   Nullable(Float64),
    refreshed_at     DateTime DEFAULT now()
)
ENGINE = MergeTree()
ORDER BY enroll_date;

CREATE TABLE IF NOT EXISTS lms.mart_flow_popularity
(
    flow_code          String,
    flow_title         String,
    total_enrollments  UInt64,
    completed_cnt      UInt64,
    dropped_cnt        UInt64,
    completion_rate    Float64,
    refreshed_at       DateTime DEFAULT now()
)
ENGINE = MergeTree()
ORDER BY total_enrollments;

CREATE TABLE IF NOT EXISTS lms.mart_status_funnel
(
    status       String,
    cnt          UInt64,
    pct          Float64,
    refreshed_at DateTime DEFAULT now()
)
ENGINE = MergeTree()
ORDER BY status;

CREATE TABLE IF NOT EXISTS lms.mart_unit_summary
(
    unit_name      String,
    enrollments    UInt64,
    avg_score      Nullable(Float64),
    refreshed_at   DateTime DEFAULT now()
)
ENGINE = MergeTree()
ORDER BY enrollments;
