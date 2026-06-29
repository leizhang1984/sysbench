#!/usr/bin/env bash
# Wait for scenario A probe to finish, then summarize results.
for i in $(seq 1 30); do
  if ! pgrep -f 'fo-probe.py 50 scenarioA' >/dev/null; then break; fi
  sleep 1
done
echo "=== probe.log ==="
cat /tmp/fo_scenarioA.log 2>/dev/null
echo "=== request summary ==="
awk -F, 'NR>1{tot++; if($4==1)ok++; else fail++} END{printf "total=%d ok=%d fail=%d\n", tot, ok, fail}' /tmp/fo_requests_scenarioA.csv
echo "=== failure window (first/last failed request) ==="
awk -F, 'NR>1 && $4==0{print $1, $3, $6, $7}' /tmp/fo_requests_scenarioA.csv | head -40
echo "=== state transitions (only when status or master changes) ==="
awk -F, 'NR>1{k=$3"|"$4; if(k!=prev){print $1, "status="$3, "master="$4, "active="$5, "unassigned="$6, "reloc="$7, "init="$8; prev=k}}' /tmp/fo_state_scenarioA.csv
