#!/bin/bash
# JDK11-compatible benchmark runner (bypasses runclass.sh JDK8 JVM opts).
# Usage: bench-run.sh <threads> <sizeBytes> <durationSec> <topic>
set -uo pipefail
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export PATH=$JAVA_HOME/bin:$PATH
ROCKETMQ_HOME=/opt/rocketmq-4.9.7
NS="10.161.0.4:9876;10.161.0.5:9876;10.161.0.6:9876"
W="${1:-16}"; S="${2:-1024}"; D="${3:-12}"; TOPIC="${4:-BenchTopic_1K}"
java -server -Xms2g -Xmx2g \
  -cp "$ROCKETMQ_HOME/lib/*" \
  org.apache.rocketmq.example.benchmark.Producer \
  -n "$NS" -t "$TOPIC" -s "$S" -w "$W" -d "$D" 2>&1 | tail -n 12
