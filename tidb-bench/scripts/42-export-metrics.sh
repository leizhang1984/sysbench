#!/bin/bash
# Export per-test-window host metrics from Prometheus on clientvm01.
# Reads /tmp/bench-dsv5.csv and /tmp/bench-dsv6.csv (copied here), queries range averages.
# Output: /tmp/metrics.csv with one row per (tag,test,threads,role,metric)=value
set -u
PROM="http://localhost:9090"
OUT="/tmp/metrics.csv"
echo "tag,test,threads,role,node,cpu_idle_pct,cpu_util_pct,softirq_pct,rx_pps,tx_pps" > "$OUT"

# node role maps
DSV5_TIDB="10.142.0.11 10.142.0.12 10.142.0.13"
DSV5_TIKV="10.142.0.21 10.142.0.22 10.142.0.23"
DSV6_TIDB="10.142.0.31 10.142.0.32 10.142.0.33"
DSV6_TIKV="10.142.0.41 10.142.0.42 10.142.0.43"

q() { # $1=query $2=start $3=end ; returns avg over window for a single series value
  curl -s -G "$PROM/api/v1/query_range" \
    --data-urlencode "query=$1" \
    --data-urlencode "start=$2" \
    --data-urlencode "end=$3" \
    --data-urlencode "step=30" 2>/dev/null
}

# avg of all values in a query_range single-series response
avg_of() {
  echo "$1" | grep -oE '\[[0-9.]+,"[0-9.eE+-]+"\]' | grep -oE '"[0-9.eE+-]+"\]' | tr -d '"]' \
    | awk '{s+=$1;n++} END{ if(n>0) printf "%.2f", s/n; else printf "NA" }'
}

process() {
  local CSV="$1"
  [ -f "$CSV" ] || { echo "skip missing $CSV"; return; }
  tail -n +2 "$CSV" | while IFS=, read -r tag test threads start end qps tps avg p95; do
    [ -z "$start" ] && continue
    case "$tag" in
      dsv5) TIDB="$DSV5_TIDB"; TIKV="$DSV5_TIKV";;
      dsv6) TIDB="$DSV6_TIDB"; TIKV="$DSV6_TIKV";;
      *) continue;;
    esac
    for role in TIDB TIKV; do
      eval "nodes=\$$role"
      for n in $nodes; do
        inst="${n}:9100"
        idle=$(avg_of "$(q "avg(rate(node_cpu_seconds_total{instance=\"$inst\",mode=\"idle\"}[1m]))*100" "$start" "$end")")
        util=$(avg_of "$(q "(1-avg(rate(node_cpu_seconds_total{instance=\"$inst\",mode=\"idle\"}[1m])))*100" "$start" "$end")")
        sirq=$(avg_of "$(q "avg(rate(node_cpu_seconds_total{instance=\"$inst\",mode=\"softirq\"}[1m]))*100" "$start" "$end")")
        rx=$(avg_of "$(q "sum(rate(node_network_receive_packets_total{instance=\"$inst\",device!~\"lo\"}[1m]))" "$start" "$end")")
        tx=$(avg_of "$(q "sum(rate(node_network_transmit_packets_total{instance=\"$inst\",device!~\"lo\"}[1m]))" "$start" "$end")")
        echo "${tag},${test},${threads},${role},${n},${idle},${util},${sirq},${rx},${tx}" >> "$OUT"
      done
    done
  done
}

process /tmp/bench-dsv5.csv
process /tmp/bench-dsv6.csv
echo "===== METRICS CSV ====="
cat "$OUT"
echo "===== DONE ====="
