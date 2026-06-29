#!/bin/bash
systemctl stop rmq-broker 2>/dev/null
pkill -9 -f 'java.*BrokerStartup' 2>/dev/null
sleep 2
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
cd "$ROCKETMQ_HOME"
echo "=== foreground mqbroker (timeout 30s) ==="
timeout 30 "$ROCKETMQ_HOME/bin/mqbroker" -c "$ROCKETMQ_HOME/conf/broker.conf" 2>&1 | grep -vE 'WARNING|illegal' | tail -n 40
echo "=== rc=$? ==="
