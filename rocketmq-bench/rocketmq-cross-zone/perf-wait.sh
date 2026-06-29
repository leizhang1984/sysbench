#!/bin/bash
# Wait (up to ~10min) for perf to complete, then dump aggregated stats.
for i in $(seq 1 40); do
  [ -f /opt/perf/PERF_COMPLETE ] && break
  sleep 15
done
if [ -f /opt/perf/PERF_COMPLETE ]; then echo "PERF_COMPLETE"; else echo "STILL_RUNNING"; fi
echo "=== driver.log ==="
cat /opt/perf/driver.log
