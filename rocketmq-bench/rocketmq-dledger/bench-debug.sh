#!/bin/bash
MQ=/opt/rocketmq-4.9.7
NS="10.170.0.6:9876;10.170.0.4:9876;10.170.0.5:9876"
export NAMESRV_ADDR="$NS"
TOPIC=BenchTopic01
LOG=/tmp/bench-dbg.log
JAVA_BIN=$(readlink -f "$(which java)")
export JAVA_HOME=$(dirname "$(dirname "$JAVA_BIN")")

cd $MQ/benchmark
nohup sh ./producer.sh -t $TOPIC -w 8 -s 1024 -n "$NS" > $LOG 2>&1 &
BPID=$!
sleep 20
kill $BPID 2>/dev/null
sleep 2
echo "=== first exception in producer log ==="
grep -iE "Exception|Caused by|RemotingException|connect to|MQBrokerException|CODE" $LOG | head -15
echo "=== broker-b master 10911 reachable from client? ==="
for ip in 10.170.0.14 10.170.0.11 10.170.0.18; do
  timeout 3 bash -c "echo > /dev/tcp/$ip/10911" 2>/dev/null && echo "$ip:10911 OK" || echo "$ip:10911 FAIL"
done
