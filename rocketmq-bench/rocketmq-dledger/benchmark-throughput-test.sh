#!/bin/bash
# RocketMQ 4.9.7 吞吐极限测试脚本
# 测试128线程并发、1KB消息、300秒持续发送

set -e

export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
export NAMESRV_ADDR="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
TOPIC="BenchTopic_throughput_${TIMESTAMP}"

echo "============================================"
echo "RocketMQ 4.9.7 Benchmark Producer Test"
echo "Start Time: $(date '+%Y-%m-%d %H:%M:%S UTC%z')"
echo "NameServers: $NAMESRV_ADDR"
echo "============================================"
echo ""

# 创建topic（8写8读，跨broker-a/b/c）
echo "[1/3] Creating topic: $TOPIC (w=8, r=8)..."
$ROCKETMQ_HOME/bin/mqadmin updateTopic -n "$NAMESRV_ADDR" \
  -c RocketMQCluster -t "$TOPIC" -w 8 -r 8

sleep 2

# 验证topic创建
echo "[2/3] Verifying topic..."
$ROCKETMQ_HOME/bin/mqadmin topicStatus -n "$NAMESRV_ADDR" -t "$TOPIC" | head -3

echo ""
echo "[3/3] Running benchmark producer..."
echo "  Configuration:"
echo "    - Threads: 128 (并发压力)"
echo "    - Message Size: 1024 bytes (1KB)"
echo "    - Duration: 300 seconds (5分钟)"
echo "    - Send Mode: Synchronous"
echo ""

cd $ROCKETMQ_HOME

# 执行benchmark - 128线程并发，消息大小1024字节，持续300秒
echo "$(date '+%Y-%m-%d %H:%M:%S') - Test started..."
sh bin/runclass.sh org.apache.rocketmq.example.benchmark.Producer \
  -n "$NAMESRV_ADDR" \
  -t "$TOPIC" \
  -s 1024 \
  -w 128 \
  -d 300 2>&1

echo ""
echo "============================================"
echo "Test completed at $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
