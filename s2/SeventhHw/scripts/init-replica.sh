#!/bin/bash
set -euo pipefail

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  rm -rf "$PGDATA"/*
  until pg_basebackup -h primary -D "$PGDATA" -U postgres -Fp -Xs -R
  do
    sleep 2
  done
fi

chmod 0700 "$PGDATA"
exec postgres
