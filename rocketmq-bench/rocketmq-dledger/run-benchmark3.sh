#!/bin/bash
# RocketMQ DLedger throughput benchmark - single reachable namesrv
MQ=/opt/rocketmq-4.9.7
NS="10.170.0.6:9876"
export NAMESRV_ADDR="$NS"
TOPIC=BenchTopic01
LOG=/tmp/bench-$(date +%Y%m%d-%H%M%S).log
JAVA_BIN=$(readlink -f "$(which java)")
export JAVA_HOME=$(dirname "$(dirname "$JAVA_BIN")")
echo "=== Benchmark start $(date) ===  NS=$NS TOPIC=$TOPIC"

cd $MQ/benchmark
nohup sh ./producer.sh -t $TOPIC -w 64 -s 4096 -n "$NS" > $LOG 2>&1 &
BPID=$!
echo "producer pid=$BPID, running 60s..."
sleep 60
kill $BPID 2>/dev/null
sleep 2
echo "=== TPS samples ==="
grep -i "Send TPS" $LOG | tail -25
echo "=== Benchmark end $(date) ==="
