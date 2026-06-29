#!/bin/bash
# Run sysbench matrix against a TiDB cluster via LB.
# Usage: $1 = LB host, $2 = tag (dsv5/dsv6)
set -u
LB="${1:-10.142.0.10}"
TAG="${2:-dsv5}"
PORT=4000
USER=root
DB=sbtest
TABLES=32
ROWS=1000000
TIME=300
OUT="/tmp/bench-${TAG}.csv"
LOG="/tmp/bench-${TAG}.log"

echo "tag,test,threads,start_epoch,end_epoch,qps,tps,avg_ms,p95_ms" > "$OUT"
echo "===== bench start $TAG LB=$LB $(date -u +%FT%TZ) =====" | tee "$LOG"

for TEST in oltp_read_only oltp_read_write; do
  for TH in 50 100 200; do
    START=$(date +%s)
    echo "----- $TEST th=$TH start=$START -----" | tee -a "$LOG"
    RES=$(sysbench "$TEST" \
      --db-driver=mysql \
      --mysql-host="$LB" --mysql-port="$PORT" --mysql-user="$USER" --mysql-db="$DB" \
      --tables="$TABLES" --table-size="$ROWS" \
      --threads="$TH" --time="$TIME" --report-interval=30 \
      --rand-type=uniform --db-ps-mode=disable \
      run 2>&1)
    END=$(date +%s)
    echo "$RES" >> "$LOG"
    QPS=$(echo "$RES"  | grep -oE 'queries:[[:space:]]+[0-9]+[[:space:]]*\([0-9.]+ per sec' | grep -oE '\([0-9.]+' | tr -d '(')
    TPS=$(echo "$RES"  | grep -oE 'transactions:[[:space:]]+[0-9]+[[:space:]]*\([0-9.]+ per sec' | grep -oE '\([0-9.]+' | tr -d '(')
    AVG=$(echo "$RES"  | grep -oE 'avg:[[:space:]]+[0-9.]+' | grep -oE '[0-9.]+')
    P95=$(echo "$RES"  | grep -oE '95th percentile:[[:space:]]+[0-9.]+' | grep -oE '[0-9.]+')
    echo "${TAG},${TEST},${TH},${START},${END},${QPS},${TPS},${AVG},${P95}" | tee -a "$OUT"
    sleep 15
  done
done
echo "===== bench done $TAG $(date -u +%FT%TZ) =====" | tee -a "$LOG"
echo "===== RESULT CSV ====="
cat "$OUT"
echo "===== DONE ====="
