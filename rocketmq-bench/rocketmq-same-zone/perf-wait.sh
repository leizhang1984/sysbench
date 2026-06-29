#!/bin/bash
# Wait (server-side) for perf completion up to ~20min, then dump summary tails.
for i in $(seq 1 80); do
  [ -f /opt/perf/PERF_COMPLETE ] && break
  sleep 15
done
echo "=== PERF_COMPLETE present: $([ -f /opt/perf/PERF_COMPLETE ] && echo yes || echo NO) ==="
echo "=== driver.log ==="
cat /opt/perf/driver.log 2>/dev/null
for f in main_w64_d300 sweep_w16_d120 sweep_w32_d120 sweep_w64_d120 sweep_w128_d120; do
  echo "=== $f (last 3 TPS lines) ==="
  grep 'Send TPS' /opt/perf/$f.log 2>/dev/null | tail -n 3
done
