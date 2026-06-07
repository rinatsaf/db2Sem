"""
DAG 2: Refresh PostgreSQL OLAP and replicate to ClickHouse analytical marts.
"""

from __future__ import annotations

from datetime import datetime, timedelta

from airflow import DAG
from airflow.exceptions import AirflowException
from airflow.operators.python import PythonOperator

from lms_common import REFRESH_OLAP_SQL, get_ch_client, get_pg_hook

default_args = {
    "owner": "lms",
    "retries": 1,
    "retry_delay": timedelta(minutes=2),
}

FACT_EXTRACT_SQL = """
SELECT
    f.enrollment_id,
    d.full_date AS enroll_date,
    fl.code AS flow_code,
    fl.title AS flow_title,
    u.name AS unit_name,
    fl.modality,
    f.status,
    f.attendance_pct,
    f.current_score,
    f.is_dropped,
    f.is_completed,
    f.enrollment_cnt
FROM olap.fact_enrollment f
JOIN olap.dim_date d ON d.date_key = f.enroll_date_key
JOIN olap.dim_flow fl ON fl.flow_key = f.flow_key
JOIN olap.dim_unit u ON u.unit_key = f.unit_key
"""

FLOW_DIM_SQL = """
SELECT flow_id, code, title, modality, cohort_year, status, unit_id
FROM olap.dim_flow
"""

UNIT_DIM_SQL = """
SELECT unit_id, name, type, status FROM olap.dim_unit
"""


def refresh_olap_postgres(**context):
    hook = get_pg_hook()
    if not REFRESH_OLAP_SQL.exists():
        raise AirflowException(f"Missing SQL file: {REFRESH_OLAP_SQL}")
    sql = REFRESH_OLAP_SQL.read_text(encoding="utf-8")
    hook.run(sql)


def load_clickhouse_raw(**context):
    hook = get_pg_hook()
    client = get_ch_client()

    client.command("TRUNCATE TABLE IF EXISTS lms.raw_fact_enrollment")
    client.command("TRUNCATE TABLE IF EXISTS lms.raw_dim_flow")
    client.command("TRUNCATE TABLE IF EXISTS lms.raw_dim_unit")

    facts = hook.get_records(FACT_EXTRACT_SQL)
    if facts:
        client.insert(
            "raw_fact_enrollment",
            facts,
            column_names=[
                "enrollment_id",
                "enroll_date",
                "flow_code",
                "flow_title",
                "unit_name",
                "modality",
                "status",
                "attendance_pct",
                "current_score",
                "is_dropped",
                "is_completed",
                "enrollment_cnt",
            ],
        )

    flows = hook.get_records(FLOW_DIM_SQL)
    if flows:
        client.insert(
            "raw_dim_flow",
            flows,
            column_names=[
                "flow_id",
                "code",
                "title",
                "modality",
                "cohort_year",
                "status",
                "unit_id",
            ],
        )

    units = hook.get_records(UNIT_DIM_SQL)
    if units:
        client.insert(
            "raw_dim_unit",
            units,
            column_names=["unit_id", "name", "type", "status"],
        )

    context["ti"].xcom_push(key="ch_fact_count", value=len(facts))


def build_marts(**context):
    client = get_ch_client()
    for table in (
        "mart_enrollment_daily",
        "mart_flow_popularity",
        "mart_status_funnel",
        "mart_unit_summary",
    ):
        client.command(f"TRUNCATE TABLE IF EXISTS lms.{table}")

    client.command("""
        INSERT INTO lms.mart_enrollment_daily (enroll_date, enrollments, avg_score, avg_attendance)
        SELECT
            enroll_date,
            sum(enrollment_cnt),
            avg(current_score),
            avg(attendance_pct)
        FROM lms.raw_fact_enrollment
        GROUP BY enroll_date
    """)

    client.command("""
        INSERT INTO lms.mart_flow_popularity (
            flow_code, flow_title, total_enrollments, completed_cnt, dropped_cnt, completion_rate
        )
        SELECT
            flow_code,
            any(flow_title),
            sum(enrollment_cnt),
            sumIf(enrollment_cnt, status = 'completed'),
            sumIf(enrollment_cnt, status = 'dropped'),
            if(
                sum(enrollment_cnt) = 0, 0,
                sumIf(enrollment_cnt, status = 'completed') / sum(enrollment_cnt) * 100
            )
        FROM lms.raw_fact_enrollment
        GROUP BY flow_code
    """)

    client.command("""
        INSERT INTO lms.mart_status_funnel (status, cnt, pct)
        SELECT
            status,
            sum(enrollment_cnt) AS cnt,
            sum(enrollment_cnt) * 100.0 / sum(sum(enrollment_cnt)) OVER () AS pct
        FROM lms.raw_fact_enrollment
        GROUP BY status
    """)

    client.command("""
        INSERT INTO lms.mart_unit_summary (unit_name, enrollments, avg_score)
        SELECT
            unit_name,
            sum(enrollment_cnt),
            avg(current_score)
        FROM lms.raw_fact_enrollment
        GROUP BY unit_name
    """)


def dq_clickhouse(**context):
    hook = get_pg_hook()
    client = get_ch_client()

    pg_count = hook.get_first("SELECT COUNT(*) FROM olap.fact_enrollment")[0]
    ch_count = int(
        client.query("SELECT count() AS cnt FROM lms.raw_fact_enrollment").result_rows[0][0]
    )
    if pg_count != ch_count:
        raise AirflowException(f"Fact count mismatch: PG={pg_count}, CH={ch_count}")

    mart_days = client.query(
        "SELECT count() AS days, sum(enrollments) AS total FROM lms.mart_enrollment_daily"
    ).result_rows[0]
    if mart_days[0] == 0 or mart_days[1] == 0:
        raise AirflowException("mart_enrollment_daily is empty or has zero enrollments")

    funnel_pct = float(
        client.query("SELECT round(sum(pct), 2) AS total_pct FROM lms.mart_status_funnel").result_rows[0][0]
    )
    if abs(funnel_pct - 100.0) > 0.5:
        raise AirflowException(f"Status funnel pct sum must be ~100, got {funnel_pct}")


with DAG(
    dag_id="lms_analytics_dag",
    default_args=default_args,
    description="PostgreSQL OLAP refresh and ClickHouse mart build",
    schedule_interval=None,
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=["lms", "analytics"],
) as dag:
    t_refresh = PythonOperator(
        task_id="refresh_olap_postgres",
        python_callable=refresh_olap_postgres,
    )
    t_load = PythonOperator(
        task_id="load_clickhouse_raw",
        python_callable=load_clickhouse_raw,
    )
    t_marts = PythonOperator(task_id="build_marts", python_callable=build_marts)
    t_dq = PythonOperator(task_id="dq_clickhouse", python_callable=dq_clickhouse)

    t_refresh >> t_load >> t_marts >> t_dq
