#!/bin/bash
# Performance test on rocketmq-client01 (JDK11-compatible direct java).
# benchmark Producer has NO -d flag; duration controlled by `timeout`.
# Main: 64 threads, 1KB, 300s. Sweep: 16/32/64/128 threads @ 120s, 1KB.
if [ "${PERF_DETACHED:-}" != "1" ]; then
  cp -f "$0" /opt/perf-run.sh 2>/dev/null || true
  mkdir -p /opt/perf
  rm -f /opt/perf/PERF_COMPLETE
  PERF_DETACHED=1 setsid bash /opt/perf-run.sh >/opt/perf/driver.log 2>&1 < /dev/null &
  echo "perf launched detached; logs in /opt/perf/"
  exit 0
fi

set -uo pipefail
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export PATH=$JAVA_HOME/bin:$PATH
ROCKETMQ_HOME=/opt/rocketmq-4.9.7
NS="10.163.0.4:9876;10.163.0.5:9876;10.163.0.6:9876"
TOPIC=BenchTopic_1K
CP="$ROCKETMQ_HOME/lib/*"
mkdir -p /opt/perf
cd /opt/perf
echo "=== PERF START $(date) ==="

run_bench() {  # <threads> <durationSec> <outfile>
  local W="$1" DUR="$2" OUT="$3"
  echo ">>> run w=$W dur=${DUR}s -> $OUT $(date)"
  timeout "$DUR" java -server -Xms2g -Xmx2g -cp "$CP" \
    org.apache.rocketmq.example.benchmark.Producer \
    -n "$NS" -t "$TOPIC" -s 1024 -w "$W" > "$OUT" 2>&1
  echo ">>> done w=$W rc=$? $(date)"
}

# Main headline run: 64 threads, 1KB, 300s
run_bench 64 300 /opt/perf/main_w64_d300.log
sleep 5

# Concurrency sweep at 120s each
for W in 16 32 64 128; do
  run_bench "$W" 120 "/opt/perf/sweep_w${W}_d120.log"
  sleep 5
done

echo "=== PERF ALL DONE $(date) ==="
touch /opt/perf/PERF_COMPLETE
