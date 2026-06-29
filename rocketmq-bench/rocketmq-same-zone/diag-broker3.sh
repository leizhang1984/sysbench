#!/bin/bash
systemctl stop rmq-broker 2>/dev/null || true
pkill -9 -f BrokerStartup 2>/dev/null || true
sleep 3
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
/opt/rocketmq-4.9.7/bin/mqbroker -c /opt/rocketmq-4.9.7/conf/broker.conf >/tmp/broker-fg.out 2>&1 &
PID=$!
sleep 12
echo "=== proc alive? ==="
if kill -0 $PID 2>/dev/null; then echo "RUNNING pid=$PID"; ss -lnt | grep -E '10911|10912' || echo 'ports not up'; kill $PID; else echo "EXITED"; fi
echo "=== /tmp/broker-fg.out (last 40) ==="
tail -40 /tmp/broker-fg.out
