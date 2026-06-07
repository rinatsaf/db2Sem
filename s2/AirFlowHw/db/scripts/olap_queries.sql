-- Q1: Daily enrollment activity dynamics
SELECT
    d.full_date,
    SUM(f.enrollment_cnt) AS enrollments
FROM olap.fact_enrollment f
JOIN olap.dim_date d ON d.date_key = f.enroll_date_key
GROUP BY d.full_date, d.date_key
ORDER BY d.date_key;

-- Q2: Top-10 most popular flows (courses)
SELECT
    fl.code,
    fl.title,
    SUM(f.enrollment_cnt) AS total_enrollments
FROM olap.fact_enrollment f
JOIN olap.dim_flow fl ON fl.flow_key = f.flow_key
GROUP BY fl.flow_key, fl.code, fl.title
ORDER BY total_enrollments DESC
LIMIT 10;

-- Q3: Enrollment status conversion (share by status)
SELECT
    f.status,
    SUM(f.enrollment_cnt) AS cnt,
    ROUND(
        100.0 * SUM(f.enrollment_cnt)
        / SUM(SUM(f.enrollment_cnt)) OVER (),
        2
    ) AS pct
FROM olap.fact_enrollment f
GROUP BY f.status
ORDER BY cnt DESC;

-- Q4: Enrollment amount per unit
SELECT
    unit.name,
    SUM(f.enrollment_cnt) AS total_enrollments
FROM olap.fact_enrollment f
JOIN olap.dim_unit unit ON unit.unit_key = f.unit_key
GROUP BY unit.unit_key, unit.name
ORDER BY total_enrollments DESC;