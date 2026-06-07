"""Shared paths and helpers for LMS Airflow DAGs."""

from __future__ import annotations

import os
from pathlib import Path

DATA_DIR = Path("/opt/airflow/data")
EXTERNAL_DIR = DATA_DIR / "external"
STAGING_DIR = DATA_DIR / "staging"
DISCIPLINES_CSV = EXTERNAL_DIR / "disciplines_catalog.csv"
CLASSROOMS_JSON = EXTERNAL_DIR / "classrooms.json"
REFRESH_OLAP_SQL = Path("/opt/airflow/db/scripts/refresh_olap.sql")

POSTGRES_CONN_ID = "postgres_lms"
CLICKHOUSE_CONN_ID = "clickhouse_lms"


def get_pg_hook():
    from airflow.providers.postgres.hooks.postgres import PostgresHook

    return PostgresHook(postgres_conn_id=POSTGRES_CONN_ID)


def get_ch_client():
    import clickhouse_connect
    from airflow.hooks.base import BaseHook

    conn = BaseHook.get_connection(CLICKHOUSE_CONN_ID)
    return clickhouse_connect.get_client(
        host=conn.host or "clickhouse",
        port=conn.port or 8123,
        username=conn.login or "default",
        password=conn.password or "",
        database=conn.schema or "lms",
    )


def ensure_staging_dir():
    STAGING_DIR.mkdir(parents=True, exist_ok=True)
