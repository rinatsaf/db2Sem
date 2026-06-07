TRUNCATE olap.fact_enrollment, olap.dim_user, olap.dim_flow, olap.dim_unit, olap.dim_date RESTART IDENTITY CASCADE;

-- dim_date: calendar from enrollment dates ± 1 year buffer
INSERT INTO olap.dim_date (date_key, full_date, year, quarter, month, day_of_month, day_of_week, day_name, is_weekend)
SELECT
    TO_CHAR(d::date, 'YYYYMMDD')::INT,
    d::date,
    EXTRACT(YEAR FROM d)::INT,
    EXTRACT(QUARTER FROM d)::INT,
    EXTRACT(MONTH FROM d)::INT,
    EXTRACT(DAY FROM d)::INT,
    EXTRACT(ISODOW FROM d)::INT,
    TO_CHAR(d::date, 'Dy'),
    EXTRACT(ISODOW FROM d) IN (6, 7)
FROM generate_series(
    COALESCE(
        (SELECT (MIN(enrolled_at) - interval '1 year')::date FROM enrollment),
        (current_date - interval '5 years')::date
    ),
    COALESCE(
        (SELECT (MAX(COALESCE(dropped_at, enrolled_at)) + interval '1 year')::date FROM enrollment),
        (current_date + interval '1 year')::date
    ),
    interval '1 day'
) AS d;

-- dim_unit
INSERT INTO olap.dim_unit (unit_id, name, type, status)
SELECT id, name, type, status
FROM unit;

-- dim_user
INSERT INTO olap.dim_user (user_id, full_name, status, unit_id, student_number)
SELECT id, full_name, status, unit_id, student_number
FROM "user";

-- dim_flow
INSERT INTO olap.dim_flow (flow_id, code, title, modality, cohort_year, status, unit_id)
SELECT id, code, title, modality, cohort_year, status, unit_id
FROM flow;

-- fact_enrollment
INSERT INTO olap.fact_enrollment (
    enrollment_id,
    enroll_date_key,
    drop_date_key,
    user_key,
    flow_key,
    unit_key,
    attendance_pct,
    current_score,
    is_dropped,
    is_completed,
    enrollment_cnt,
    status
)
SELECT
    e.id,
    TO_CHAR(e.enrolled_at::date, 'YYYYMMDD')::INT,
    CASE
        WHEN e.dropped_at IS NOT NULL
            THEN TO_CHAR(e.dropped_at::date, 'YYYYMMDD')::INT
    END,
    du.user_key,
    df.flow_key,
    dun.unit_key,
    e.attendance_pct,
    e.current_score,
    CASE WHEN e.dropped_at IS NOT NULL THEN 1 ELSE 0 END,
    CASE WHEN e.status = 'completed' THEN 1 ELSE 0 END,
    1,
    e.status
FROM enrollment e
JOIN olap.dim_user du ON du.user_id = e.user_id
JOIN olap.dim_flow df ON df.flow_id = e.flow_id
JOIN olap.dim_unit dun ON dun.unit_id = df.unit_id
WHERE e.enrolled_at IS NOT NULL;
