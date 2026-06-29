#!/bin/bash
# Wait for probe DONE_<RUNID>, then print sigstop log info is separate.
RUNID="${1:?need RUNID}"
for i in $(seq 1 40); do
  [ -f "/opt/probe/DONE_${RUNID}" ] && break
  sleep 10
done
if [ -f "/opt/probe/DONE_${RUNID}" ]; then echo "DONE_${RUNID}"; else echo "STILL_RUNNING"; fi
echo "=== produce log tail ==="
tail -5 "/opt/probe/produce_${RUNID}.log" 2>/dev/null
echo "=== csv tail ==="
tail -3 "/opt/probe/ft_${RUNID}.csv" 2>/dev/null
