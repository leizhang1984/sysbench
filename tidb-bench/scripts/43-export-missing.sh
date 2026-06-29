#!/bin/bash
set -u
PROM="http://localhost:9090"
OUT="/tmp/metrics-missing.csv"
: > "$OUT"
declare -A NODES
NODES["dsv5,oltp_read_write,200,TIDB"]="10.142.0.11 10.142.0.12 10.142.0.13"
NODES["dsv5,oltp_read_write,200,TIKV"]="10.142.0.21 10.142.0.22 10.142.0.23"
NODES["dsv6,oltp_read_write,200,TIDB"]="10.142.0.31 10.142.0.32 10.142.0.33"
NODES["dsv6,oltp_read_write,200,TIKV"]="10.142.0.41 10.142.0.42 10.142.0.43"
declare -A WIN
WIN["dsv5"]="1781622033 1781622334"
WIN["dsv6"]="1781622044 1781622344"
q(){ curl -s -G "$PROM/api/v1/query_range" --data-urlencode "query=$1" --data-urlencode "start=$2" --data-urlencode "end=$3" --data-urlencode "step=30" 2>/dev/null; }
avg_of(){ echo "$1" | grep -oE '\[[0-9.]+,"[0-9.eE+-]+"\]' | grep -oE '"[0-9.eE+-]+"\]' | tr -d '"]' | awk '{s+=$1;n++} END{if(n>0)printf "%.2f",s/n; else printf "NA"}'; }
for key in "dsv5,oltp_read_write,200,TIDB" "dsv5,oltp_read_write,200,TIKV" "dsv6,oltp_read_write,200,TIDB" "dsv6,oltp_read_write,200,TIKV"; do
  tag=${key%%,*}; role=${key##*,}
  set -- ${WIN[$tag]}; start=$1; end=$2
  for n in ${NODES[$key]}; do
    inst="${n}:9100"
    idle=$(avg_of "$(q "avg(rate(node_cpu_seconds_total{instance=\"$inst\",mode=\"idle\"}[1m]))*100" "$start" "$end")")
    util=$(avg_of "$(q "(1-avg(rate(node_cpu_seconds_total{instance=\"$inst\",mode=\"idle\"}[1m])))*100" "$start" "$end")")
    sirq=$(avg_of "$(q "avg(rate(node_cpu_seconds_total{instance=\"$inst\",mode=\"softirq\"}[1m]))*100" "$start" "$end")")
    rx=$(avg_of "$(q "sum(rate(node_network_receive_packets_total{instance=\"$inst\",device!~\"lo\"}[1m]))" "$start" "$end")")
    tx=$(avg_of "$(q "sum(rate(node_network_transmit_packets_total{instance=\"$inst\",device!~\"lo\"}[1m]))" "$start" "$end")")
    echo "${tag},oltp_read_write,200,${role},${n},${idle},${util},${sirq},${rx},${tx}" >> "$OUT"
  done
done
echo "===== MISSING ====="
cat "$OUT"
echo "===== DONE ====="
