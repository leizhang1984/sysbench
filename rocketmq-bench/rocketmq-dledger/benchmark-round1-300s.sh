#!/bin/bash
set -e

pkill -f benchmark.Producer || true
pkill -f /opt/rocketmq-4.9.7/benchmark/runclass.sh || true
sleep 2

export JAVA_HOME=$(dirname $(dirname $(readlink -f /usr/bin/java)))
export PATH=$JAVA_HOME/bin:$PATH
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
export NAMESRV_ADDR="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"

TS=$(date +%Y%m%d_%H%M%S)
TOPIC="BenchTopic_1K_${TS}"
LOG="/var/tmp/benchmark_round1_${TS}.log"

echo "=== ROUND1 BENCHMARK START ==="
echo "START_TIME=$(date '+%Y-%m-%d %H:%M:%S UTC%z')"
echo "JAVA_HOME=$JAVA_HOME"
echo "NAMESRV_ADDR=$NAMESRV_ADDR"
echo "TOPIC=$TOPIC"
echo "LOG=$LOG"

${ROCKETMQ_HOME}/bin/mqadmin updateTopic -n "$NAMESRV_ADDR" -c RocketMQCluster -t "$TOPIC" -w 8 -r 8

timeout 330 sh ${ROCKETMQ_HOME}/benchmark/runclass.sh org.apache.rocketmq.example.benchmark.Producer \
  -n "$NAMESRV_ADDR" \
  -t "$TOPIC" \
  -s 1024 \
  -w 64 \
  -d 300 > "$LOG" 2>&1 || true

echo "=== ROUND1 BENCHMARK END ==="
echo "END_TIME=$(date '+%Y-%m-%d %H:%M:%S UTC%z')"
echo "--- LOG HEAD ---"
head -n 40 "$LOG" || true
echo "--- LOG TAIL ---"
tail -n 120 "$LOG" || true
