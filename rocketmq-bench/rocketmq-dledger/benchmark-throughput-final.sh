#!/bin/bash
# RocketMQ 4.9.7 吞吐极限测试脚本 (设置正确JAVA_HOME)

export JAVA_HOME=$(dirname $(dirname $(readlink -f /usr/bin/java)))
export PATH=$JAVA_HOME/bin:$PATH
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
export NAMESRV_ADDR="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
TOPIC="BenchTopic_throughput_${TIMESTAMP}"

echo "============================================"
echo "RocketMQ 4.9.7 Benchmark Producer Test"
echo "Start Time: $(date '+%Y-%m-%d %H:%M:%S UTC%z')"
echo "Java: $(java -version 2>&1 | head -1)"
echo "JAVA_HOME: $JAVA_HOME"
echo "============================================"
echo ""

# 创建topic（8写8读）
echo "[1/3] Creating topic: $TOPIC (w=8, r=8)..."
${ROCKETMQ_HOME}/bin/mqadmin updateTopic -n "$NAMESRV_ADDR" \
  -c RocketMQCluster -t "$TOPIC" -w 8 -r 8

sleep 2

echo ""
echo "[2/3] Running benchmark producer..."
echo "  - Threads: 128"
echo "  - Message Size: 1024 bytes"
echo "  - Duration: 300 seconds"
echo ""

echo "$(date '+%Y-%m-%d %H:%M:%S') - Test started..."
sh ${ROCKETMQ_HOME}/benchmark/runclass.sh \
  org.apache.rocketmq.example.benchmark.Producer \
  -n "$NAMESRV_ADDR" \
  -t "$TOPIC" \
  -s 1024 \
  -w 128 \
  -d 300 2>&1

echo ""
echo "============================================"
echo "Test completed at $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
