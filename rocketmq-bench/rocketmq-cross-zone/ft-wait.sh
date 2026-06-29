#!/bin/bash
# Wait for produce DONE_<runId>, then print produce log tail + CSV (full) + fail window.
RUNID="${1:?need RUNID}"
for i in $(seq 1 40); do
  [ -f /opt/probe/DONE_${RUNID} ] && break
  sleep 10
done
echo "=== DONE_${RUNID}: $([ -f /opt/probe/DONE_${RUNID} ] && echo yes || echo NO) ==="
echo "=== produce log tail ==="
tail -n 4 /opt/probe/produce_${RUNID}.log 2>/dev/null
echo "=== CSV (sec,ok,fail,ok_total,fail_total,p99,max,err) rows with fail>0 or around them ==="
awk -F, 'NR==1{next} {print $3","$4","$5","$6","$7","$9","$10","$11}' /opt/probe/ft_${RUNID}.csv 2>/dev/null
