#!/usr/bin/env bash
# Wait for scenario B probe to finish, then summarize.
for i in $(seq 1 60); do
  if ! pgrep -f 'fo-probe.py 180 scenarioB' >/dev/null; then break; fi
  sleep 2
done
F=/tmp/fo_requests_scenarioB.csv
S=/tmp/fo_state_scenarioB.csv
echo "=== probe.log ==="
cat /tmp/fo_scenarioB.log 2>/dev/null
echo "=== request summary ==="
awk -F, 'NR>1{tot++; if($4==1)ok++; else fail++} END{printf "total=%d ok=%d fail=%d\n", tot, ok, fail}' "$F"
echo "=== per-target totals ==="
awk -F, 'NR>1{tot[$3]++; if($4==0)fail[$3]++} END{for(t in tot) printf "%s total=%d fail=%d\n", t, tot[t], (fail[t]?fail[t]:0)}' "$F"
echo "=== first & last failure ==="
awk -F, 'NR>1 && $4==0{print $1, $3, $6}' "$F" | head -1
awk -F, 'NR>1 && $4==0{print $1, $3, $6}' "$F" | tail -1
echo "=== failed-request latency (timeout behavior) p50/avg/max ms ==="
awk -F, 'NR>1 && $4==0{print $5}' "$F" | sort -n | awk '{a[NR]=$1;s+=$1} END{if(NR>0)printf "p50=%.1f avg=%.1f max=%.1f n=%d\n", a[int(NR*0.5)], s/NR, a[NR], NR; else print none}'
echo "=== first success to 10.122.0.7 after freeze (recovery) ==="
awk -F, 'NR>1 && $3=="10.122.0.7" && $4==1 && $1>"11:18:25"{print $1; exit}' "$F"
echo "=== state transitions ==="
awk -F, 'NR>1{k=$3"|"$4; if(k!=prev){print $1, "status="$3, "master="$4, "active="$5, "unassigned="$6, "reloc="$7, "init="$8; prev=k}}' "$S"
