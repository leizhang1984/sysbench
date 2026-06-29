#!/bin/bash
# Detached JDK11-compatible benchmark smoke: 16 threads, 1KB, 15s -> /opt/perf/smoke.log
mkdir -p /opt/perf
if [ "${SMOKE_DETACHED:-}" != "1" ]; then
  cp -f "$0" /opt/perf-smoke-run.sh 2>/dev/null || true
  SMOKE_DETACHED=1 setsid bash /opt/perf-smoke-run.sh >/dev/null 2>&1 < /dev/null &
  echo "smoke launched detached -> /opt/perf/smoke.log"
  exit 0
fi
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export PATH=$JAVA_HOME/bin:$PATH
ROCKETMQ_HOME=/opt/rocketmq-4.9.7
NS="10.161.0.4:9876;10.161.0.5:9876;10.161.0.6:9876"
{
  echo "=== SMOKE START $(date) ==="
  timeout 60 java -server -Xms2g -Xmx2g -cp "$ROCKETMQ_HOME/lib/*" \
    org.apache.rocketmq.example.benchmark.Producer \
    -n "$NS" -t BenchTopic_1K -s 1024 -w 16 -d 15
  echo "=== SMOKE END rc=$? $(date) ==="
} > /opt/perf/smoke.log 2>&1
