#!/bin/bash
# Prepare sysbench data on a TiDB cluster via its LB.
# Usage: pass LB host as $1 (default 10.142.0.10).
set -e
LB="${1:-10.142.0.10}"
PORT=4000
USER=root
DB=sbtest
TABLES=32
ROWS=1000000

echo "===== target LB=$LB:$PORT db=$DB tables=$TABLES rows=$ROWS ====="
echo "===== create database ====="
mysql -h "$LB" -P "$PORT" -u "$USER" -e "CREATE DATABASE IF NOT EXISTS ${DB};" 2>&1
echo "db ready"

echo "===== sysbench prepare (parallel) ====="
sysbench oltp_common \
  --db-driver=mysql \
  --mysql-host="$LB" \
  --mysql-port="$PORT" \
  --mysql-user="$USER" \
  --mysql-db="$DB" \
  --tables="$TABLES" \
  --table-size="$ROWS" \
  --threads=16 \
  prepare 2>&1 | tail -40
echo "===== verify row count of sbtest1 ====="
mysql -h "$LB" -P "$PORT" -u "$USER" -D "$DB" -e "SELECT COUNT(*) AS sbtest1_rows FROM sbtest1;" 2>&1
echo "===== table count ====="
mysql -h "$LB" -P "$PORT" -u "$USER" -D "$DB" -e "SELECT COUNT(*) AS tables FROM information_schema.tables WHERE table_schema='${DB}';" 2>&1
echo "===== DONE ====="
