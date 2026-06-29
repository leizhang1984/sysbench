#!/bin/bash
# RocketMQ DLedger throughput benchmark
MQ=/opt/rocketmq-4.9.7
export NAMESRV_ADDR="10.170.0.6:9876;10.170.0.4:9876;10.170.0.5:9876"
TOPIC="BenchmarkTopic_$(date +%H%M%S)"
LOG=/tmp/bench-$(date +%Y%m%d-%H%M%S).log

echo "=== Benchmark start $(date) ==="
echo "TOPIC=$TOPIC"

# detect real JAVA_HOME (runclass.sh hardcodes /usr/java which is missing)
JAVA_BIN=$(readlink -f "$(which java)")
export JAVA_HOME=$(dirname "$(dirname "$JAVA_BIN")")
echo "JAVA_HOME=$JAVA_HOME"
"$JAVA_HOME/bin/java" -version 2>&1 | head -1

# create topic across all 3 broker groups (master broker names)
for b in broker-a broker-b broker-c; do
  $MQ/bin/mqadmin updateTopic -n 10.170.0.6:9876 -b $b -t $TOPIC -r 8 -w 8 2>/dev/null | tail -1
done
sleep 3

# run producer benchmark in background, capture ~60s
cd $MQ/benchmark
nohup sh ./producer.sh -t $TOPIC -w 64 -s 4096 -n "$NAMESRV_ADDR" > $LOG 2>&1 &
BPID=$!
echo "producer pid=$BPID, warming up..."
sleep 60
kill $BPID 2>/dev/null
sleep 2

echo "=== Last 25 stat lines ==="
grep -i "Send TPS" $LOG | tail -25
echo "=== Summary tail ==="
tail -5 $LOG
echo "=== Benchmark end $(date) ==="
