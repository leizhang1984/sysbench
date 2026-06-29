#!/bin/bash
# slice-csv.sh <runId> <secFrom> <secTo>
RUNID="$1"; FROM="$2"; TO="$3"
CSV="/opt/probe/${RUNID}.csv"
echo "=== ${RUNID} rows sec ${FROM}..${TO} ==="
echo "epoch_ms,wall,sec,ok,fail,ok_total,fail_total,p50,p99,max,err"
awk -F, -v a="$FROM" -v b="$TO" 'NR>1 && $3>=a && $3<=b {print}' "$CSV"
echo "=== PRODUCE_DONE ==="
grep PRODUCE_DONE "/opt/probe/${RUNID}.console.log" 2>/dev/null | tail -1
