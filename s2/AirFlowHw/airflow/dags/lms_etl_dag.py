"""
DAG 1: ETL from external CSV (disciplines) and JSON (classrooms) into PostgreSQL LMS.
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta

import pandas as pd
from airflow import DAG
from airflow.exceptions import AirflowException
from airflow.operators.python import PythonOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator

from lms_common import (
    CLASSROOMS_JSON,
    DISCIPLINES_CSV,
    STAGING_DIR,
    ensure_staging_dir,
    get_pg_hook,
)

default_args = {
    "owner": "lms",
    "retries": 1,
    "retry_delay": timedelta(minutes=2),
}


def validate_sources(**context):
    ensure_staging_dir()
    if not DISCIPLINES_CSV.exists():
        raise AirflowException(f"Missing CSV: {DISCIPLINES_CSV}")
    if not CLASSROOMS_JSON.exists():
        raise AirflowException(f"Missing JSON: {CLASSROOMS_JSON}")

    df = pd.read_csv(DISCIPLINES_CSV)
    required_csv = {"code", "title", "ects_credits", "level", "unit_code", "language"}
    if not required_csv.issubset(df.columns):
        raise AirflowException(f"CSV missing columns: {required_csv - set(df.columns)}")
    if df["code"].isna().any() or (df["code"].astype(str).str.strip() == "").any():
        raise AirflowException("CSV contains empty discipline codes")
    if len(df) < 1:
        raise AirflowException("CSV must have at least one row")

    with open(CLASSROOMS_JSON, encoding="utf-8") as f:
        rooms = json.load(f)
    if not isinstance(rooms, list) or len(rooms) == 0:
        raise AirflowException("JSON must be a non-empty array")
    for i, room in enumerate(rooms):
        for field in ("building", "room_number", "campus", "capacity"):
            if field not in room:
                raise AirflowException(f"Room #{i} missing field: {field}")
        if room["capacity"] <= 0:
            raise AirflowException(f"Room #{i} has invalid capacity")


def extract_disciplines(**context):
    df = pd.read_csv(DISCIPLINES_CSV)
    path = STAGING_DIR / "disciplines.parquet"
    df.to_parquet(path, index=False)
    return str(path)


def extract_classrooms(**context):
    with open(CLASSROOMS_JSON, encoding="utf-8") as f:
        rooms = json.load(f)
    path = STAGING_DIR / "classrooms.json"
    with open(path, "w", encoding="utf-8") as f:
        json.dump(rooms, f)
    return str(path)


def transform_disciplines(**context):
    path = STAGING_DIR / "disciplines.parquet"
    df = pd.read_parquet(path)
    df["code"] = df["code"].astype(str).str.strip().str.upper()
    df["title"] = df["title"].astype(str).str.strip()
    df["unit_code"] = df["unit_code"].astype(str).str.strip().str.upper()
    df["ects_credits"] = pd.to_numeric(df["ects_credits"], errors="coerce")
    if (df["ects_credits"] <= 0).any():
        raise AirflowException("ects_credits must be > 0")
    df = df.drop_duplicates(subset=["code"], keep="last")
    out = STAGING_DIR / "disciplines_ready.parquet"
    df.to_parquet(out, index=False)
    context["ti"].xcom_push(key="discipline_count", value=len(df))


def transform_classrooms(**context):
    path = STAGING_DIR / "classrooms.json"
    with open(path, encoding="utf-8") as f:
        rooms = json.load(f)
    seen = set()
    cleaned = []
    for room in rooms:
        key = (room["building"].strip(), room["room_number"].strip())
        if key in seen:
            continue
        seen.add(key)
        cleaned.append(
            {
                "building": room["building"].strip(),
                "room_number": room["room_number"].strip(),
                "campus": room.get("campus", "").strip(),
                "capacity": int(room["capacity"]),
                "floor": room.get("floor"),
                "has_projector": bool(room.get("has_projector", False)),
                "has_pc": bool(room.get("has_pc", False)),
                "is_accessible": bool(room.get("is_accessible", False)),
                "status": room.get("status", "active"),
            }
        )
    out = STAGING_DIR / "classrooms_ready.json"
    with open(out, "w", encoding="utf-8") as f:
        json.dump(cleaned, f)
    context["ti"].xcom_push(key="classroom_count", value=len(cleaned))


def load_disciplines(**context):
    hook = get_pg_hook()
    df = pd.read_parquet(STAGING_DIR / "disciplines_ready.parquet")
    sql = """
        INSERT INTO discipline (code, title, ects_credits, level, language, unit_id, status)
        VALUES (%s, %s, %s, %s, %s,
            (SELECT id FROM unit WHERE code = %s LIMIT 1),
            'active')
        ON CONFLICT (code) DO UPDATE SET
            title = EXCLUDED.title,
            ects_credits = EXCLUDED.ects_credits,
            level = EXCLUDED.level,
            language = EXCLUDED.language,
            unit_id = EXCLUDED.unit_id,
            status = EXCLUDED.status,
            updated_at = now()
    """
    rows = [
        (
            r.code,
            r.title,
            float(r.ects_credits),
            r.level,
            r.language,
            r.unit_code,
        )
        for r in df.itertuples(index=False)
    ]
    hook.run("DELETE FROM discipline WHERE code LIKE 'TMP_DQ_%'")
    with hook.get_conn() as conn:
        with conn.cursor() as cur:
            cur.executemany(sql, rows)
        conn.commit()
    context["ti"].xcom_push(key="disciplines_loaded", value=len(rows))


def load_classrooms(**context):
    hook = get_pg_hook()
    with open(STAGING_DIR / "classrooms_ready.json", encoding="utf-8") as f:
        rooms = json.load(f)
    sql = """
        INSERT INTO classroom (
            building, room_number, campus, capacity, floor,
            has_projector, has_pc, is_accessible, status
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (building, room_number) DO UPDATE SET
            campus = EXCLUDED.campus,
            capacity = EXCLUDED.capacity,
            floor = EXCLUDED.floor,
            has_projector = EXCLUDED.has_projector,
            has_pc = EXCLUDED.has_pc,
            is_accessible = EXCLUDED.is_accessible,
            status = EXCLUDED.status,
            updated_at = now()
    """
    rows = [
        (
            r["building"],
            r["room_number"],
            r["campus"],
            r["capacity"],
            r.get("floor"),
            r["has_projector"],
            r["has_pc"],
            r["is_accessible"],
            r["status"],
        )
        for r in rooms
    ]
    with hook.get_conn() as conn:
        with conn.cursor() as cur:
            cur.executemany(sql, rows)
        conn.commit()
    context["ti"].xcom_push(key="classrooms_loaded", value=len(rows))


def log_etl_run(**context):
    hook = get_pg_hook()
    dag_run_id = context["dag_run"].run_id
    disc = context["ti"].xcom_pull(task_ids="load_disciplines", key="disciplines_loaded") or 0
    rooms = context["ti"].xcom_pull(task_ids="load_classrooms", key="classrooms_loaded") or 0
    sql = """
        INSERT INTO etl_load_log (dag_run_id, source_name, rows_loaded)
        VALUES (%s, %s, %s)
        ON CONFLICT (dag_run_id, source_name) DO UPDATE SET
            rows_loaded = EXCLUDED.rows_loaded,
            loaded_at = now()
    """
    for source, cnt in (("disciplines_catalog.csv", disc), ("classrooms.json", rooms)):
        hook.run(sql, parameters=(dag_run_id, source, cnt))


def dq_postgres(**context):
    hook = get_pg_hook()
    df = pd.read_parquet(STAGING_DIR / "disciplines_ready.parquet")
    codes = tuple(df["code"].tolist())
    if not codes:
        raise AirflowException("No discipline codes to validate")

    loaded = hook.get_first(
        "SELECT COUNT(*) FROM discipline WHERE code = ANY(%s)",
        parameters=(list(codes),),
    )[0]
    if loaded != len(codes):
        raise AirflowException(f"Discipline count mismatch: expected {len(codes)}, got {loaded}")

    orphans = hook.get_first(
        "SELECT COUNT(*) FROM discipline WHERE code = ANY(%s) AND unit_id IS NULL",
        parameters=(list(codes),),
    )[0]
    if orphans > 0:
        raise AirflowException(f"Disciplines without unit_id: {orphans}")

    room_count = context["ti"].xcom_pull(task_ids="transform_classrooms", key="classroom_count")
    cr_count = hook.get_first("SELECT COUNT(*) FROM classroom")[0]
    if cr_count < room_count:
        raise AirflowException(f"Classroom count too low: {cr_count} < {room_count}")


with DAG(
    dag_id="lms_etl_dag",
    default_args=default_args,
    description="Load external LMS reference data (CSV + JSON) into PostgreSQL",
    schedule_interval=None,
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=["lms", "etl"],
) as dag:
    t_validate = PythonOperator(task_id="validate_sources", python_callable=validate_sources)
    t_extract_csv = PythonOperator(task_id="extract_disciplines_csv", python_callable=extract_disciplines)
    t_extract_json = PythonOperator(task_id="extract_classrooms_json", python_callable=extract_classrooms)
    t_transform_disc = PythonOperator(task_id="transform_disciplines", python_callable=transform_disciplines)
    t_transform_rooms = PythonOperator(task_id="transform_classrooms", python_callable=transform_classrooms)
    t_load_disc = PythonOperator(task_id="load_disciplines", python_callable=load_disciplines)
    t_load_rooms = PythonOperator(task_id="load_classrooms", python_callable=load_classrooms)
    t_log = PythonOperator(task_id="log_etl_run", python_callable=log_etl_run)
    t_dq = PythonOperator(task_id="dq_postgres", python_callable=dq_postgres)
    t_trigger = TriggerDagRunOperator(
        task_id="trigger_analytics",
        trigger_dag_id="lms_analytics_dag",
        wait_for_completion=False,
    )

    t_validate >> [t_extract_csv, t_extract_json]
    t_extract_csv >> t_transform_disc >> t_load_disc
    t_extract_json >> t_transform_rooms >> t_load_rooms
    [t_load_disc, t_load_rooms] >> t_log >> t_dq >> t_trigger
