#!/usr/bin/env bash
# Detailed per-target breakdown and failure-stop time for scenario A.
F=/tmp/fo_requests_scenarioA.csv
echo "=== per-target totals ==="
awk -F, 'NR>1{tot[$3]++; if($4==0)fail[$3]++} END{for(t in tot) printf "%s total=%d fail=%d\n", t, tot[t], (fail[t]?fail[t]:0)}' "$F"
echo "=== last 5 failures ==="
awk -F, 'NR>1 && $4==0{print $1, $3}' "$F" | tail -5
echo "=== first success to node 10.122.0.7 AFTER 11:10:34 (recovery of killed node) ==="
awk -F, 'NR>1 && $3=="10.122.0.7" && $4==1 && $1>"11:10:34"{print $1; exit}' "$F"
echo "=== failure count strictly on 10.122.0.7 vs others ==="
awk -F, 'NR>1 && $4==0{ if($3=="10.122.0.7")a++; else b++ } END{printf "killed_node_fails=%d other_node_fails=%d\n", a, b}' "$F"
echo "=== latency on surviving nodes during fault (11:10:34..11:10:47) p50/avg/max ==="
awk -F, 'NR>1 && $4==1 && $3!="10.122.0.7" && $1>"11:10:34" && $1<"11:10:47"{print $5}' "$F" | sort -n | awk '{a[NR]=$1;s+=$1} END{if(NR>0)printf "p50=%.1f avg=%.1f max=%.1f n=%d\n", a[int(NR*0.5)], s/NR, a[NR], NR; else print "none"}'
